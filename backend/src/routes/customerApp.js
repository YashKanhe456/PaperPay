const express = require("express");

const auth = require("../middleware/auth");
const pool = require("../db/pool");

const router = express.Router();

router.use(auth);

router.get("/complaints", async (req, res) => {
  if (req.user?.role !== "agency_admin") {
    return res.status(403).json({ message: "Complaint access denied" });
  }

  const agencyId = req.query.agency_id || req.user.agency_id;
  if (!agencyId || agencyId !== req.user.agency_id) {
    return res.status(403).json({ message: "Agency access denied" });
  }

  try {
    const result = await pool.query(
      `SELECT
         cp.id,
         cp.customer_id,
         c.name AS customer_name,
         cp.category,
         cp.description,
         cp.status,
         cp.photo_url,
         cp.raised_at AS created_at,
         cp.resolved_at,
         NULL::text AS notes
       FROM complaints cp
       INNER JOIN customers c ON c.id = cp.customer_id
       WHERE cp.agency_id = $1
       ORDER BY cp.raised_at DESC`,
      [agencyId]
    );

    return res.status(200).json({ complaints: result.rows });
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch complaints" });
  }
});

router.put("/complaints/:id", async (req, res) => {
  if (req.user?.role !== "agency_admin") {
    return res.status(403).json({ message: "Complaint update denied" });
  }

  const { status, notes } = req.body;
  if (!status) {
    return res.status(400).json({ message: "status is required" });
  }

  try {
    const existing = await pool.query(
      `SELECT id, agency_id
       FROM complaints
       WHERE id = $1
       LIMIT 1`,
      [req.params.id]
    );

    if (!existing.rows.length) {
      return res.status(404).json({ message: "Complaint not found" });
    }

    if (existing.rows[0].agency_id !== req.user.agency_id) {
      return res.status(403).json({ message: "Agency access denied" });
    }

    const result = await pool.query(
      `UPDATE complaints
       SET status = $2,
           resolved_at = CASE WHEN $2 = 'resolved' THEN NOW() ELSE resolved_at END
       WHERE id = $1
       RETURNING id, status, resolved_at`,
      [req.params.id, status]
    );

    return res.status(200).json({
      complaint: {
        ...result.rows[0],
        notes: notes || null,
      },
    });
  } catch (error) {
    return res.status(500).json({ message: "Failed to update complaint" });
  }
});

