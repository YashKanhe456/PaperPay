const express = require("express");

const auth = require("../middleware/auth");
const { requireRole } = require("../middleware/requireRole");
const pool = require("../db/pool");
const {
  createOrder,
  verifyPayment,
  createRefund,
} = require("../services/razorpay");

const router = express.Router();

router.use(auth);

async function getCustomerByPhone(client, phone) {
  if (!phone) {
    return null;
  }

  const result = await client.query(
    `SELECT id, agency_id, phone
     FROM customers
     WHERE phone = $1
     LIMIT 1`,
    [phone]
  );

  return result.rows[0] || null;
}

async function hasBillAccess(client, req, bill, customerId) {
  if (!bill) {
    return false;
  }

  if (req.user.role === "agency_admin") {
    return bill.agency_id === req.user.agency_id && bill.customer_id === customerId;
  }

  if (req.user.role === "customer") {
    const customer = await getCustomerByPhone(client, req.user.phone);
    return customer && customer.id === customerId && bill.customer_id === customer.id;
  }

  return false;
}

async function getBillWithAgency(client, billId) {
  const result = await client.query(
    `SELECT id, customer_id, agency_id, final_amount, status
     FROM bills
     WHERE id = $1
     LIMIT 1`,
    [billId]
  );

  return result.rows[0] || null;
}

async function getOldestOpenBillForCustomer(client, customerId, agencyId) {
  const result = await client.query(
    `SELECT id, customer_id, agency_id, final_amount, status
     FROM bills
     WHERE customer_id = $1
       AND agency_id = $2
       AND status IN ('unpaid', 'partial')
     ORDER BY due_date ASC NULLS LAST, generated_at ASC
     LIMIT 1`,
    [customerId, agencyId]
  );

  return result.rows[0] || null;
}

async function recalculateBillAndCustomer(client, billId, customerId) {
  const paidTotals = await client.query(
    `SELECT COALESCE(SUM(amount), 0)::numeric(10,2) AS paid_amount
     FROM payments
     WHERE bill_id = $1
       AND status IN ('success', 'cash_received')`,
    [billId]
  );

  const billResult = await client.query(
    `SELECT final_amount
     FROM bills
     WHERE id = $1
     LIMIT 1`,
    [billId]
  );

  const finalAmount = Number(billResult.rows[0].final_amount || 0);
  const paidAmount = Number(paidTotals.rows[0].paid_amount || 0);

  let billStatus = "unpaid";
  let paidAt = null;

  if (paidAmount >= finalAmount && finalAmount > 0) {
    billStatus = "paid";
    paidAt = new Date();
  } else if (paidAmount > 0) {
    billStatus = "partial";
  }

  await client.query(
    `UPDATE bills
     SET status = $2,
         paid_at = $3
     WHERE id = $1`,
    [billId, billStatus, paidAt]
  );

  const outstandingResult = await client.query(
    `SELECT COALESCE(SUM(GREATEST(b.final_amount - COALESCE(p.paid_amount, 0), 0)), 0)::numeric(10,2) AS outstanding
     FROM bills b
     LEFT JOIN (
       SELECT bill_id, COALESCE(SUM(amount), 0) AS paid_amount
       FROM payments
       WHERE status IN ('success', 'cash_received')
       GROUP BY bill_id
     ) p ON p.bill_id = b.id
     WHERE b.customer_id = $1
       AND b.status IN ('unpaid', 'partial')`,
    [customerId]
  );

  const outstanding = Number(outstandingResult.rows[0].outstanding || 0);

  await client.query(
    `UPDATE customers
     SET total_outstanding = $2
     WHERE id = $1`,
    [customerId, outstanding]
  );

  return {
    bill_status: billStatus,
    total_outstanding: outstanding,
  };
}

