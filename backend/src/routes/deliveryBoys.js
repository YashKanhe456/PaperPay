const express = require("express");

const auth = require("../middleware/auth");
const agencyAccess = require("../middleware/agencyAccess");
const { requireRole } = require("../middleware/requireRole");
const pool = require("../db/pool");
const { writeAuditLog } = require("../db/audit");

const router = express.Router();

// Managing delivery staff is an administrative operation.
router.use(auth, requireRole("agency_admin"));

// GET /api/delivery-boys?agency_id=
router.get("/", agencyAccess(), async (req, res) => {
  const { agency_id: agencyId } = req.query;

  if (!agencyId) {
    return res.status(400).json({ success: false, message: "agency_id is required" });
  }

  try {
    const today = new Date().toISOString().slice(0, 10);

    const result = await pool.query(
      `SELECT
         db.id,
         db.name,
         db.phone,
         db.area,
         db.created_at,
         COUNT(d.id) FILTER (WHERE d.date = $2 AND d.status != 'pending')::int AS delivered_today,
         COUNT(d.id) FILTER (WHERE d.date = $2)::int AS total_today
       FROM delivery_boys db
       LEFT JOIN deliveries d ON d.delivery_boy_id = db.id
       WHERE db.agency_id = $1
       GROUP BY db.id
       ORDER BY db.name`,
      [agencyId, today],
    );

    return res.status(200).json({ success: true, data: { delivery_boys: result.rows } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to fetch delivery boys" });
  }
});

// POST /api/delivery-boys
router.post("/", agencyAccess(), async (req, res) => {
  const { agency_id: agencyId, name, phone, area } = req.body;

  if (!agencyId || !name) {
    return res.status(400).json({ success: false, message: "agency_id and name are required" });
  }

  try {
    const result = await pool.query(
      `INSERT INTO delivery_boys (agency_id, name, phone, area)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [agencyId, name, phone || null, area || null],
    );

    await writeAuditLog({
      userId: req.user.id,
      action: "CREATE",
      entity: "delivery_boy",
      entityId: result.rows[0].id,
      newValue: result.rows[0],
      ip: req.ip,
    });

    return res.status(201).json({ success: true, data: { delivery_boy: result.rows[0] } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to create delivery boy" });
  }
});

// PUT /api/delivery-boys/:id
router.put("/:id", async (req, res) => {
  const { name, phone, area } = req.body;
  const updates = [];
  const values = [];

  if (name !== undefined) { values.push(name); updates.push(`name = $${values.length}`); }
  if (phone !== undefined) { values.push(phone); updates.push(`phone = $${values.length}`); }
  if (area !== undefined) { values.push(area); updates.push(`area = $${values.length}`); }

  if (!updates.length) {
    return res.status(400).json({ success: false, message: "No fields to update" });
  }

  values.push(req.params.id);
  values.push(req.user.agency_id);

  try {
    const result = await pool.query(
      `UPDATE delivery_boys
       SET ${updates.join(", ")}
       WHERE id = $${values.length - 1}
         AND agency_id = $${values.length}
       RETURNING *`,
      values,
    );

    if (!result.rows.length) {
      return res.status(404).json({ success: false, message: "Delivery boy not found" });
    }

    return res.status(200).json({ success: true, data: { delivery_boy: result.rows[0] } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to update delivery boy" });
  }
});

// DELETE /api/delivery-boys/:id
router.delete("/:id", async (req, res) => {
  try {
    const result = await pool.query(
      `DELETE FROM delivery_boys
       WHERE id = $1 AND agency_id = $2
       RETURNING id`,
      [req.params.id, req.user.agency_id],
    );

    if (!result.rows.length) {
      return res.status(404).json({ success: false, message: "Delivery boy not found" });
    }

    await writeAuditLog({
      userId: req.user.id,
      action: "DELETE",
      entity: "delivery_boy",
      entityId: req.params.id,
      ip: req.ip,
    });

    return res.status(200).json({ success: true, data: { id: req.params.id } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to delete delivery boy" });
  }
});

// GET /api/delivery-boys/:id/performance
router.get("/:id/performance", async (req, res) => {
  const { month, year } = req.query;

  const targetMonth = month ? Number(month) : new Date().getMonth() + 1;
  const targetYear = year ? Number(year) : new Date().getFullYear();

  try {
    const perfResult = await pool.query(
      `SELECT
         COUNT(d.id)::int AS total_deliveries,
         COUNT(d.id) FILTER (WHERE d.status = 'delivered')::int AS delivered_count,
         COUNT(d.id) FILTER (WHERE d.status = 'missed')::int AS missed_count,
         COUNT(d.id) FILTER (WHERE d.status = 'delivered' AND d.photo_proof_url IS NOT NULL)::int AS photo_count
       FROM deliveries d
       WHERE d.delivery_boy_id = $1
         AND EXTRACT(MONTH FROM d.date) = $2
         AND EXTRACT(YEAR FROM d.date) = $3`,
      [req.params.id, targetMonth, targetYear],
    );

    const attendanceResult = await pool.query(
      `SELECT
         COUNT(*) FILTER (WHERE status = 'present')::int AS present_days,
         COUNT(*) FILTER (WHERE status = 'leave')::int AS leave_days
       FROM attendance
       WHERE delivery_boy_id = $1
         AND EXTRACT(MONTH FROM date) = $2
         AND EXTRACT(YEAR FROM date) = $3`,
      [req.params.id, targetMonth, targetYear],
    );

    const perf = perfResult.rows[0];
    const att = attendanceResult.rows[0];
    const total = Number(perf.total_deliveries || 0);
    const delivered = Number(perf.delivered_count || 0);

    return res.status(200).json({
      success: true,
      data: {
        month: targetMonth,
        year: targetYear,
        total_deliveries: total,
        delivered_count: delivered,
        missed_count: Number(perf.missed_count || 0),
        photo_count: Number(perf.photo_count || 0),
        success_rate: total > 0 ? Number(((delivered / total) * 100).toFixed(2)) : 0,
        present_days: Number(att.present_days || 0),
        leave_days: Number(att.leave_days || 0),
      },
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to fetch performance" });
  }
});

module.exports = router;
