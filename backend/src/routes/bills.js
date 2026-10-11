const express = require("express");

const auth = require("../middleware/auth");
const agencyAccess = require("../middleware/agencyAccess");
const pool = require("../db/pool");
const { calculateBill, generateBillsForAgency } = require("../services/billing");
const { requireRole } = require("../middleware/requireRole");

const router = express.Router();

// Billing is an administrative workflow (generation, edits, defaulters).
router.use(auth, requireRole("agency_admin"));

router.post("/generate", agencyAccess(), async (req, res) => {
  const { agency_id: agencyId, month, year } = req.body;

  if (!agencyId || !month || !year) {
    return res.status(400).json({ message: "agency_id, month, and year are required" });
  }

  try {
    const result = await generateBillsForAgency(agencyId, Number(month), Number(year));
    return res.status(200).json(result);
  } catch (error) {
    return res.status(500).json({ message: "Failed to generate bills" });
  }
});

router.get("/defaulters", agencyAccess(), async (req, res) => {
  const { agency_id: agencyId } = req.query;

  if (!agencyId) {
    return res.status(400).json({ message: "agency_id is required" });
  }

  try {
    const result = await pool.query(
      `SELECT
         b.id,
         b.customer_id,
         c.name AS customer_name,
         c.phone,
         b.final_amount,
         (CURRENT_DATE - b.due_date)::int AS days_overdue
       FROM bills b
       INNER JOIN customers c ON c.id = b.customer_id
       WHERE b.agency_id = $1
         AND b.status = 'unpaid'
         AND b.due_date < CURRENT_DATE
       ORDER BY days_overdue DESC, b.final_amount DESC`,
      [agencyId]
    );

    return res.status(200).json({ defaulters: result.rows });
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch bill defaulters" });
  }
});

router.get("/", agencyAccess(), async (req, res) => {
  const { agency_id: agencyId, status, month, year, customer_id: customerId } = req.query;
  const page = Math.max(Number.parseInt(req.query.page || "1", 10), 1);
  const limit = 20;
  const offset = (page - 1) * limit;

  if (!agencyId) {
    return res.status(400).json({ message: "agency_id is required" });
  }

  try {
    const filters = ["b.agency_id = $1"];
    const values = [agencyId];

    if (status) {
      values.push(status);
      filters.push(`b.status = $${values.length}`);
    }

    if (month) {
      values.push(Number(month));
      filters.push(`b.month = $${values.length}`);
    }

    if (year) {
      values.push(Number(year));
      filters.push(`b.year = $${values.length}`);
    }

    if (customerId) {
      values.push(customerId);
      filters.push(`b.customer_id = $${values.length}`);
    }

    const whereClause = filters.join(" AND ");
    const countResult = await pool.query(
      `SELECT COUNT(*)::int AS total
       FROM bills b
       WHERE ${whereClause}`,
      values
    );

    values.push(limit, offset);

    const result = await pool.query(
      `SELECT
         b.*,
         c.name AS customer_name,
         c.phone
       FROM bills b
       INNER JOIN customers c ON c.id = b.customer_id
       WHERE ${whereClause}
       ORDER BY b.year DESC, b.month DESC, b.generated_at DESC
       LIMIT $${values.length - 1}
       OFFSET $${values.length}`,
      values
    );

    return res.status(200).json({
      bills: result.rows,
      total_count: countResult.rows[0].total,
      page,
      limit,
    });
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch bills" });
  }
});

router.get("/:id", agencyAccess({ resourceTable: "bills" }), async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
         b.*,
         c.name AS customer_name,
         c.phone,
         c.area
       FROM bills b
       INNER JOIN customers c ON c.id = b.customer_id
       WHERE b.id = $1
       LIMIT 1`,
      [req.params.id]
    );

    if (!result.rows.length) {
      return res.status(404).json({ message: "Bill not found" });
    }

    const bill = result.rows[0];
    const calculated = await calculateBill(bill.customer_id, bill.month, bill.year);

    return res.status(200).json({
      bill,
      bill_items: calculated.bill_items,
    });
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch bill" });
  }
});

router.put("/:id", agencyAccess({ resourceTable: "bills" }), async (req, res) => {
  const { status, notes } = req.body;
  const updates = [];
  const values = [];

  if (status !== undefined) {
    values.push(status);
    updates.push(`status = $${values.length}`);
  }

  if (notes !== undefined) {
    values.push(notes);
    updates.push(`notes = $${values.length}`);
  }

  if (!updates.length) {
    return res.status(400).json({ message: "status or notes is required" });
  }

  values.push(req.params.id);

  try {
    const result = await pool.query(
      `UPDATE bills
       SET ${updates.join(", ")}
       WHERE id = $${values.length}
       RETURNING *`,
      values
    );

    if (!result.rows.length) {
      return res.status(404).json({ message: "Bill not found" });
    }

    return res.status(200).json({ bill: result.rows[0] });
  } catch (error) {
    return res.status(500).json({ message: "Failed to update bill" });
  }
});

module.exports = router;
