const pool = require("../db/pool");

const CUSTOMER_FIELDS = [
  "name",
  "phone",
  "email",
  "address",
  "area",
  "landmark",
  "gps_lat",
  "gps_lng",
  "alt_contact",
  "category",
  "status",
  "start_date",
  "total_outstanding",
  "lifetime_value",
  "notes",
  "agency_id",
];

function getClientIp(req) {
  const forwarded = req.headers["x-forwarded-for"];

  if (typeof forwarded === "string" && forwarded.length) {
    return forwarded.split(",")[0].trim();
  }

  return req.ip || null;
}

async function logAudit({
  userId,
  action,
  entity,
  entityId,
  oldValue = null,
  newValue = null,
  ip = null,
}) {
  await pool.query(
    `INSERT INTO audit_logs (user_id, action, entity, entity_id, old_value, new_value, ip)
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [userId, action, entity, entityId, oldValue, newValue, ip]
  );
}

function normalizeIndianPhone(phone) {
  const digits = String(phone || "").replace(/\D/g, "");

  if (/^[6-9]\d{9}$/.test(digits)) {
    return `+91${digits}`;
  }

  if (/^91[6-9]\d{9}$/.test(digits)) {
    return `+${digits}`;
  }

  return null;
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

async function listCustomers(req, res) {
  const { agency_id: agencyId, search, category, area, status } = req.query;
  const page = Math.max(Number.parseInt(req.query.page || "1", 10), 1);
  const limit = clamp(Number.parseInt(req.query.limit || "20", 10), 1, 100);
  const offset = (page - 1) * limit;

  if (!agencyId) {
    return res.status(400).json({ message: "agency_id is required" });
  }

  try {
    const filters = ["agency_id = $1"];
    const values = [agencyId];

    if (search) {
      values.push(`%${search.trim()}%`);
      values.push(search.replace(/\D/g, ""));
      const nameIndex = values.length - 1;
      const phoneIndex = values.length;
      filters.push(
        `(name ILIKE $${nameIndex} OR regexp_replace(phone, '\\D', '', 'g') LIKE '%' || $${phoneIndex} || '%')`
      );
    }

    if (category) {
      values.push(category);
      filters.push(`category = $${values.length}`);
    }

    if (area) {
      values.push(area);
      filters.push(`area = $${values.length}`);
    }

    if (status) {
      values.push(status);
      filters.push(`status = $${values.length}`);
    }

    const whereClause = filters.join(" AND ");

    const countResult = await pool.query(
      `SELECT COUNT(*)::int AS total
       FROM customers
       WHERE ${whereClause}`,
      values
    );

    values.push(limit, offset);

    const customerResult = await pool.query(
      `SELECT
         id,
         agency_id,
         name,
         phone,
         email,
         address,
         area,
         landmark,
         gps_lat,
         gps_lng,
         alt_contact,
         category,
         status,
         start_date,
         total_outstanding,
         lifetime_value,
         notes,
         created_at
       FROM customers
       WHERE ${whereClause}
       ORDER BY created_at DESC, name ASC
       LIMIT $${values.length - 1}
       OFFSET $${values.length}`,
      values
    );

    return res.status(200).json({
      customers: customerResult.rows,
      total_count: countResult.rows[0].total,
      page,
      limit,
    });
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch customers" });
  }
}

async function createCustomer(req, res) {
  const {
    name,
    phone,
    agency_id: agencyId,
    email,
    address,
    area,
    landmark,
    gps_lat,
    gps_lng,
    alt_contact,
    notes,
  } = req.body;

  if (!name || !phone || !agencyId) {
    return res.status(400).json({ message: "name, phone, and agency_id are required" });
  }

  const normalizedPhone = normalizeIndianPhone(phone);

  if (!normalizedPhone) {
    return res.status(400).json({ message: "Phone must be a valid 10-digit Indian number" });
  }

  const normalizedAltContact = alt_contact ? normalizeIndianPhone(alt_contact) : null;

  if (alt_contact && !normalizedAltContact) {
    return res.status(400).json({ message: "alt_contact must be a valid 10-digit Indian number" });
  }

  if (req.user.agency_id !== agencyId) {
    return res.status(403).json({ message: "Agency access denied" });
  }

  try {
    const existingCustomer = await pool.query(
      `SELECT id
       FROM customers
       WHERE agency_id = $1 AND phone = $2
       LIMIT 1`,
      [agencyId, normalizedPhone]
    );

    if (existingCustomer.rows.length) {
      return res.status(409).json({ message: "Customer with this phone already exists" });
    }

    const result = await pool.query(
      `INSERT INTO customers (
         agency_id, name, phone, email, address, area, landmark,
         gps_lat, gps_lng, alt_contact, category, status, notes, start_date
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'New', 'active', $11, CURRENT_DATE)
       RETURNING *`,
      [
        agencyId,
        name,
        normalizedPhone,
        email || null,
        address || null,
        area || null,
        landmark || null,
        gps_lat || null,
        gps_lng || null,
        normalizedAltContact,
        notes || null,
      ]
    );

    await logAudit({
      userId: req.user.id,
      action: "customer_created",
      entity: "customer",
      entityId: result.rows[0].id,
      newValue: result.rows[0],
      ip: getClientIp(req),
    });

    return res.status(201).json({ customer: result.rows[0] });
  } catch (error) {
    return res.status(500).json({ message: "Failed to create customer" });
  }
}

async function getCustomerHealthScore(customerId) {
  const [billingResult, deliveryResult, referralResult, tenureResult] = await Promise.all([
    pool.query(
      `SELECT
         COUNT(*)::int AS total_bills,
         COUNT(*) FILTER (WHERE status = 'paid')::int AS paid_bills
       FROM bills
       WHERE customer_id = $1
         AND generated_at >= NOW() - INTERVAL '6 months'`,
      [customerId]
    ),
    pool.query(
      `SELECT
         COUNT(*)::int AS total_deliveries,
         COUNT(*) FILTER (
           WHERE status IN ('missed', 'wrong_paper', 'wet_paper', 'pending')
         )::int AS issue_deliveries
       FROM deliveries
       WHERE customer_id = $1
         AND date >= CURRENT_DATE - INTERVAL '30 days'`,
      [customerId]
    ),
    pool.query(
      `SELECT COUNT(*)::int AS referral_count
       FROM referrals
       WHERE referrer_id = $1`,
      [customerId]
    ),
    pool.query(
      `SELECT GREATEST(
         0,
         FLOOR(EXTRACT(DAY FROM (CURRENT_DATE - COALESCE(start_date, CURRENT_DATE))) / 30)
       )::int AS tenure_months
       FROM customers
       WHERE id = $1`,
      [customerId]
    ),
  ]);

  const billing = billingResult.rows[0];
  const delivery = deliveryResult.rows[0];
  const referrals = referralResult.rows[0];
  const tenure = tenureResult.rows[0];

  const paymentScore =
    Number(billing.total_bills) > 0
      ? (Number(billing.paid_bills) / Number(billing.total_bills)) * 40
      : 40;

  const deliveryScore =
    Number(delivery.total_deliveries) > 0
      ? (1 - Number(delivery.issue_deliveries) / Number(delivery.total_deliveries)) * 20
      : 20;

  const tenureScore = Math.min(Number(tenure.tenure_months) / 12, 1) * 20;
  const referralScore = Math.min(Number(referrals.referral_count) / 5, 1) * 20;

  return {
    score: Math.round(
      clamp(paymentScore, 0, 40) +
        clamp(deliveryScore, 0, 20) +
        clamp(tenureScore, 0, 20) +
        clamp(referralScore, 0, 20)
    ),
    breakdown: {
      payment_history: Math.round(clamp(paymentScore, 0, 40)),
      delivery_issues: Math.round(clamp(deliveryScore, 0, 20)),
      tenure_months: Math.round(clamp(tenureScore, 0, 20)),
      referrals_made: Math.round(clamp(referralScore, 0, 20)),
    },
  };
}

async function getCustomerById(req, res) {
  const { id } = req.params;

  try {
    const customerResult = await pool.query(
      `SELECT *
       FROM customers
       WHERE id = $1
       LIMIT 1`,
      [id]
    );

    if (!customerResult.rows.length) {
      return res.status(404).json({ message: "Customer not found" });
    }

    const customer = customerResult.rows[0];

    const [subscriptionsResult, billsResult, paymentsResult, healthScore] = await Promise.all([
      pool.query(
        `SELECT
           s.id,
           s.newspaper_id,
           n.name AS newspaper_name,
           s.rate,
           s.start_date,
           s.end_date,
           s.status,
           s.plan_type,
           s.auto_renew,
           s.pause_from,
           s.pause_to
         FROM subscriptions s
         INNER JOIN newspapers n ON n.id = s.newspaper_id
         WHERE s.customer_id = $1
           AND s.status = 'active'
         ORDER BY n.name`,
        [id]
      ),
      pool.query(
        `SELECT
           id,
           month,
           year,
           final_amount,
           due_date,
           status,
           generated_at,
           paid_at
         FROM bills
         WHERE customer_id = $1
         ORDER BY year DESC, month DESC, generated_at DESC
         LIMIT 3`,
        [id]
      ),
      pool.query(
        `SELECT
           p.id,
           p.amount,
           p.mode,
           p.status,
           p.gateway,
           p.paid_at,
           p.notes,
           b.id AS bill_id,
           b.month,
           b.year
         FROM payments p
         LEFT JOIN bills b ON b.id = p.bill_id
         WHERE p.customer_id = $1
           AND COALESCE(p.paid_at, NOW()) >= NOW() - INTERVAL '6 months'
         ORDER BY COALESCE(p.paid_at, NOW()) DESC`,
        [id]
      ),
      getCustomerHealthScore(id),
    ]);

    return res.status(200).json({
      customer,
      subscriptions: subscriptionsResult.rows,
      recent_bills: billsResult.rows,
      payment_history: paymentsResult.rows,
      health_score: healthScore,
    });
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch customer detail" });
  }
}

async function updateCustomer(req, res) {
  const { id } = req.params;

  try {
    const existingResult = await pool.query(
      `SELECT *
       FROM customers
       WHERE id = $1
       LIMIT 1`,
      [id]
    );

    if (!existingResult.rows.length) {
      return res.status(404).json({ message: "Customer not found" });
    }

    const existingCustomer = existingResult.rows[0];

    const updates = [];
    const values = [];

    for (const field of CUSTOMER_FIELDS) {
      if (!(field in req.body)) {
        continue;
      }

      let value = req.body[field];

      if (field === "phone") {
        value = normalizeIndianPhone(value);

        if (!value) {
          return res.status(400).json({ message: "Phone must be a valid 10-digit Indian number" });
        }
      }

      if (field === "alt_contact" && value) {
        value = normalizeIndianPhone(value);

        if (!value) {
          return res.status(400).json({ message: "alt_contact must be a valid 10-digit Indian number" });
        }
      }

      if (field === "agency_id" && value !== req.user.agency_id) {
        return res.status(403).json({ message: "Agency access denied" });
      }

      values.push(value);
      updates.push(`${field} = $${values.length}`);
    }

    if (!updates.length) {
      return res.status(400).json({ message: "No valid customer fields provided" });
    }

    values.push(id);

    const result = await pool.query(
      `UPDATE customers
       SET ${updates.join(", ")}
       WHERE id = $${values.length}
       RETURNING *`,
      values
    );

    await logAudit({
      userId: req.user.id,
      action: "customer_updated",
      entity: "customer",
      entityId: id,
      oldValue: existingCustomer,
      newValue: result.rows[0],
      ip: getClientIp(req),
    });

    return res.status(200).json({ customer: result.rows[0] });
  } catch (error) {
    return res.status(500).json({ message: "Failed to update customer" });
  }
}

async function deleteCustomer(req, res) {
  const { id } = req.params;

  try {
    const existingResult = await pool.query(
      `SELECT *
       FROM customers
       WHERE id = $1
       LIMIT 1`,
      [id]
    );

    if (!existingResult.rows.length) {
      return res.status(404).json({ message: "Customer not found" });
    }

    const result = await pool.query(
      `UPDATE customers
       SET status = 'inactive'
       WHERE id = $1
       RETURNING *`,
      [id]
    );

    await logAudit({
      userId: req.user.id,
      action: "customer_soft_deleted",
      entity: "customer",
      entityId: id,
      oldValue: existingResult.rows[0],
      newValue: result.rows[0],
      ip: getClientIp(req),
    });

    return res.status(200).json({ customer: result.rows[0] });
  } catch (error) {
    return res.status(500).json({ message: "Failed to delete customer" });
  }
}

async function pauseCustomer(req, res) {
  const { id } = req.params;
  const { from_date: fromDate, to_date: toDate, reason } = req.body;

  if (!fromDate || !toDate || !reason) {
    return res.status(400).json({ message: "from_date, to_date, and reason are required" });
  }

  try {
    const customerResult = await pool.query(
      `SELECT id
       FROM customers
       WHERE id = $1
       LIMIT 1`,
      [id]
    );

    if (!customerResult.rows.length) {
      return res.status(404).json({ message: "Customer not found" });
    }

    const holidayResult = await pool.query(
      `INSERT INTO customer_holidays (customer_id, from_date, to_date, reason)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [id, fromDate, toDate, reason]
    );

    await pool.query(
      `UPDATE subscriptions
       SET status = 'paused',
           pause_from = $2,
           pause_to = $3
       WHERE customer_id = $1
         AND status = 'active'`,
      [id, fromDate, toDate]
    );

    return res.status(200).json({ pause: holidayResult.rows[0] });
  } catch (error) {
    return res.status(500).json({ message: "Failed to pause customer" });
  }
}

