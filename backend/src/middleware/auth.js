"use strict";

const { ensureFirebase } = require("../config/firebase");
const pool = require("../db/pool");

async function loadUserById(id) {
  const client = await pool.connect();
  try {
    const { rows } = await client.query(
      `SELECT id, name, phone, role, agency_id
       FROM users
       WHERE id = $1
       LIMIT 1`,
      [id]
    );
    return rows[0] || null;
  } finally {
    client.release();
  }
}

async function loadUserByPhone(phone) {
  const client = await pool.connect();
  try {
    const { rows } = await client.query(
      `SELECT id, name, phone, role, agency_id
       FROM users
       WHERE phone = $1
       LIMIT 1`,
      [phone]
    );
    return rows[0] || null;
  } finally {
    client.release();
  }
}

async function auth(req, res, next) {
  const authHeader = req.headers.authorization || "";

  if (!authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ message: "Authorization token missing" });
  }

  const idToken = authHeader.replace("Bearer ", "").trim();

  if (!idToken) {
    return res.status(401).json({ message: "Authorization token missing" });
  }

  try {
    const admin = ensureFirebase();
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const phone = decodedToken.phone_number || null;

    let user = null;
    if (phone) {
      try {
        user = await loadUserByPhone(phone);
      } catch (dbErr) {
        // If the database is not reachable yet, fall back to the Firebase
        // phone claim so the API can still authorise the token when the
        // caller only needs a recognized phone/role from Firebase.
        console.warn("auth: database lookup failed, using Firebase claim only");
      }
    }

    req.user = {
      uid: decodedToken.uid,
      phone,
      id: user?.id || null,
      name: user?.name || decodedToken.name || null,
      role: user?.role || null,
      agency_id: user?.agency_id || null,
    };

    return next();
  } catch (error) {
    return res.status(401).json({ message: "Invalid or expired token" });
  }
}

module.exports = auth;
