const pool = require("../db/pool");

const DEDUCTION_STATUSES = ["missed", "wrong_paper", "wet_paper", "customer_holiday"];

function getMonthBounds(month, year) {
  const firstDay = new Date(Date.UTC(year, month - 1, 1));
  const lastDay = new Date(Date.UTC(year, month, 0));
  return { firstDay, lastDay };
}

function formatDate(date) {
  return date.toISOString().slice(0, 10);
}

function listDatesBetween(startDate, endDate) {
  const dates = [];
  const cursor = new Date(startDate);

  while (cursor <= endDate) {
    dates.push(formatDate(cursor));
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }

  return dates;
}

function toMoney(value) {
  return Number(Number(value).toFixed(2));
}

async function getAgencyDiscount(agencyId, month, year) {
  const { firstDay, lastDay } = getMonthBounds(month, year);

  const { rows } = await pool.query(
    `SELECT id, name, type, value
     FROM discounts
     WHERE agency_id = $1
       AND status = 'active'
       AND (start_date IS NULL OR start_date <= $3::date)
       AND (end_date IS NULL OR end_date >= $2::date)
     ORDER BY value DESC
     LIMIT 1`,
    [agencyId, formatDate(firstDay), formatDate(lastDay)]
  );

  return rows[0] || null;
}

async function calculateBill(customerId, month, year) {
  const { firstDay, lastDay } = getMonthBounds(month, year);
  const totalDaysInMonth = lastDay.getUTCDate();

  const customerResult = await pool.query(
    `SELECT id, agency_id, start_date
     FROM customers
     WHERE id = $1
     LIMIT 1`,
    [customerId]
  );

  if (!customerResult.rows.length) {
    throw new Error("Customer not found");
  }

  const customer = customerResult.rows[0];

  const subscriptionsResult = await pool.query(
    `SELECT
       s.id,
       s.newspaper_id,
       n.name AS newspaper_name,
       s.rate,
       s.start_date,
       s.end_date,
       s.status
     FROM subscriptions s
     INNER JOIN newspapers n ON n.id = s.newspaper_id
     WHERE s.customer_id = $1
       AND s.status IN ('active', 'paused')
       AND (s.start_date IS NULL OR s.start_date <= $3::date)
       AND (s.end_date IS NULL OR s.end_date >= $2::date)
     ORDER BY n.name`,
    [customerId, formatDate(firstDay), formatDate(lastDay)]
  );

  const subscriptions = subscriptionsResult.rows;

  const [customerHolidaysResult, agencyHolidaysResult, deliveriesResult, previousBillResult] =
    await Promise.all([
      pool.query(
        `SELECT from_date, to_date
         FROM customer_holidays
         WHERE customer_id = $1
           AND from_date <= $3::date
           AND to_date >= $2::date`,
        [customerId, formatDate(firstDay), formatDate(lastDay)]
      ),
      pool.query(
        `SELECT date
         FROM holidays
         WHERE agency_id = $1
           AND date BETWEEN $2::date AND $3::date`,
        [customer.agency_id, formatDate(firstDay), formatDate(lastDay)]
      ),
      pool.query(
        `SELECT newspaper_id, date, status
         FROM deliveries
         WHERE customer_id = $1
           AND date BETWEEN $2::date AND $3::date
           AND status = ANY($4::varchar[])`,
        [customerId, formatDate(firstDay), formatDate(lastDay), DEDUCTION_STATUSES]
      ),
      (() => {
        const previousMonth = month === 1 ? 12 : month - 1;
        const previousYear = month === 1 ? year - 1 : year;

        return pool.query(
          `SELECT id, status
           FROM bills
           WHERE customer_id = $1
             AND month = $2
             AND year = $3
           LIMIT 1`,
          [customerId, previousMonth, previousYear]
        );
      })(),
    ]);

  const customerHolidayDates = new Set();

  for (const holiday of customerHolidaysResult.rows) {
    const overlapStart = new Date(
      Math.max(firstDay.getTime(), new Date(holiday.from_date).getTime())
    );
    const overlapEnd = new Date(
      Math.min(lastDay.getTime(), new Date(holiday.to_date).getTime())
    );

    if (overlapStart <= overlapEnd) {
      for (const date of listDatesBetween(overlapStart, overlapEnd)) {
        customerHolidayDates.add(date);
      }
    }
  }

  const agencyHolidayDates = new Set(
    agencyHolidaysResult.rows.map((row) => formatDate(new Date(row.date)))
  );

  const missedByNewspaper = deliveriesResult.rows.reduce((acc, row) => {
    const key = row.newspaper_id;

    if (!acc[key]) {
      acc[key] = new Set();
    }

    acc[key].add(formatDate(new Date(row.date)));
    return acc;
  }, {});

  const billItems = subscriptions.map((subscription) => {
    const subscriptionStart = subscription.start_date
      ? new Date(subscription.start_date)
      : firstDay;
    const subscriptionEnd = subscription.end_date
      ? new Date(subscription.end_date)
      : lastDay;
    const activeStart = new Date(Math.max(firstDay.getTime(), subscriptionStart.getTime()));
    const activeEnd = new Date(Math.min(lastDay.getTime(), subscriptionEnd.getTime()));

    if (activeStart > activeEnd) {
      return {
        subscription_id: subscription.id,
        newspaper_id: subscription.newspaper_id,
        newspaper_name: subscription.newspaper_name,
        rate: toMoney(subscription.rate),
        total_days: totalDaysInMonth,
        paused_days: 0,
        agency_holidays: 0,
        missed_days: 0,
        billable_days: 0,
        amount: 0,
      };
    }

    const activeDates = listDatesBetween(activeStart, activeEnd);
    const pausedDays = activeDates.filter((date) => customerHolidayDates.has(date)).length;
    const agencyHolidays = activeDates.filter((date) => agencyHolidayDates.has(date)).length;
    const missedDays = activeDates.filter((date) =>
      missedByNewspaper[subscription.newspaper_id]?.has(date)
    ).length;
    const billableDays = Math.max(
      activeDates.length - pausedDays - agencyHolidays - missedDays,
      0
    );
    const amount = toMoney((Number(subscription.rate) / 30) * billableDays);

    return {
      subscription_id: subscription.id,
      newspaper_id: subscription.newspaper_id,
      newspaper_name: subscription.newspaper_name,
      rate: toMoney(subscription.rate),
      total_days: activeDates.length,
      paused_days: pausedDays,
      agency_holidays: agencyHolidays,
      missed_days: missedDays,
      billable_days: billableDays,
      amount,
    };
  });

  const amount = toMoney(billItems.reduce((sum, item) => sum + item.amount, 0));

  const lateFeeEligible =
    previousBillResult.rows.length &&
    previousBillResult.rows[0].status !== "paid" &&
    new Date() > new Date(Date.UTC(year, month - 1, 10));
  const lateFee = lateFeeEligible ? 20 : 0;

  const activeDiscount = await getAgencyDiscount(customer.agency_id, month, year);
  let discount = 0;

  if (activeDiscount) {
    if (String(activeDiscount.type || "").toLowerCase() === "percentage") {
      discount = (amount * Number(activeDiscount.value || 0)) / 100;
    } else {
      discount = Number(activeDiscount.value || 0);
    }
  }

  discount = toMoney(Math.min(discount, amount));
  const finalAmount = toMoney(Math.max(amount - discount + lateFee, 0));

  return {
    amount,
    discount,
    late_fee: lateFee,
    final_amount: finalAmount,
    bill_items: billItems,
    customer_id: customerId,
    agency_id: customer.agency_id,
    month,
    year,
  };
}