async function resumeCustomer(req, res) {
  const { id } = req.params;

  try {
    const deleteResult = await pool.query(
      `DELETE FROM customer_holidays
       WHERE customer_id = $1
         AND CURRENT_DATE BETWEEN from_date AND to_date
       RETURNING *`,
      [id]
    );

    await pool.query(
      `UPDATE subscriptions
       SET status = 'active',
           pause_from = NULL,
           pause_to = NULL
       WHERE customer_id = $1
         AND status = 'paused'`,
      [id]
    );

    return res.status(200).json({
      resumed: true,
      removed_pauses: deleteResult.rowCount,
    });
  } catch (error) {
    return res.status(500).json({ message: "Failed to resume customer" });
  }
}

async function getDefaulters(req, res) {
  const { agency_id: agencyId } = req.query;

  if (!agencyId) {
    return res.status(400).json({ message: "agency_id is required" });
  }

  try {
    const result = await pool.query(
      `SELECT
         c.id,
         c.name,
         c.phone,
         MAX((CURRENT_DATE - b.due_date))::int AS days_overdue,
         SUM(b.final_amount)::numeric(10,2) AS amount_overdue
       FROM customers c
       INNER JOIN bills b ON b.customer_id = c.id
       WHERE c.agency_id = $1
         AND b.status = 'unpaid'
         AND b.due_date < CURRENT_DATE
       GROUP BY c.id, c.name, c.phone
       ORDER BY days_overdue DESC, amount_overdue DESC`,
      [agencyId]
    );

    return res.status(200).json({ defaulters: result.rows });
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch defaulters" });
  }
}

module.exports = {
  listCustomers,
  createCustomer,
  getCustomerById,
  updateCustomer,
  deleteCustomer,
  pauseCustomer,
  resumeCustomer,
  getDefaulters,
};
