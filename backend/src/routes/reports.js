const express = require("express");

const auth = require("../middleware/auth");
const agencyAccess = require("../middleware/agencyAccess");
const { requireRole } = require("../middleware/requireRole");
const pool = require("../db/pool");

const router = express.Router();

// Reports expose agency-wide business data — admins only.
router.use(auth, requireRole("agency_admin"));

function monthBounds(month, year) {
  return {
    start: new Date(Date.UTC(year, month - 1, 1)).toISOString().slice(0, 10),
    end: new Date(Date.UTC(year, month, 0)).toISOString().slice(0, 10),
  };
}

router.get("/dashboard", agencyAccess(), async (req, res) => {
  const { agency_id: agencyId } = req.query;

  if (!agencyId) {
    return res.status(400).json({ message: "agency_id is required" });
  }

  try {
    const [
      customersResult,
      todayCollectionResult,
      pendingDuesResult,
      deliveriesResult,
      overdueResult,
      monthlyRevenueResult,
      collectionRateResult,
      activityResult,
    ] = await Promise.all([
      pool.query(
        `SELECT COUNT(*)::int AS total_customers
         FROM customers
         WHERE agency_id = $1
           AND status = 'active'`,
        [agencyId]
      ),
      pool.query(
        `SELECT COALESCE(SUM(p.amount), 0)::numeric(10,2) AS today_collection
         FROM payments p
         INNER JOIN bills b ON b.id = p.bill_id
         WHERE b.agency_id = $1
           AND DATE(COALESCE(p.paid_at, NOW())) = CURRENT_DATE
           AND p.status IN ('success', 'cash_received')`,
        [agencyId]
      ),
      pool.query(
        `SELECT COALESCE(SUM(total_outstanding), 0)::numeric(10,2) AS pending_dues
         FROM customers
         WHERE agency_id = $1`,
        [agencyId]
      ),
      pool.query(
        `SELECT
           COUNT(*) FILTER (WHERE d.status <> 'pending')::int AS deliveries_done_today,
           COUNT(*)::int AS deliveries_total_today
         FROM deliveries d
         INNER JOIN customers c ON c.id = d.customer_id
         WHERE c.agency_id = $1
           AND d.date = CURRENT_DATE`,
        [agencyId]
      ),
      pool.query(
        `SELECT COUNT(*)::int AS overdue_count
         FROM bills
         WHERE agency_id = $1
           AND status IN ('unpaid', 'partial')
           AND due_date < CURRENT_DATE`,
        [agencyId]
      ),
      pool.query(
        `SELECT COALESCE(SUM(p.amount), 0)::numeric(10,2) AS monthly_revenue
         FROM payments p
         INNER JOIN bills b ON b.id = p.bill_id
         WHERE b.agency_id = $1
           AND EXTRACT(MONTH FROM COALESCE(p.paid_at, NOW())) = EXTRACT(MONTH FROM CURRENT_DATE)
           AND EXTRACT(YEAR FROM COALESCE(p.paid_at, NOW())) = EXTRACT(YEAR FROM CURRENT_DATE)
           AND p.status IN ('success', 'cash_received')`,
        [agencyId]
      ),
      pool.query(
        `SELECT
           COALESCE(SUM(CASE WHEN p.status IN ('success', 'cash_received') THEN p.amount ELSE 0 END), 0)::numeric(10,2) AS collected,
           COALESCE(SUM(b.final_amount), 0)::numeric(10,2) AS billed
         FROM bills b
         LEFT JOIN payments p ON p.bill_id = b.id
         WHERE b.agency_id = $1
           AND EXTRACT(MONTH FROM b.generated_at) = EXTRACT(MONTH FROM CURRENT_DATE)
           AND EXTRACT(YEAR FROM b.generated_at) = EXTRACT(YEAR FROM CURRENT_DATE)`,
        [agencyId]
      ),
      pool.query(
        `SELECT action, entity, timestamp
         FROM audit_logs
         WHERE user_id IN (
           SELECT id FROM users WHERE agency_id = $1
         )
         ORDER BY timestamp DESC
         LIMIT 10`,
        [agencyId]
      ),
    ]);

    const billed = Number(collectionRateResult.rows[0].billed || 0);
    const collected = Number(collectionRateResult.rows[0].collected || 0);

    return res.status(200).json({
      total_customers: customersResult.rows[0].total_customers,
      today_collection: Number(todayCollectionResult.rows[0].today_collection || 0),
      pending_dues: Number(pendingDuesResult.rows[0].pending_dues || 0),
      deliveries_done_today: deliveriesResult.rows[0].deliveries_done_today,
      deliveries_total_today: deliveriesResult.rows[0].deliveries_total_today,
      overdue_count: overdueResult.rows[0].overdue_count,
      monthly_revenue: Number(monthlyRevenueResult.rows[0].monthly_revenue || 0),
      collection_rate: billed > 0 ? Number(((collected / billed) * 100).toFixed(2)) : 0,
      recent_activity: activityResult.rows,
    });
  } catch (error) {
    console.error("DASHBOARD ERROR:", error);
    return res.status(500).json({ message: "Failed to fetch dashboard report" });
  }
});

