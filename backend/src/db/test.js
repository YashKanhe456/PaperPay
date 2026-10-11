require("dotenv").config();

const pool = require("./pool");

async function run() {
  try {
    const [usersResult, customersResult, newspapersResult] = await Promise.all([
      pool.query("SELECT COUNT(*) FROM users"),
      pool.query("SELECT COUNT(*) FROM customers"),
      pool.query("SELECT COUNT(*) FROM newspapers"),
    ]);

    console.log("NeonDB connection successful.");
    console.log(`Users: ${usersResult.rows[0].count}`);
    console.log(`Customers: ${customersResult.rows[0].count}`);
    console.log(`Newspapers: ${newspapersResult.rows[0].count}`);
  } catch (error) {
    console.error("Database test failed:", error.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

run();
