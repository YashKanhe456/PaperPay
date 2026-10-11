"use strict";

const Razorpay = require("razorpay");

let instance = null;

function ensureRazorpay() {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;

  if (!keyId || !keySecret) {
    const missing = [];
    if (!keyId) missing.push("RAZORPAY_KEY_ID");
    if (!keySecret) missing.push("RAZORPAY_KEY_SECRET");
    throw new Error(`Razorpay is not configured: ${missing.join(", ")}`);
  }

  if (!instance) {
    instance = new Razorpay({
      key_id: keyId,
      key_secret: keySecret,
    });
  }

  return instance;
}

/**
 * Create a Razorpay payment order. The caller is responsible for ensuring the
 * amount has already been validated and converted to paise if required.
 */
async function createOrder(amount, receipt) {
  const razorpay = ensureRazorpay();
  return razorpay.orders.create({
    amount,
    currency: "INR",
    receipt,
  });
}

/**
 * Verify a Razorpay payment signature using the webhook secret. This is a
 * lightweight wrapper that makes the signature check explicit at the call site.
 */
async function verifyPayment(orderId, paymentId, signature) {
  const razorpay = ensureRazorpay();
  return razorpay.utilities.verifyPaymentSignature({
    order_id: orderId,
    payment_id: paymentId,
    signature: signature,
  });
}

/**
 * Create a refund against an existing payment transaction id. Partial refunds
 * are supported by passing an amount smaller than the captured amount.
 */
async function createRefund(txnId, amount) {
  const razorpay = ensureRazorpay();
  return razorpay.payments.refund(txnId, {
    amount,
  });
}

module.exports = {
  ensureRazorpay,
  createOrder,
  verifyPayment,
  createRefund,
};
