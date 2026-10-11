const express = require("express");

const auth = require("../middleware/auth");
const agencyAccess = require("../middleware/agencyAccess");
const { requireRole } = require("../middleware/requireRole");
const pool = require("../db/pool");
const { writeAuditLog } = require("../db/audit");

const router = express.Router();

// The newspaper master list is managed by the agency admin.
router.use(auth, requireRole("agency_admin"));

// GET /api/newspapers?agency_id=
router.get("/", agencyAccess(), async (req, res) => {
  const { agency_id: agencyId, status } = req.query;

  if (!agencyId) {
    return res.status(400).json({ success: false, message: "agency_id is required" });
  }

  try {
    const filters = ["n.agency_id = $1"];
    const values = [agencyId];

    if (status) {
      values.push(status);
      filters.push(`n.status = $${values.length}`);
    } else {
      filters.push("n.status != 'deleted'");
    }

    const result = await pool.query(
      `SELECT
         n.id,
         n.name,
         n.language,
         n.type,
         n.cost_price,
         n.selling_price,
         n.publisher,
         n.status,
         COUNT(s.id) FILTER (WHERE s.status = 'active')::int AS active_subscribers
       FROM newspapers n
       LEFT JOIN subscriptions s ON s.newspaper_id = n.id
       WHERE ${filters.join(" AND ")}
       GROUP BY n.id
       ORDER BY n.name`,
      values,
    );

    return res.status(200).json({ success: true, data: { newspapers: result.rows } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to fetch newspapers" });
  }
});

// POST /api/newspapers
router.post("/", agencyAccess(), async (req, res) => {
  const {
    agency_id: agencyId,
    name,
    language,
    type,
    cost_price: costPrice,
    selling_price: sellingPrice,
    publisher,
  } = req.body;

  if (!agencyId || !name || !sellingPrice) {
    return res
      .status(400)
      .json({ success: false, message: "agency_id, name, and selling_price are required" });
  }

  try {
    const result = await pool.query(
      `INSERT INTO newspapers (agency_id, name, language, type, cost_price, selling_price, publisher, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'active')
       RETURNING *`,
      [agencyId, name, language || null, type || "daily", costPrice || null, sellingPrice, publisher || null],
    );

    await writeAuditLog({
      userId: req.user.id,
      action: "CREATE",
      entity: "newspaper",
      entityId: result.rows[0].id,
      newValue: result.rows[0],
      ip: req.ip,
    });

    return res.status(201).json({ success: true, data: { newspaper: result.rows[0] } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to create newspaper" });
  }
});

// PUT /api/newspapers/:id
router.put("/:id", agencyAccess({ resourceTable: "newspapers" }), async (req, res) => {
  const { name, language, type, cost_price: costPrice, selling_price: sellingPrice, publisher, status } =
    req.body;

  const updates = [];
  const values = [];

  if (name !== undefined) { values.push(name); updates.push(`name = $${values.length}`); }
  if (language !== undefined) { values.push(language); updates.push(`language = $${values.length}`); }
  if (type !== undefined) { values.push(type); updates.push(`type = $${values.length}`); }
  if (costPrice !== undefined) { values.push(costPrice); updates.push(`cost_price = $${values.length}`); }
  if (sellingPrice !== undefined) { values.push(sellingPrice); updates.push(`selling_price = $${values.length}`); }
  if (publisher !== undefined) { values.push(publisher); updates.push(`publisher = $${values.length}`); }
  if (status !== undefined) { values.push(status); updates.push(`status = $${values.length}`); }

  if (!updates.length) {
    return res.status(400).json({ success: false, message: "No fields to update" });
  }

  values.push(req.params.id);

  try {
    const result = await pool.query(
      `UPDATE newspapers SET ${updates.join(", ")} WHERE id = $${values.length} RETURNING *`,
      values,
    );

    if (!result.rows.length) {
      return res.status(404).json({ success: false, message: "Newspaper not found" });
    }

    await writeAuditLog({
      userId: req.user.id,
      action: "UPDATE",
      entity: "newspaper",
      entityId: req.params.id,
      ip: req.ip,
    });

    return res.status(200).json({ success: true, data: { newspaper: result.rows[0] } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to update newspaper" });
  }
});

// DELETE /api/newspapers/:id  (soft delete)
router.delete("/:id", agencyAccess({ resourceTable: "newspapers" }), async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE newspapers SET status = 'inactive' WHERE id = $1 RETURNING id`,
      [req.params.id],
    );

    if (!result.rows.length) {
      return res.status(404).json({ success: false, message: "Newspaper not found" });
    }

    await writeAuditLog({
      userId: req.user.id,
      action: "DELETE",
      entity: "newspaper",
      entityId: req.params.id,
      ip: req.ip,
    });

    return res.status(200).json({ success: true, data: { id: req.params.id } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to delete newspaper" });
  }
});

module.exports = router;