router.get("/monthly", agencyAccess(), async (req, res) => {
  const { agency_id: agencyId, year } = req.query;

  if (!agencyId || !year) {
    return res.status(400).json({ message: "agency_id and year are required" });
  }

  try {
    const result = await pool.query(
      `SELECT
         m.month,
         COALESCE(SUM(b.final_amount), 0)::numeric(10,2) AS billed,
         COALESCE(SUM(CASE WHEN p.status IN ('success', 'cash_received') THEN p.amount ELSE 0 END), 0)::numeric(10,2) AS collected
       FROM generate_series(1, 12) AS m(month)
       LEFT JOIN bills b
         ON b.agency_id = $1
        AND b.month = m.month
        AND b.year = $2
       LEFT JOIN payments p
         ON p.bill_id = b.id
       GROUP BY m.month
       ORDER BY m.month`,
      [agencyId, Number(year)]
    );

    const data = result.rows.map((row) => {
      const billed = Number(row.billed || 0);
      const collected = Number(row.collected || 0);
      return {
        month: Number(row.month),
        billed,
        collected,
        pending: Number((billed - collected).toFixed(2)),
      };
    });

    return res.status(200).json({ months: data });
  } catch (error) {
    console.error("MONTHLY REPORT ERROR:", error);
    return res.status(500).json({ message: "Failed to fetch monthly report" });
  }
});

router.get("/collection", agencyAccess(), async (req, res) => {
  const { agency_id: agencyId, month, year } = req.query;

  if (!agencyId || !month || !year) {
    return res.status(400).json({ message: "agency_id, month, and year are required" });
  }

  try {
    const [totals, paperBreakdown, areaBreakdown, modeBreakdown] = await Promise.all([
      pool.query(
        `SELECT
           COALESCE(SUM(b.final_amount), 0)::numeric(10,2) AS total_billed,
           COALESCE(SUM(CASE WHEN p.status IN ('success', 'cash_received') THEN p.amount ELSE 0 END), 0)::numeric(10,2) AS total_collected
         FROM bills b
         LEFT JOIN payments p ON p.bill_id = b.id
         WHERE b.agency_id = $1
           AND b.month = $2
           AND b.year = $3`,
        [agencyId, Number(month), Number(year)]
      ),
      pool.query(
        `SELECT
           n.name AS newspaper,
           COALESCE(SUM(s.rate), 0)::numeric(10,2) AS billed,
           COALESCE(SUM(CASE WHEN p.status IN ('success', 'cash_received') THEN p.amount ELSE 0 END), 0)::numeric(10,2) AS collected
         FROM subscriptions s
         INNER JOIN customers c ON c.id = s.customer_id
         INNER JOIN newspapers n ON n.id = s.newspaper_id
         LEFT JOIN bills b
           ON b.customer_id = c.id
          AND b.month = $2
          AND b.year = $3
         LEFT JOIN payments p ON p.bill_id = b.id
         WHERE c.agency_id = $1
         GROUP BY n.name
         ORDER BY n.name`,
        [agencyId, Number(month), Number(year)]
      ),
      pool.query(
        `SELECT
           c.area,
           COALESCE(SUM(b.final_amount), 0)::numeric(10,2) AS billed,
           COALESCE(SUM(CASE WHEN p.status IN ('success', 'cash_received') THEN p.amount ELSE 0 END), 0)::numeric(10,2) AS collected
         FROM customers c
         LEFT JOIN bills b
           ON b.customer_id = c.id
          AND b.month = $2
          AND b.year = $3
         LEFT JOIN payments p ON p.bill_id = b.id
         WHERE c.agency_id = $1
         GROUP BY c.area
         ORDER BY c.area`,
        [agencyId, Number(month), Number(year)]
      ),
      pool.query(
        `SELECT
           COALESCE(mode, 'unknown') AS mode,
           COALESCE(SUM(amount), 0)::numeric(10,2) AS amount
         FROM payments p
         INNER JOIN bills b ON b.id = p.bill_id
         WHERE b.agency_id = $1
           AND b.month = $2
           AND b.year = $3
           AND p.status IN ('success', 'cash_received')
         GROUP BY COALESCE(mode, 'unknown')
         ORDER BY amount DESC`,
        [agencyId, Number(month), Number(year)]
      ),
    ]);

    const totalBilled = Number(totals.rows[0].total_billed || 0);
    const totalCollected = Number(totals.rows[0].total_collected || 0);

    return res.status(200).json({
      total_billed: totalBilled,
      total_collected: totalCollected,
      rate: totalBilled > 0 ? Number(((totalCollected / totalBilled) * 100).toFixed(2)) : 0,
      paper_wise: paperBreakdown.rows.map((row) => ({
        newspaper: row.newspaper,
        billed: Number(row.billed || 0),
        collected: Number(row.collected || 0),
      })),
      area_wise: areaBreakdown.rows.map((row) => ({
        area: row.area,
        billed: Number(row.billed || 0),
        collected: Number(row.collected || 0),
      })),
      payment_mode_wise: modeBreakdown.rows.map((row) => ({
        mode: row.mode,
        amount: Number(row.amount || 0),
      })),
    });
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch collection report" });
  }
});

