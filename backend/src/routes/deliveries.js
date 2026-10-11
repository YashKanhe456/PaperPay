const express = require("express");

const auth = require("../middleware/auth");
const agencyAccess = require("../middleware/agencyAccess");
const { requireRole } = require("../middleware/requireRole");
const pool = require("../db/pool");

const router = express.Router();

const VALID_STATUSES = new Set([
  "delivered",
  "pending",
  "missed",
  "customer_holiday",
  "wrong_paper",
  "wet_paper",
]);

// Deliveries are marked from the agency side of the app.
router.use(auth, requireRole("agency_admin"));

function normalizeDate(dateValue) {
  if (!dateValue) {
    return new Date().toISOString().slice(0, 10);
  }

  const parsed = new Date(dateValue);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  return parsed.toISOString().slice(0, 10);
}

async function getCustomerAgency(customerId) {
  const result = await pool.query(
    `SELECT agency_id
     FROM customers
     WHERE id = $1
     LIMIT 1`,
    [customerId]
  );

  return result.rows[0] || null;
}

async function getGroupedCustomersForDay(agencyId, targetDate) {
  const result = await pool.query(
    `SELECT
       c.id AS customer_id,
       c.name,
       c.phone,
       c.address,
       c.area,
       c.landmark,
       c.category,
       COALESCE(
         JSON_AGG(
           JSON_BUILD_OBJECT(
             'newspaper_id', n.id,
             'newspaper_name', n.name,
             'rate', s.rate,
             'status', COALESCE(d.status, 'pending'),
             'notes', d.notes
           )
           ORDER BY n.name
         ) FILTER (WHERE s.id IS NOT NULL),
         '[]'::json
       ) AS newspapers,
       BOOL_OR(ch.id IS NOT NULL) AS is_holiday_today
     FROM customers c
     LEFT JOIN subscriptions s
       ON s.customer_id = c.id
      AND s.status IN ('active', 'paused')
      AND (s.start_date IS NULL OR s.start_date <= $2::date)
      AND (s.end_date IS NULL OR s.end_date >= $2::date)
     LEFT JOIN newspapers n
       ON n.id = s.newspaper_id
     LEFT JOIN deliveries d
       ON d.customer_id = c.id
      AND d.newspaper_id = s.newspaper_id
      AND d.date = $2::date
     LEFT JOIN customer_holidays ch
       ON ch.customer_id = c.id
      AND $2::date BETWEEN ch.from_date AND ch.to_date
     WHERE c.agency_id = $1
       AND c.status = 'active'
     GROUP BY
       c.id, c.name, c.phone, c.address, c.area, c.landmark, c.category
     ORDER BY COALESCE(c.area, 'Unassigned'), c.name`,
    [agencyId, targetDate]
  );

  const grouped = [];
  const groupedMap = new Map();
  let markedCount = 0;
  let totalCount = 0;

  for (const row of result.rows) {
    const papers = Array.isArray(row.newspapers) ? row.newspapers : [];
    const overallStatus = row.is_holiday_today
      ? "customer_holiday"
      : papers.every((item) => item.status && item.status !== "pending") && papers.length > 0
        ? "marked"
        : "pending";

    if (overallStatus !== "pending") {
      markedCount += 1;
    }

    totalCount += 1;

    const areaName = row.area || "Unassigned";
    if (!groupedMap.has(areaName)) {
      const group = { area: areaName, customers: [] };
      groupedMap.set(areaName, group);
      grouped.push(group);
    }

    groupedMap.get(areaName).customers.push({
      customer_id: row.customer_id,
      name: row.name,
      phone: row.phone,
      address: row.address,
      area: row.area,
      landmark: row.landmark,
      category: row.category,
      status: overallStatus,
      is_holiday_today: row.is_holiday_today,
      newspapers: papers.map((paper) => ({
        newspaper_id: paper.newspaper_id,
        newspaper_name: paper.newspaper_name,
        rate: Number(paper.rate || 0),
        status: paper.status || (row.is_holiday_today ? "customer_holiday" : "pending"),
        notes: paper.notes,
      })),
    });
  }

  return {
    date: targetDate,
    progress: {
      marked: markedCount,
      total: totalCount,
    },
    areas: grouped,
  };
}

router.get("/today", agencyAccess(), async (req, res) => {
  const { agency_id: agencyId, date } = req.query;

  if (!agencyId) {
    return res.status(400).json({ message: "agency_id is required" });
  }

  const targetDate = normalizeDate(date);
  if (!targetDate) {
    return res.status(400).json({ message: "Invalid date" });
  }

  try {
    const payload = await getGroupedCustomersForDay(agencyId, targetDate);
    return res.status(200).json(payload);
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch today's deliveries" });
  }
});