router.get("/me", async (req, res) => {
  const phone = req.user?.phone;

  if (!phone) {
    return res.status(400).json({ message: "Phone number missing from authenticated user" });
  }

  try {
    const customerResult = await pool.query(
      `SELECT
         id,
         agency_id,
         name,
         phone,
         email,
         address,
         area,
         landmark,
         category,
         status,
         total_outstanding,
         lifetime_value,
         notes,
         created_at
       FROM customers
       WHERE phone = $1
       LIMIT 1`,
      [phone]
    );

    const customer = customerResult.rows[0];
    if (!customer) {
      return res.status(404).json({
        message: "Customer profile not found",
        code: "CUSTOMER_PROFILE_NOT_FOUND",
      });
    }

    const today = new Date().toISOString().slice(0, 10);
    const month = new Date().getMonth() + 1;
    const year = new Date().getFullYear();

    const [
      subscriptionsResult,
      currentBillResult,
      billsResult,
      paymentsResult,
      deliveriesResult,
      loyaltyResult,
      complaintsResult,
    ] = await Promise.all([
      pool.query(
        `SELECT
           s.id,
           s.rate,
           s.status,
           s.plan_type,
           s.start_date,
           s.end_date,
           n.id AS newspaper_id,
           n.name AS newspaper_name,
           n.language
         FROM subscriptions s
         INNER JOIN newspapers n ON n.id = s.newspaper_id
         WHERE s.customer_id = $1
         ORDER BY n.name`,
        [customer.id]
      ),
      pool.query(
        `SELECT
           id,
           month,
           year,
           amount,
           discount,
           late_fee,
           final_amount,
           due_date,
           status,
           paid_at,
           pdf_url
         FROM bills
         WHERE customer_id = $1
           AND month = $2
           AND year = $3
         ORDER BY generated_at DESC
         LIMIT 1`,
        [customer.id, month, year]
      ),
      pool.query(
        `SELECT
           id,
           month,
           year,
           amount,
           final_amount,
           due_date,
           status,
           paid_at,
           pdf_url
         FROM bills
         WHERE customer_id = $1
         ORDER BY year DESC, month DESC
         LIMIT 12`,
        [customer.id]
      ),
      pool.query(
        `SELECT
           id,
           amount,
           mode,
           status,
           paid_at,
           txn_id,
           bill_id
         FROM payments
         WHERE customer_id = $1
         ORDER BY COALESCE(paid_at, NOW()) DESC
         LIMIT 20`,
        [customer.id]
      ),
      pool.query(
        `SELECT
           d.id,
           d.date,
           d.status,
           d.photo_proof_url,
           d.notes,
           n.name AS newspaper_name
         FROM deliveries d
         INNER JOIN newspapers n ON n.id = d.newspaper_id
         WHERE d.customer_id = $1
           AND d.date >= CURRENT_DATE - INTERVAL '6 days'
         ORDER BY d.date DESC, n.name ASC`,
        [customer.id]
      ),
      pool.query(
        `SELECT COALESCE(SUM(points), 0)::int AS loyalty_points
         FROM loyalty_points
         WHERE customer_id = $1
           AND (expires_at IS NULL OR expires_at >= CURRENT_DATE)`,
        [customer.id]
      ),
      pool.query(
        `SELECT
           id,
           category,
           description,
           status,
           raised_at
         FROM complaints
         WHERE customer_id = $1
         ORDER BY raised_at DESC
         LIMIT 10`,
        [customer.id]
      ),
    ]);

    const deliveries = deliveriesResult.rows;
    const groupedDeliveryHistory = deliveries.reduce((accumulator, row) => {
      const key = row.date.toISOString().slice(0, 10);
      if (!accumulator[key]) {
        accumulator[key] = [];
      }
      accumulator[key].push({
        id: row.id,
        newspaper_name: row.newspaper_name,
        status: row.status,
        photo_proof_url: row.photo_proof_url,
        notes: row.notes,
      });
      return accumulator;
    }, {});

    const todayDeliveries = groupedDeliveryHistory[today] || [];
    const currentBill = currentBillResult.rows[0] || null;
    const activeSubscriptions = subscriptionsResult.rows.filter(
      (item) => item.status === "active" || item.status === "paused"
    );

    return res.status(200).json({
      customer,
      current_bill: currentBill,
      active_subscriptions: activeSubscriptions,
      bills: billsResult.rows,
      payments: paymentsResult.rows,
      today_delivery: todayDeliveries,
      delivery_history: Object.entries(groupedDeliveryHistory).map(([date, items]) => ({
        date,
        items,
      })),
      loyalty_points: Number(loyaltyResult.rows[0]?.loyalty_points || 0),
      complaints: complaintsResult.rows,
      quick_info: {
        papers_count: activeSubscriptions.length,
        today_delivery_status:
          todayDeliveries.length === 0
            ? "pending"
            : todayDeliveries.every((item) => item.status === "delivered")
              ? "delivered"
              : todayDeliveries.some((item) => item.status === "missed")
                ? "missed"
                : todayDeliveries[0].status,
      },
    });
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch customer app data" });
  }
});

router.post("/complaints", async (req, res) => {
  const phone = req.user?.phone;
  const {
    category,
    description,
    photo_url: photoUrl,
  } = req.body;

  if (!phone) {
    return res.status(400).json({ message: "Phone number missing from authenticated user" });
  }

  if (!category || !description) {
    return res.status(400).json({ message: "category and description are required" });
  }

  try {
    const customerResult = await pool.query(
      `SELECT id, agency_id
       FROM customers
       WHERE phone = $1
       LIMIT 1`,
      [phone]
    );

    const customer = customerResult.rows[0];
    if (!customer) {
      return res.status(404).json({ message: "Customer profile not found" });
    }

    const complaintResult = await pool.query(
      `INSERT INTO complaints (
         customer_id,
         agency_id,
         category,
         description,
         photo_url,
         status,
         raised_at
       )
       VALUES ($1, $2, $3, $4, $5, 'open', NOW())
       RETURNING *`,
      [customer.id, customer.agency_id, category, description, photoUrl || null]
    );

    return res.status(201).json({ complaint: complaintResult.rows[0] });
  } catch (error) {
    return res.status(500).json({ message: "Failed to raise complaint" });
  }
});

router.put("/profile", async (req, res) => {
  const phone = req.user?.phone;
  const { name, email, address, language } = req.body;

  if (!phone) {
    return res.status(400).json({ message: "Phone number missing from authenticated user" });
  }

  try {
    const customerResult = await pool.query(
      `UPDATE customers
       SET name = COALESCE($2, name),
           email = COALESCE($3, email),
           address = COALESCE($4, address)
       WHERE phone = $1
       RETURNING id, name, phone, email, address, area, landmark, category, status`,
      [phone, name || null, email || null, address || null]
    );

    await pool.query(
      `UPDATE users
       SET name = COALESCE($2, name),
           email = COALESCE($3, email),
           language = COALESCE($4, language)
       WHERE phone = $1`,
      [phone, name || null, email || null, language || null]
    );

    if (!customerResult.rows.length) {
      return res.status(404).json({ message: "Customer profile not found" });
    }

    return res.status(200).json({ customer: customerResult.rows[0] });
  } catch (error) {
    return res.status(500).json({ message: "Failed to update profile" });
  }
});

module.exports = router;
