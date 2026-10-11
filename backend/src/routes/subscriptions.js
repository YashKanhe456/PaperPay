const express = require("express");

const auth = require("../middleware/auth");
const { requireRole } = require("../middleware/requireRole");
const pool = require("../db/pool");
const { writeAuditLog } = require("../db/audit");

const router = express.Router();

// Subscriptions are created and edited by the agency admin (the customer app
// reads them through /api/customer-app/me).
router.use(auth, requireRole("agency_admin"));

// GET /api/subscriptions?customer_id=&agency_id=
router.get("/", async (req, res) => {
  const { customer_id: customerId, agency_id: agencyId } = req.query;

  if (!customerId && !agencyId) {
    return res.status(400).json({ success: false, message: "customer_id or agency_id is required" });
  }

  // Callers may only ever read their own agency's data.
  if (agencyId && agencyId !== req.user.agency_id) {
    return res.status(403).json({ success: false, message: "Agency access denied" });
  }

  try {
    if (customerId) {
      const owner = await pool.query(
        `SELECT id FROM customers WHERE id = $1 AND agency_id = $2 LIMIT 1`,
        [customerId, req.user.agency_id],
      );

      if (!owner.rows.length) {
        return res.status(403).json({ success: false, message: "Agency access denied" });
      }
    }

    const filters = [];
    const values = [];

    if (customerId) {
      values.push(customerId);
      filters.push(`s.customer_id = $${values.length}`);
    }

    if (agencyId) {
      values.push(agencyId);
      filters.push(`c.agency_id = $${values.length}`);
    }

    const result = await pool.query(
      `SELECT
         s.id,
         s.customer_id,
         s.newspaper_id,
         s.rate,
         s.start_date,
         s.end_date,
         s.status,
         s.plan_type,
         s.auto_renew,
         s.pause_from,
         s.pause_to,
         n.name AS newspaper_name,
         n.language AS newspaper_language,
         n.type AS newspaper_type,
         c.name AS customer_name
       FROM subscriptions s
       INNER JOIN newspapers n ON n.id = s.newspaper_id
       INNER JOIN customers c ON c.id = s.customer_id
       WHERE ${filters.join(" AND ")}
       ORDER BY n.name`,
      values,
    );

    return res.status(200).json({ success: true, data: { subscriptions: result.rows } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to fetch subscriptions" });
  }
});

// POST /api/subscriptions
router.post("/", async (req, res) => {
  const {
    customer_id: customerId,
    newspaper_id: newspaperId,
    rate,
    start_date: startDate,
    end_date: endDate,
    plan_type: planType,
    auto_renew: autoRenew,
  } = req.body;

  if (!customerId || !newspaperId || !rate) {
    return res
      .status(400)
      .json({ success: false, message: "customer_id, newspaper_id, and rate are required" });
  }

  try {
    // Verify customer belongs to user's agency
    const customerResult = await pool.query(
      `SELECT id, agency_id FROM customers WHERE id = $1 LIMIT 1`,
      [customerId],
    );

    if (!customerResult.rows.length) {
      return res.status(404).json({ success: false, message: "Customer not found" });
    }

    if (customerResult.rows[0].agency_id !== req.user.agency_id) {
      return res.status(403).json({ success: false, message: "Agency access denied" });
    }

    const result = await pool.query(
      `INSERT INTO subscriptions
         (customer_id, newspaper_id, rate, start_date, end_date, status, plan_type, auto_renew)
       VALUES ($1, $2, $3, $4, $5, 'active', $6, $7)
       RETURNING *`,
      [
        customerId,
        newspaperId,
        rate,
        startDate || null,
        endDate || null,
        planType || "monthly",
        autoRenew !== false,
      ],
    );

    await writeAuditLog({
      userId: req.user.id,
      action: "CREATE",
      entity: "subscription",
      entityId: result.rows[0].id,
      newValue: result.rows[0],
      ip: req.ip,
    });

    return res.status(201).json({ success: true, data: { subscription: result.rows[0] } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to create subscription" });
  }
});

// PUT /api/subscriptions/:id
router.put("/:id", async (req, res) => {
  const { rate, start_date: startDate, end_date: endDate, plan_type: planType, auto_renew: autoRenew } =
    req.body;

  const updates = [];
  const values = [];

  if (rate !== undefined) { values.push(rate); updates.push(`rate = $${values.length}`); }
  if (startDate !== undefined) { values.push(startDate); updates.push(`start_date = $${values.length}`); }
  if (endDate !== undefined) { values.push(endDate); updates.push(`end_date = $${values.length}`); }
  if (planType !== undefined) { values.push(planType); updates.push(`plan_type = $${values.length}`); }
  if (autoRenew !== undefined) { values.push(autoRenew); updates.push(`auto_renew = $${values.length}`); }

  if (!updates.length) {
    return res.status(400).json({ success: false, message: "No fields to update" });
  }

  values.push(req.params.id);

  try {
    // Verify subscription belongs to user's agency
    const check = await pool.query(
      `SELECT s.id FROM subscriptions s
       INNER JOIN customers c ON c.id = s.customer_id
       WHERE s.id = $1 AND c.agency_id = $2 LIMIT 1`,
      [req.params.id, req.user.agency_id],
    );

    if (!check.rows.length) {
      return res.status(404).json({ success: false, message: "Subscription not found" });
    }

    const result = await pool.query(
      `UPDATE subscriptions SET ${updates.join(", ")} WHERE id = $${values.length} RETURNING *`,
      values,
    );

    return res.status(200).json({ success: true, data: { subscription: result.rows[0] } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to update subscription" });
  }
});

// DELETE /api/subscriptions/:id
router.delete("/:id", async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE subscriptions s
       SET status = 'cancelled'
       FROM customers c
       WHERE s.id = $1
         AND s.customer_id = c.id
         AND c.agency_id = $2
       RETURNING s.id`,
      [req.params.id, req.user.agency_id],
    );

    if (!result.rows.length) {
      return res.status(404).json({ success: false, message: "Subscription not found" });
    }

    await writeAuditLog({
      userId: req.user.id,
      action: "DELETE",
      entity: "subscription",
      entityId: req.params.id,
      ip: req.ip,
    });

    return res.status(200).json({ success: true, data: { id: req.params.id } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to delete subscription" });
  }
});

// POST /api/subscriptions/:id/pause
router.post("/:id/pause", async (req, res) => {
  const { from_date: fromDate, to_date: toDate } = req.body;

  try {
    const result = await pool.query(
      `UPDATE subscriptions s
       SET status = 'paused', pause_from = $3, pause_to = $4
       FROM customers c
       WHERE s.id = $1
         AND s.customer_id = c.id
         AND c.agency_id = $2
       RETURNING s.*`,
      [req.params.id, req.user.agency_id, fromDate || null, toDate || null],
    );

    if (!result.rows.length) {
      return res.status(404).json({ success: false, message: "Subscription not found" });
    }

    return res.status(200).json({ success: true, data: { subscription: result.rows[0] } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to pause subscription" });
  }
});

// POST /api/subscriptions/:id/resume
router.post("/:id/resume", async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE subscriptions s
       SET status = 'active', pause_from = NULL, pause_to = NULL
       FROM customers c
       WHERE s.id = $1
         AND s.customer_id = c.id
         AND c.agency_id = $2
       RETURNING s.*`,
      [req.params.id, req.user.agency_id],
    );

    if (!result.rows.length) {
      return res.status(404).json({ success: false, message: "Subscription not found" });
    }

    return res.status(200).json({ success: true, data: { subscription: result.rows[0] } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to resume subscription" });
  }
});

module.exports = router;
