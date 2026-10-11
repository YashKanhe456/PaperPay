"use strict";

const express = require("express");

const auth = require("../middleware/auth");
const pool = require("../db/pool");

const router = express.Router();

function normalizePhone(phone) {
  const digits = String(phone || "").replace(/\D/g, "");
  if (/^[6-9]\d{9}$/.test(digits)) {
    return `91${digits}`;
  }
  if (/^91[6-9]\d{9}$/.test(digits)) {
    return digits;
  }
  return null;
}

// POST /api/notifications/register-token  — authenticated user registers own FCM token
router.post("/register-token", auth, async (req, res) => {
  const { fcm_token: fcmToken } = req.body;

  if (!fcmToken) {
    return res.status(400).json({ success: false, message: "fcm_token is required" });
  }

  try {
    await pool.query(
      `UPDATE users SET fcm_token = $1 WHERE id = $2`,
      [fcmToken, req.user.id],
    );

    return res.status(200).json({ success: true, data: { message: "FCM token registered" } });
  } catch (error) {
    if (error.code === "42703") {
      return res.status(200).json({
        success: true,
        data: { message: "FCM token not stored: column not found. Run migration." },
      });
    }
    return res.status(500).json({ success: false, message: "Failed to register FCM token" });
  }
});

// POST /api/notifications/send — agency admin only; targets users in the same agency
router.post("/send", auth, async (req, res) => {
  const userRole = req.user?.role;
  if (userRole !== "agency_admin") {
    return res.status(403).json({ success: false, message: "Access denied" });
  }

  const { user_id: userId, title, message, type } = req.body;

  if (!userId || !title || !message) {
    return res.status(400).json({ success: false, message: "user_id, title, and message are required" });
  }

  try {
    const userResult = await pool.query(
      `SELECT id, fcm_token, agency_id
       FROM users
       WHERE id = $1 AND agency_id = $2
       LIMIT 1`,
      [userId, req.user.agency_id],
    );

    const user = userResult.rows[0];

    if (!user) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    const fcmToken = user.fcm_token || null;

    const notifResult = await pool.query(
      `INSERT INTO notifications (user_id, title, message, type, channel, status, sent_at)
       VALUES ($1, $2, $3, $4, 'push', $5, NOW())
       RETURNING id`,
      [userId, title, message, type || "general", fcmToken ? "sent" : "pending"],
    );

    if (fcmToken) {
      try {
        const admin = require("../config/firebase").ensureFirebase();
        await admin.messaging().send({
          token: fcmToken,
          notification: { title, body: message },
          data: { type: type || "general", notification_id: notifResult.rows[0].id },
        });
      } catch (fcmError) {
        await pool.query(
          `UPDATE notifications SET status = 'failed' WHERE id = $1`,
          [notifResult.rows[0].id],
        );
      }
    }

    return res.status(200).json({ success: true, data: { notification_id: notifResult.rows[0].id } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to send notification" });
  }
});

// POST /api/notifications/send-reminder — agency admin only; targets unpaid bills in the same agency
router.post("/send-reminder", auth, async (req, res) => {
  const userRole = req.user?.role;
  if (userRole !== "agency_admin") {
    return res.status(403).json({ success: false, message: "Access denied" });
  }

  const { agency_id: agencyId, bill_ids: billIds, channel } = req.body;

  if (!agencyId || !Array.isArray(billIds) || !billIds.length) {
    return res.status(400).json({ success: false, message: "agency_id and bill_ids are required" });
  }

  if (agencyId !== req.user.agency_id) {
    return res.status(403).json({ success: false, message: "Agency access denied" });
  }

  try {
    const billsResult = await pool.query(
      `SELECT
         b.id,
         b.final_amount,
         b.due_date,
         c.id AS customer_id,
         c.name AS customer_name,
         c.phone
       FROM bills b
       INNER JOIN customers c ON c.id = b.customer_id
       WHERE b.id = ANY($1::uuid[])
         AND c.agency_id = $2`,
      [billIds, agencyId],
    );

    if (!billsResult.rows.length) {
      return res.status(404).json({ success: false, message: "Bills not found" });
    }

    const reminders = [];
    for (const row of billsResult.rows) {
      const phone = normalizePhone(row.phone);
      const dueDate = row.due_date
        ? new Date(row.due_date).toLocaleDateString("en-IN", {
            day: "2-digit",
            month: "short",
            year: "numeric",
          })
        : "";
      const message = `${row.customer_name} ji, ${Number(row.final_amount || 0).toFixed(0)} baaki hai.${dueDate ? ` Due: ${dueDate}.` : ""}`;
      const link = phone
        ? `https://wa.me/${phone}?text=${encodeURIComponent(message)}`
        : null;

      const insertResult = await pool.query(
        `INSERT INTO notifications (user_id, title, message, type, channel, status, sent_at)
         VALUES (
           (SELECT id FROM users WHERE phone = c.phone LIMIT 1),
           $1,
           $2,
           'payment_reminder',
           $3,
           'sent',
           NOW()
         )
         FROM customers c
         WHERE c.id = $4
         RETURNING id`,
        ["Payment Reminder", message, channel || "whatsapp", row.customer_id],
      );

      reminders.push({
        bill_id: row.id,
        customer_id: row.customer_id,
        message,
        link,
        notification_id: insertResult.rows[0]?.id ?? null,
      });
    }

    return res.status(200).json({ success: true, reminders });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to send reminders" });
  }
});

// GET /api/notifications — authenticated user can read their own notifications
router.get("/", auth, async (req, res) => {
  const userId = req.query.user_id;

  if (userId) {
    if (req.user.role !== "agency_admin") {
      return res.status(403).json({ success: false, message: "Access denied" });
    }
    if (userId !== req.user.id) {
      return res.status(403).json({ success: false, message: "Access denied" });
    }
  }

  const targetId = userId || req.user.id;

  try {
    const result = await pool.query(
      `SELECT *
       FROM notifications
       WHERE user_id = $1
       ORDER BY COALESCE(sent_at, read_at) DESC NULLS LAST
       LIMIT 100`,
      [targetId],
    );
    return res.status(200).json({ success: true, notifications: result.rows });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to fetch notifications" });
  }
});

module.exports = router;
