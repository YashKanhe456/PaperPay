const express = require("express");
const jwt = require("jsonwebtoken");

const { ensureFirebase } = require("../config/firebase");
const pool = require("../db/pool");
const { authLimiter } = require("../middleware/rateLimit");

const router = express.Router();

router.post("/verify-token", authLimiter, async (req, res) => {
  const { token: idToken } = req.body;
  const jwtSecret = process.env.JWT_SECRET;

  if (!idToken) {
    return res.status(400).json({ message: "Firebase ID token is required" });
  }

  if (!jwtSecret) {
    return res.status(500).json({ message: "JWT_SECRET is not configured" });
  }

  try {
    const admin = ensureFirebase();
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const phone = decodedToken.phone_number;

    if (!phone) {
      return res.status(400).json({ message: "Phone number missing in Firebase token" });
    }

    let userResult = await pool.query(
      `SELECT id, name, phone, email, role, agency_id, language, theme, created_at
       FROM users
       WHERE phone = $1
       LIMIT 1`,
      [phone]
    );

    if (!userResult.rows.length) {
      userResult = await pool.query(
        `INSERT INTO users (name, phone, role, language)
         VALUES ($1, $2, 'customer', 'hi')
         RETURNING id, name, phone, email, role, agency_id, language, theme, created_at`,
        [decodedToken.name || "Customer", phone]
      );
    }

    const user = userResult.rows[0];

    const token = jwt.sign(
      {
        sub: user.id,
        uid: decodedToken.uid,
        phone: user.phone,
        role: user.role,
        agency_id: user.agency_id,
      },
      jwtSecret,
      { expiresIn: "7d" }
    );

    return res.status(200).json({ user, token });
  } catch (error) {
    return res.status(401).json({
      message: error.message || "Invalid Firebase token",
    });
  }
});

module.exports = router;
