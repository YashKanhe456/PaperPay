const express = require("express");
const jwt = require("jsonwebtoken");

const { ensureFirebase } = require("../config/firebase");
const pool = require("../db/pool");
const { writeAuditLog } = require("../db/audit");
const auth = require("../middleware/auth");
const { requireRole } = require("../middleware/requireRole");
const { authLimiter } = require("../middleware/rateLimit");

const router = express.Router();

// POST /api/agencies/register  — no auth, creates new agency + admin user
router.post("/register", authLimiter, async (req, res) => {
  const { token: idToken, name, city, state, pincode, address, gst_number: gstNumber } = req.body;

  if (!idToken || !name) {
    return res.status(400).json({ success: false, message: "token and agency name are required" });
  }

  const jwtSecret = process.env.JWT_SECRET;
  if (!jwtSecret) {
    return res.status(500).json({ success: false, message: "JWT_SECRET is not configured" });
  }

  try {
    const admin = ensureFirebase();
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const phone = decodedToken.phone_number;

    if (!phone) {
      return res.status(400).json({ success: false, message: "Phone number missing in token" });
    }

    const client = await pool.connect();
    try {
      await client.query("BEGIN");

      // Upsert user as agency_admin
      let userResult = await client.query(
        `SELECT id, agency_id FROM users WHERE phone = $1 LIMIT 1`,
        [phone],
      );

      let userId;
      if (userResult.rows.length) {
        userId = userResult.rows[0].id;
        // If already has an agency, return error
        if (userResult.rows[0].agency_id) {
          await client.query("ROLLBACK");
          return res.status(409).json({ success: false, message: "User already has an agency" });
        }
      } else {
        const newUser = await client.query(
          `INSERT INTO users (name, phone, role, language)
           VALUES ($1, $2, 'agency_admin', 'hi')
           RETURNING id`,
          [decodedToken.name || "Admin", phone],
        );
        userId = newUser.rows[0].id;
      }

      // Create agency
      const agencyResult = await client.query(
        `INSERT INTO agencies (name, owner_id, city, state, pincode, address, gst_number, status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, 'active')
         RETURNING *`,
        [name, userId, city || null, state || null, pincode || null, address || null, gstNumber || null],
      );

      const agency = agencyResult.rows[0];

      // Update user with agency_id and role
      await client.query(
        `UPDATE users SET agency_id = $1, role = 'agency_admin' WHERE id = $2`,
        [agency.id, userId],
      );

      await client.query("COMMIT");

      // Fetch updated user
      const finalUser = await pool.query(
        `SELECT id, name, phone, email, role, agency_id, language, theme FROM users WHERE id = $1`,
        [userId],
      );
      const user = finalUser.rows[0];

      const token = jwt.sign(
        { sub: user.id, uid: decodedToken.uid, phone: user.phone, role: user.role, agency_id: user.agency_id },
        jwtSecret,
        { expiresIn: "7d" },
      );

      await writeAuditLog({
        userId,
        action: "CREATE",
        entity: "agency",
        entityId: agency.id,
        newValue: { name: agency.name },
        ip: req.ip,
      });

      return res.status(201).json({ success: true, data: { user, token, agency } });
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    if (error.code === "auth/argument-error" || error.code === "auth/id-token-expired") {
      return res.status(401).json({ success: false, message: "Invalid or expired Firebase token" });
    }
    return res.status(500).json({ success: false, message: "Failed to register agency" });
  }
});

// GET /api/agencies/me  — returns current user's agency
router.get("/me", auth, requireRole("agency_admin"), async (req, res) => {
  const agencyId = req.user.agency_id;
  if (!agencyId) {
    return res.status(404).json({ success: false, message: "No agency linked to this user" });
  }

  try {
    const result = await pool.query(
      `SELECT id, name, owner_id, address, city, state, pincode, gst_number, subscription_plan, status, created_at
       FROM agencies WHERE id = $1 LIMIT 1`,
      [agencyId],
    );

    if (!result.rows.length) {
      return res.status(404).json({ success: false, message: "Agency not found" });
    }

    return res.status(200).json({ success: true, data: { agency: result.rows[0] } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to fetch agency" });
  }
});

// PUT /api/agencies/me
router.put("/me", auth, requireRole("agency_admin"), async (req, res) => {
  const agencyId = req.user.agency_id;
  if (!agencyId) {
    return res.status(404).json({ success: false, message: "No agency linked to this user" });
  }

  const { name, address, city, state, pincode, gst_number: gstNumber } = req.body;
  const updates = [];
  const values = [];

  if (name !== undefined) { values.push(name); updates.push(`name = $${values.length}`); }
  if (address !== undefined) { values.push(address); updates.push(`address = $${values.length}`); }
  if (city !== undefined) { values.push(city); updates.push(`city = $${values.length}`); }
  if (state !== undefined) { values.push(state); updates.push(`state = $${values.length}`); }
  if (pincode !== undefined) { values.push(pincode); updates.push(`pincode = $${values.length}`); }
  if (gstNumber !== undefined) { values.push(gstNumber); updates.push(`gst_number = $${values.length}`); }

  if (!updates.length) {
    return res.status(400).json({ success: false, message: "No fields to update" });
  }

  values.push(agencyId);

  try {
    const result = await pool.query(
      `UPDATE agencies SET ${updates.join(", ")} WHERE id = $${values.length} RETURNING *`,
      values,
    );

    return res.status(200).json({ success: true, data: { agency: result.rows[0] } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to update agency" });
  }
});

module.exports = router;
