const cron = require("node-cron");

const pool = require("../db/pool");
const { generateBillsForAgency } = require("../services/billing");

cron.schedule("0 6 1 * *", async () => {
  const now = new Date();
  const month = now.getMonth() + 1;
  const year = now.getFullYear();

  try {
    const result = await pool.query(
      `SELECT id
       FROM agencies
       WHERE status = 'active'`
    );

    for (const agency of result.rows) {
      await generateBillsForAgency(agency.id, month, year);
    }
  } catch (error) {
    console.error("Bill cron failed:", error.message);
  }
});