router.post("/mark", async (req, res) => {
  const {
    customer_id: customerId,
    newspaper_id: newspaperId,
    date,
    status,
    notes,
  } = req.body;

  if (!customerId || !newspaperId || !date || !status) {
    return res.status(400).json({
      message: "customer_id, newspaper_id, date, and status are required",
    });
  }

  if (!VALID_STATUSES.has(status)) {
    return res.status(400).json({ message: "Invalid delivery status" });
  }

  const customer = await getCustomerAgency(customerId);
  if (!customer) {
    return res.status(404).json({ message: "Customer not found" });
  }

  if (customer.agency_id !== req.user.agency_id) {
    return res.status(403).json({ message: "Agency access denied" });
  }

  const targetDate = normalizeDate(date);
  if (!targetDate) {
    return res.status(400).json({ message: "Invalid date" });
  }

  try {
    const result = await pool.query(
      `INSERT INTO deliveries (
         customer_id, newspaper_id, date, status, timestamp, notes
       )
       VALUES ($1, $2, $3, $4, NOW(), $5)
       ON CONFLICT (customer_id, newspaper_id, date)
       DO UPDATE SET
         status = EXCLUDED.status,
         timestamp = NOW(),
         notes = EXCLUDED.notes
       RETURNING *`,
      [customerId, newspaperId, targetDate, status, notes || null]
    );

    return res.status(200).json({ delivery: result.rows[0] });
  } catch (error) {
    return res.status(500).json({ message: "Failed to mark delivery" });
  }
});

router.post("/bulk-mark", async (req, res) => {
  const { customer_ids: customerIds, status, date } = req.body;

  if (!Array.isArray(customerIds) || !customerIds.length || !status || !date) {
    return res.status(400).json({
      message: "customer_ids, status, and date are required",
    });
  }

  if (!VALID_STATUSES.has(status)) {
    return res.status(400).json({ message: "Invalid delivery status" });
  }

  const targetDate = normalizeDate(date);
  if (!targetDate) {
    return res.status(400).json({ message: "Invalid date" });
  }

  try {
    const subscriptionsResult = await pool.query(
      `SELECT
         s.customer_id,
         s.newspaper_id
       FROM subscriptions s
       INNER JOIN customers c ON c.id = s.customer_id
       LEFT JOIN customer_holidays ch
         ON ch.customer_id = c.id
        AND $2::date BETWEEN ch.from_date AND ch.to_date
       WHERE s.customer_id = ANY($1::uuid[])
         AND c.agency_id = $3
         AND c.status = 'active'
         AND ch.id IS NULL
         AND s.status IN ('active', 'paused')
         AND (s.start_date IS NULL OR s.start_date <= $2::date)
         AND (s.end_date IS NULL OR s.end_date >= $2::date)`,
      [customerIds, targetDate, req.user.agency_id]
    );

    if (!subscriptionsResult.rows.length) {
      return res.status(200).json({ updated: 0 });
    }

    let updated = 0;
    for (const row of subscriptionsResult.rows) {
      await pool.query(
        `INSERT INTO deliveries (
           customer_id, newspaper_id, date, status, timestamp
         )
         VALUES ($1, $2, $3, $4, NOW())
         ON CONFLICT (customer_id, newspaper_id, date)
         DO UPDATE SET
           status = EXCLUDED.status,
           timestamp = NOW()`,
        [row.customer_id, row.newspaper_id, targetDate, status]
      );
      updated += 1;
    }

    return res.status(200).json({ updated });
  } catch (error) {
    return res.status(500).json({ message: "Failed to bulk mark deliveries" });
  }
});

router.get("/summary", agencyAccess(), async (req, res) => {
  const { agency_id: agencyId, date } = req.query;

  if (!agencyId) {
    return res.status(400).json({ message: "agency_id is required" });
  }

  const targetDate = normalizeDate(date);
  if (!targetDate) {
    return res.status(400).json({ message: "Invalid date" });
  }

  try {
    const result = await pool.query(
      `SELECT
         COALESCE(COUNT(*) FILTER (WHERE d.status = 'delivered'), 0)::int AS delivered,
         COALESCE(COUNT(*) FILTER (WHERE d.status = 'pending'), 0)::int AS pending,
         COALESCE(COUNT(*) FILTER (WHERE d.status = 'missed'), 0)::int AS missed,
         COALESCE(COUNT(*) FILTER (WHERE d.status = 'customer_holiday'), 0)::int AS holiday,
         COALESCE(COUNT(*) FILTER (WHERE d.status = 'wrong_paper'), 0)::int AS wrong_paper,
         COALESCE(COUNT(*) FILTER (WHERE d.status = 'wet_paper'), 0)::int AS wet_paper
       FROM deliveries d
       INNER JOIN customers c ON c.id = d.customer_id
       WHERE c.agency_id = $1
         AND d.date = $2::date`,
      [agencyId, targetDate]
    );

    return res.status(200).json({
      date: targetDate,
      ...result.rows[0],
    });
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch delivery summary" });
  }
});

module.exports = router;
