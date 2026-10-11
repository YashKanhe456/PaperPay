const express = require("express");

const auth = require("../middleware/auth");
const { requireRole } = require("../middleware/requireRole");
const pool = require("../db/pool");

const router = express.Router();

// Cash collection bookkeeping belongs to the agency admin.
router.use(auth, requireRole("agency_admin"));

router.get("/", async (req, res) => {
  const { delivery_boy_id: deliveryBoyId, date } = req.query;

  try {
    const filters = ["db.agency_id = $1"];
    const values = [req.user.agency_id];

    if (deliveryBoyId) {
      values.push(deliveryBoyId);
      filters.push(`cc.delivery_boy_id = $${values.length}`);
    }

    if (date) {
      values.push(date);
      filters.push(`cc.date = $${values.length}`);
    }

    const result = await pool.query(
      `SELECT
         cc.*,
         db.name AS delivery_boy_name,
         c.name AS customer_name,
         c.phone AS customer_phone
       FROM cash_collections cc
       INNER JOIN delivery_boys db ON db.id = cc.delivery_boy_id
       LEFT JOIN customers c ON c.id = cc.customer_id
       WHERE ${filters.join(" AND ")}
       ORDER BY cc.date DESC, cc.id DESC`,
      values
    );

    return res.status(200).json({ cash_collections: result.rows });
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch cash collections" });
  }
});

async function createCashCollection(req, res) {
  const { delivery_boy_id: deliveryBoyId, customer_id: customerId, amount, date } = req.body;

  if (!deliveryBoyId || !amount) {
    return res.status(400).json({ message: "delivery_boy_id and amount are required" });
  }

  try {
    const deliveryBoyResult = await pool.query(
      `SELECT id, agency_id
       FROM delivery_boys
       WHERE id = $1
       LIMIT 1`,
      [deliveryBoyId]
    );

    if (!deliveryBoyResult.rows.length) {
      return res.status(404).json({ message: "Delivery staff not found" });
    }

    if (deliveryBoyResult.rows[0].agency_id !== req.user.agency_id) {
      return res.status(403).json({ message: "Agency access denied" });
    }

    const result = await pool.query(
      `INSERT INTO cash_collections (
         delivery_boy_id, customer_id, amount, date, submitted
       )
       VALUES ($1, $2, $3, $4, true)
       RETURNING *`,
      [deliveryBoyId, customerId || null, amount, date || new Date().toISOString().slice(0, 10)]
    );

    return res.status(201).json({ cash_collection: result.rows[0] });
  } catch (error) {
    return res.status(500).json({ message: "Failed to submit cash collection" });
  }
}

router.post("/", createCashCollection);
router.post("/submit", createCashCollection);

router.post("/:id/confirm", async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE cash_collections cc
       SET admin_confirmed_at = NOW()
       FROM delivery_boys db
       WHERE cc.id = $1
         AND db.id = cc.delivery_boy_id
         AND db.agency_id = $2
       RETURNING cc.*`,
      [req.params.id, req.user.agency_id]
    );

    if (!result.rows.length) {
      return res.status(404).json({ message: "Cash collection not found" });
    }

    return res.status(200).json({ cash_collection: result.rows[0] });
  } catch (error) {
    return res.status(500).json({ message: "Failed to confirm cash collection" });
  }
});

module.exports = router;