router.get("/pl", agencyAccess(), async (req, res) => {
  const { agency_id: agencyId, month, year } = req.query;

  if (!agencyId || !month || !year) {
    return res.status(400).json({ message: "agency_id, month, and year are required" });
  }

  try {
    const [revenueResult, expenseResult, newspaperMarginResult] = await Promise.all([
      pool.query(
        `SELECT COALESCE(SUM(p.amount), 0)::numeric(10,2) AS revenue
         FROM payments p
         INNER JOIN bills b ON b.id = p.bill_id
         WHERE b.agency_id = $1
           AND b.month = $2
           AND b.year = $3
           AND p.status IN ('success', 'cash_received')`,
        [agencyId, Number(month), Number(year)]
      ),
      pool.query(
        `SELECT COALESCE(SUM(amount), 0)::numeric(10,2) AS expenses
         FROM expenses
         WHERE agency_id = $1
           AND EXTRACT(MONTH FROM date) = $2
           AND EXTRACT(YEAR FROM date) = $3`,
        [agencyId, Number(month), Number(year)]
      ),
      pool.query(
        `SELECT
           n.name AS newspaper,
           COALESCE(SUM(n.selling_price - COALESCE(n.cost_price, 0)), 0)::numeric(10,2) AS margin_amount,
           COALESCE(SUM(n.selling_price), 0)::numeric(10,2) AS sales_value
         FROM subscriptions s
         INNER JOIN customers c ON c.id = s.customer_id
         INNER JOIN newspapers n ON n.id = s.newspaper_id
         WHERE c.agency_id = $1
         GROUP BY n.name
         ORDER BY n.name`,
        [agencyId]
      ),
    ]);

    const revenue = Number(revenueResult.rows[0].revenue || 0);
    const expenses = Number(expenseResult.rows[0].expenses || 0);

    return res.status(200).json({
      revenue,
      expenses,
      profit: Number((revenue - expenses).toFixed(2)),
      newspaper_margins: newspaperMarginResult.rows.map((row) => {
        const salesValue = Number(row.sales_value || 0);
        const marginAmount = Number(row.margin_amount || 0);
        return {
          newspaper: row.newspaper,
          margin_amount: marginAmount,
          margin_percent: salesValue > 0 ? Number(((marginAmount / salesValue) * 100).toFixed(2)) : 0,
        };
      }),
    });
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch P&L report" });
  }
});

router.get("/delivery", agencyAccess(), async (req, res) => {
  const { agency_id: agencyId, month, year } = req.query;

  if (!agencyId || !month || !year) {
    return res.status(400).json({ message: "agency_id, month, and year are required" });
  }

  try {
    const result = await pool.query(
      `SELECT
         COALESCE(NULLIF(c.area, ''), 'Unassigned') AS delivery_boy_name,
         COUNT(d.id)::int AS total_deliveries,
         COUNT(*) FILTER (WHERE d.status = 'delivered')::int AS delivered_count,
         COUNT(*) FILTER (WHERE d.status = 'missed')::int AS missed_count,
         COUNT(*) FILTER (
           WHERE d.status = 'delivered' AND d.photo_proof_url IS NOT NULL
         )::int AS photo_count
       FROM deliveries d
       INNER JOIN customers c ON c.id = d.customer_id
       WHERE c.agency_id = $1
         AND EXTRACT(MONTH FROM d.date) = $2
         AND EXTRACT(YEAR FROM d.date) = $3
       GROUP BY COALESCE(NULLIF(c.area, ''), 'Unassigned')
       ORDER BY delivery_boy_name`,
      [agencyId, Number(month), Number(year)]
    );

    return res.status(200).json({
      delivery_performance: result.rows.map((row) => {
        const total = Number(row.total_deliveries || 0);
        const delivered = Number(row.delivered_count || 0);
        const photoCount = Number(row.photo_count || 0);
        return {
          delivery_boy_id: row.delivery_boy_name.toLowerCase().replace(/\s+/g, "_"),
          delivery_boy_name: row.delivery_boy_name,
          success_rate: total > 0 ? Number(((delivered / total) * 100).toFixed(2)) : 0,
          missed_count: Number(row.missed_count || 0),
          photo_compliance_rate: delivered > 0 ? Number(((photoCount / delivered) * 100).toFixed(2)) : 0,
        };
      }),
    });
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch delivery report" });
  }
});

module.exports = router;
