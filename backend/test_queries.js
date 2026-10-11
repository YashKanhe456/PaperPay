require('dotenv').config();
const pool = require('./src/db/pool');

async function run() {
  try {
    const res = await pool.query(`SELECT id FROM agencies LIMIT 1`);
    const agencyId = res.rows[0].id;
    console.log("Testing with agencyId:", agencyId);
    
    // Just run the same logic from reports.js
    const start = Date.now();
    const dashboardStats = await pool.query(
      `SELECT COUNT(*)::int AS overdue_count
       FROM bills
       WHERE agency_id = $1
         AND status IN ('unpaid', 'partial')
         AND due_date < CURRENT_DATE`,
      [agencyId]
    );
    console.log("Overdue query passed");

    const delRes = await pool.query(
        `SELECT
           COUNT(*) FILTER (WHERE d.status <> 'pending')::int AS deliveries_done_today,
           COUNT(*)::int AS deliveries_total_today
         FROM deliveries d
         INNER JOIN customers c ON c.id = d.customer_id
         WHERE c.agency_id = $1
           AND d.date = CURRENT_DATE`,
        [agencyId]
      );
    console.log("Deliveries query passed");

    console.log("All dashboard queries passed. Time:", Date.now() - start, "ms");
  } catch(e) {
    console.error("Test queries failed:", e);
  } finally {
    pool.end();
  }
}

run();