router.post("/cash", requireRole("agency_admin"), async (req, res) => {
  const { bill_id: billId, customer_id: customerId, amount, notes } = req.body;

  if (!customerId || !amount) {
    return res.status(400).json({
      message: "customer_id and amount are required",
    });
  }

  // The collecting user is taken from the verified token, never from the body.
  const receivedBy = req.user.id;

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const bill = billId
      ? await getBillWithAgency(client, billId)
      : await getOldestOpenBillForCustomer(client, customerId, req.user.agency_id);

    if (!bill || bill.customer_id !== customerId) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "No unpaid bill found for this customer" });
    }

    const allowed = await hasBillAccess(client, req, bill, customerId);

    if (!allowed) {
      await client.query("ROLLBACK");
      return res.status(403).json({ message: "Payment access denied" });
    }

    const paymentResult = await client.query(
      `INSERT INTO payments (
         bill_id, customer_id, amount, mode, txn_id, status, gateway, paid_at, received_by, notes
       )
       VALUES ($1, $2, $3, 'cash', $4, 'cash_received', 'cash', NOW(), $5, $6)
      RETURNING *`,
      [
        bill.id,
        customerId,
        amount,
        `cash_${Date.now()}`,
        receivedBy,
        notes || null,
      ]
    );

    const summary = await recalculateBillAndCustomer(client, bill.id, customerId);

    await client.query("COMMIT");

    return res.status(201).json({
      receipt: paymentResult.rows[0],
      bill_id: bill.id,
      bill_status: summary.bill_status,
      total_outstanding: summary.total_outstanding,
    });
  } catch (error) {
    await client.query("ROLLBACK");
    return res.status(500).json({ message: "Failed to record cash payment" });
  } finally {
    client.release();
  }
});

router.post("/razorpay/create-order", async (req, res) => {
  const { bill_id: billId, customer_id: customerId } = req.body;

  if (!billId || !customerId) {
    return res.status(400).json({ message: "bill_id and customer_id are required" });
  }

  try {
    const bill = await getBillWithAgency(pool, billId);

    if (!bill || bill.customer_id !== customerId) {
      return res.status(404).json({ message: "Bill not found" });
    }

    const allowed = await hasBillAccess(pool, req, bill, customerId);

    if (!allowed) {
      return res.status(403).json({ message: "Payment access denied" });
    }

    const order = await createOrder(
      bill.final_amount,
      `bill_${billId}_${Date.now()}`
    );

    return res.status(200).json({
      order_id: order.id,
      amount: order.amount,
      razorpay_key: process.env.RAZORPAY_KEY_ID,
    });
  } catch (error) {
    if (error.message === "Razorpay is not configured") {
      return res.status(500).json({ message: "Razorpay is not configured" });
    }

    return res.status(500).json({ message: "Failed to create Razorpay order" });
  }
});

router.post("/razorpay/verify", async (req, res) => {
  const {
    bill_id: billId,
    customer_id: customerId,
    orderId,
    paymentId,
    signature,
    order_id: orderIdAlt,
    payment_id: paymentIdAlt,
    razorpay_order_id: razorpayOrderId,
    razorpay_payment_id: razorpayPaymentId,
    razorpay_signature: razorpaySignature,
  } = req.body;

  const finalOrderId = orderId || orderIdAlt || razorpayOrderId;
  const finalPaymentId = paymentId || paymentIdAlt || razorpayPaymentId;
  const finalSignature = signature || razorpaySignature;

  if (!billId || !customerId || !finalOrderId || !finalPaymentId || !finalSignature) {
    return res.status(400).json({ message: "Missing Razorpay verification payload" });
  }

  try {
    const valid = verifyPayment(finalOrderId, finalPaymentId, finalSignature);

    if (!valid) {
      return res.status(400).json({ message: "Invalid payment signature" });
    }

    const client = await pool.connect();

    try {
      await client.query("BEGIN");

      const bill = await getBillWithAgency(client, billId);

      if (!bill || bill.customer_id !== customerId) {
        await client.query("ROLLBACK");
        return res.status(404).json({ message: "Bill not found" });
      }

      const allowed = await hasBillAccess(client, req, bill, customerId);

      if (!allowed) {
        await client.query("ROLLBACK");
        return res.status(403).json({ message: "Payment access denied" });
      }

      const paymentResult = await client.query(
        `INSERT INTO payments (
           bill_id, customer_id, amount, mode, txn_id, status, gateway, paid_at, received_by, notes
         )
         VALUES ($1, $2, $3, 'online', $4, 'success', 'razorpay', NOW(), $5, $6)
         RETURNING *`,
        [
          billId,
          customerId,
          bill.final_amount,
          finalPaymentId,
          req.user.id,
          JSON.stringify({ order_id: finalOrderId }),
        ]
      );

      const summary = await recalculateBillAndCustomer(client, billId, customerId);

      await client.query("COMMIT");

      return res.status(200).json({
        payment: paymentResult.rows[0],
        bill_status: summary.bill_status,
        total_outstanding: summary.total_outstanding,
      });
    } catch (error) {
      await client.query("ROLLBACK");
      return res.status(500).json({ message: "Failed to verify and record payment" });
    } finally {
      client.release();
    }
  } catch (error) {
    if (error.message === "Razorpay is not configured") {
      return res.status(500).json({ message: "Razorpay is not configured" });
    }

    return res.status(500).json({ message: "Payment verification failed" });
  }
});

