const express = require("express");

const auth = require("../middleware/auth");
const { requireRole } = require("../middleware/requireRole");
const pool = require("../db/pool");

const router = express.Router();

// Agency settings are administrative data.
router.use(auth, requireRole("agency_admin"));

// GET /api/settings?agency_id=
router.get("/", async (req, res) => {
  const agencyId = req.query.agency_id || req.user.agency_id;

  if (!agencyId) {
    return res.status(400).json({ success: false, message: "agency_id is required" });
  }

  if (agencyId !== req.user.agency_id) {
    return res.status(403).json({ success: false, message: "Agency access denied" });
  }

  try {
    const result = await pool.query(
      `SELECT key, value FROM settings WHERE agency_id = $1`,
      [agencyId],
    );

    // Convert key-value rows to a single object
    const settings = result.rows.reduce((acc, row) => {
      acc[row.key] = row.value;
      return acc;
    }, {});

    // Defaults
    const defaults = {
      due_date_day: "10",
      late_fee_amount: "20",
      auto_generate_bills: "true",
      language: "hi",
      theme: "light",
      notifications_enabled: "true",
    };

    return res.status(200).json({
      success: true,
      data: { settings: { ...defaults, ...settings } },
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to fetch settings" });
  }
});

// PUT /api/settings
router.put("/", async (req, res) => {
  const agencyId = req.user.agency_id;
  if (!agencyId) {
    return res.status(403).json({ success: false, message: "Agency access denied" });
  }

  const { settings } = req.body;
  if (!settings || typeof settings !== "object") {
    return res.status(400).json({ success: false, message: "settings object is required" });
  }

  try {
    const client = await pool.connect();
    try {
      await client.query("BEGIN");

      for (const [key, value] of Object.entries(settings)) {
        await client.query(
          `INSERT INTO settings (agency_id, key, value, updated_at)
           VALUES ($1, $2, $3, NOW())
           ON CONFLICT (agency_id, key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()`,
          [agencyId, key, String(value)],
        );
      }

      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }

    return res.status(200).json({ success: true, data: { message: "Settings saved" } });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to save settings" });
  }
});

module.exports = router;