async function generateBillsForAgency(agencyId, month, year) {
  const customerResult = await pool.query(
    `SELECT id
     FROM customers
     WHERE agency_id = $1
       AND status = 'active'
     ORDER BY created_at ASC`,
    [agencyId]
  );

  let generated = 0;
  let skipped = 0;
  let totalAmount = 0;

  for (const customer of customerResult.rows) {
    const existingBill = await pool.query(
      `SELECT id
       FROM bills
       WHERE customer_id = $1
         AND month = $2
         AND year = $3
       LIMIT 1`,
      [customer.id, month, year]
    );

    if (existingBill.rows.length) {
      skipped += 1;
      continue;
    }

    const billData = await calculateBill(customer.id, month, year);

    const dueDate = new Date(Date.UTC(year, month - 1, 10));

    await pool.query(
      `INSERT INTO bills (
         customer_id, agency_id, month, year, amount, discount, late_fee,
         final_amount, due_date, status
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'unpaid')`,
      [
        customer.id,
        agencyId,
        month,
        year,
        billData.amount,
        billData.discount,
        billData.late_fee,
        billData.final_amount,
        formatDate(dueDate),
      ]
    );

    generated += 1;
    totalAmount += billData.final_amount;
  }

  return {
    generated,
    skipped,
    total_amount: toMoney(totalAmount),
  };
}

module.exports = {
  calculateBill,
  generateBillsForAgency,
};
