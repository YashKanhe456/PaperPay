const express = require("express");

const auth = require("../middleware/auth");
const { requireRole } = require("../middleware/requireRole");
const pool = require("../db/pool");

const router = express.Router();

/**
 * Attendance is recorded and reviewed by the agency admin. Delivery staff are
 * rows in `delivery_boys`, not application users, so every call is scoped
 * through the delivery boy's agency instead of trusting the posted id.
 */
router.use(auth, requireRole("agency_admin"));

async function findDeliveryBoyForAgency(deliveryBoyId, agencyId) {
  const result = await pool.query(
    `SELECT id FROM delivery_boys WHERE id = $1 AND agency_id = $2 LIMIT 1`,
    [deliveryBoyId, agencyId]
  );

  return result.rows[0] || null;
}

router.post("/clockin", async (req, res) => {
  const { delivery_boy_id: deliveryBoyId } = req.body;

  if (!deliveryBoyId) {
    return res.status(400).json({ message: "delivery_boy_id is required" });
  }

  try {
    const deliveryBoy = await findDeliveryBoyForAgency(deliveryBoyId, req.user.agency_id);

    if (!deliveryBoy) {
      return res.status(404).json({ message: "Delivery staff not found" });
    }

    const result = await pool.query(
      `INSERT INTO attendance (delivery_boy_id, date, clock_in, status)
       VALUES ($1, CURRENT_DATE, NOW(), 'present')
       ON CONFLICT (delivery_boy_id, date)
       DO UPDATE SET
         clock_in = COALESCE(attendance.clock_in, NOW()),
         status = 'present'
       RETURNING *`,
      [deliveryBoyId]
    );

    return res.status(200).json({ attendance: result.rows[0] });
  } catch (error) {
    return res.status(500).json({ message: "Failed to record clock-in" });
  }
});

router.post("/clockout", async (req, res) => {
  const { delivery_boy_id: deliveryBoyId } = req.body;

  if (!deliveryBoyId) {
    return res.status(400).json({ message: "delivery_boy_id is required" });
  }

  try {
    const deliveryBoy = await findDeliveryBoyForAgency(deliveryBoyId, req.user.agency_id);

    if (!deliveryBoy) {
      return res.status(404).json({ message: "Delivery staff not found" });
    }

    const result = await pool.query(
      `UPDATE attendance
       SET clock_out = NOW()
       WHERE delivery_boy_id = $1
         AND date = CURRENT_DATE
       RETURNING *`,
      [deliveryBoyId]
    );

    if (!result.rows.length) {
      return res.status(404).json({ message: "No attendance record found for today" });
    }

    return res.status(200).json({ attendance: result.rows[0] });
  } catch (error) {
    return res.status(500).json({ message: "Failed to record clock-out" });
  }
});

router.get("/", async (req, res) => {
  const { delivery_boy_id: deliveryBoyId, month, year } = req.query;

  if (!deliveryBoyId || !month || !year) {
    return res.status(400).json({ message: "delivery_boy_id, month, and year are required" });
  }

  try {
    const deliveryBoy = await findDeliveryBoyForAgency(deliveryBoyId, req.user.agency_id);

    if (!deliveryBoy) {
      return res.status(404).json({ message: "Delivery staff not found" });
    }

    const recordsResult = await pool.query(
      `SELECT *
       FROM attendance
       WHERE delivery_boy_id = $1
         AND EXTRACT(MONTH FROM date) = $2
         AND EXTRACT(YEAR FROM date) = $3
       ORDER BY date ASC`,
      [deliveryBoyId, Number(month), Number(year)]
    );

    const countsResult = await pool.query(
      `WITH month_days AS (
         SELECT generate_series(
           make_date($2, $1, 1),
           (make_date($2, $1, 1) + INTERVAL '1 month - 1 day')::date,
           INTERVAL '1 day'
         )::date AS day
       )
       SELECT
         COUNT(*) FILTER (WHERE a.status = 'present')::int AS present_days,
         COUNT(*) FILTER (WHERE a.status = 'leave')::int AS leave_days,
         COUNT(*) FILTER (WHERE a.id IS NULL)::int AS absent_days
       FROM month_days md
       LEFT JOIN attendance a
         ON a.delivery_boy_id = $3
        AND a.date = md.day`,
      [Number(month), Number(year), deliveryBoyId]
    );

    return res.status(200).json({
      records: recordsResult.rows,
      summary: countsResult.rows[0],
    });
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch attendance" });
  }
});

module.exports = router;