router.get("/", async (req, res) => {
  const { customer_id: customerId, bill_id: billId } = req.query;

  try {
    const filters = [];
    const values = [];

    if (req.user.role === "agency_admin") {
      values.push(req.user.agency_id);
      filters.push(`b.agency_id = $${values.length}`);
    } else if (req.user.role === "customer") {
      const customer = await getCustomerByPhone(pool, req.user.phone);
      if (!customer) {
        return res.status(404).json({ message: "Customer profile not found" });
      }
      values.push(customer.id);
      filters.push(`p.customer_id = $${values.length}`);
    } else {
      return res.status(403).json({ message: "Payment access denied" });
    }

    if (customerId) {
      values.push(customerId);
      filters.push(`p.customer_id = $${values.length}`);
    }

    if (billId) {
      values.push(billId);
      filters.push(`p.bill_id = $${values.length}`);
    }

    const result = await pool.query(
      `SELECT
         p.*,
         b.month,
         b.year,
         c.name AS customer_name,
         c.phone
       FROM payments p
       INNER JOIN bills b ON b.id = p.bill_id
       INNER JOIN customers c ON c.id = p.customer_id
       WHERE ${filters.join(" AND ")}
       ORDER BY COALESCE(p.paid_at, NOW()) DESC`,
      values
    );

    return res.status(200).json({ payments: result.rows });
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch payment history" });
  }
});

router.post("/:id/refund", async (req, res) => {
  const { amount } = req.body;

  try {
    const paymentResult = await pool.query(
      `SELECT
         p.*,
         b.agency_id
       FROM payments p
       INNER JOIN bills b ON b.id = p.bill_id
       WHERE p.id = $1
       LIMIT 1`,
      [req.params.id]
    );

    if (!paymentResult.rows.length) {
      return res.status(404).json({ message: "Payment not found" });
    }

    const payment = paymentResult.rows[0];

    if (req.user.role !== "agency_admin" || payment.agency_id !== req.user.agency_id) {
      return res.status(403).json({ message: "Refund access denied" });
    }

    const refund = await createRefund(payment.txn_id, amount || payment.amount);

    const client = await pool.connect();

    try {
      await client.query("BEGIN");

      await client.query(
        `UPDATE payments
         SET status = 'refunded',
             notes = $2
         WHERE id = $1`,
        [payment.id, JSON.stringify({ refund_id: refund.id })]
      );

      const summary = await recalculateBillAndCustomer(
        client,
        payment.bill_id,
        payment.customer_id
      );

      await client.query("COMMIT");

      return res.status(200).json({
        refund,
        bill_status: summary.bill_status,
        total_outstanding: summary.total_outstanding,
      });
    } catch (error) {
      await client.query("ROLLBACK");
      return res.status(500).json({ message: "Failed to update refund status" });
    } finally {
      client.release();
    }
  } catch (error) {
    if (error.message === "Razorpay is not configured") {
      return res.status(500).json({ message: "Razorpay is not configured" });
    }

    return res.status(500).json({ message: "Failed to refund payment" });
  }
});

module.exports = router;
