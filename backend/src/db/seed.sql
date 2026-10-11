BEGIN;

-- Agency admin user
INSERT INTO users (name, phone, role, language)
VALUES ('Rajesh Sharma', '+919876543210', 'agency_admin', 'hi');

-- Agency
INSERT INTO agencies (name, owner_id, city, state, pincode, subscription_plan)
VALUES (
  'Sharma News Agency',
  (SELECT id FROM users WHERE phone = '+919876543210'),
  'Nashik',
  'Maharashtra',
  '422001',
  'free'
);

UPDATE users
SET agency_id = (SELECT id FROM agencies WHERE name = 'Sharma News Agency')
WHERE phone = '+919876543210';

-- Newspapers (5)
INSERT INTO newspapers (agency_id, name, language, type, cost_price, selling_price, publisher, status)
VALUES
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Times of India', 'English', 'daily', 8.00, 12.00, 'Bennett Coleman', 'active'),
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'The Hindu', 'English', 'daily', 7.00, 11.00, 'The Hindu Group', 'active'),
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Lokmat', 'Hindi', 'daily', 4.00, 6.00, 'Lokmat Media', 'active'),
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Dainik Bhaskar', 'Hindi', 'daily', 4.00, 7.00, 'Dainik Bhaskar Group', 'active'),
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Economic Times', 'English', 'daily', 9.00, 13.00, 'Bennett Coleman', 'active');

-- Delivery staff list (2)
INSERT INTO delivery_boys (agency_id, name, phone, area)
VALUES
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Raju Pawar', '+919812345601', 'Gangapur Road'),
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Mohan Singh', '+919812345602', 'College Road');

-- Customers (10)
INSERT INTO customers (
  agency_id, name, phone, email, address, area, landmark, alt_contact,
  category, status, start_date, total_outstanding, lifetime_value, notes
)
VALUES
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Suresh Patil', '+919900000001', 'suresh.patil@example.com', 'Flat 101, Gokul Heights', 'Gangapur Road', 'Near Someshwar Temple', '+919911111001', 'Regular', 'active', CURRENT_DATE - INTERVAL '420 days', 0.00, 7800.00, 'Prefers morning delivery before 7 AM'),
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Meena Desai', '+919900000002', 'meena.desai@example.com', 'Bungalow 12, Garden Estate', 'Sadar', 'Opposite Cantonment Gate', '+919911111002', 'VIP', 'active', CURRENT_DATE - INTERVAL '300 days', 320.00, 6400.00, 'Pays online but often after reminder'),
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Vinod Kumar', '+919900000003', 'vinod.kumar@example.com', 'Plot 8, Shanti Park', 'College Road', 'Near Byk College', '+919911111003', 'Regular', 'active', CURRENT_DATE - INTERVAL '250 days', 580.00, 5220.00, 'Evening contact works better'),
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Ramesh Joshi', '+919900000004', 'ramesh.joshi@example.com', 'House 22, Old City Lane', 'Panchavati', 'Near Kalaram Mandir', '+919911111004', 'Risky', 'active', CURRENT_DATE - INTERVAL '500 days', 180.00, 3100.00, 'Frequent delayed payments'),
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Anil Tiwari', '+919900000005', 'anil.tiwari@example.com', 'Villa 5, Hill View', 'Trimbak Road', 'Near ABB Circle', '+919911111005', 'VIP', 'active', CURRENT_DATE - INTERVAL '360 days', 0.00, 10200.00, 'Prefers WhatsApp receipts'),
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Priya Shah', '+919900000006', 'priya.shah@example.com', 'Flat 4B, Maple Residency', 'Gangapur Road', 'Near City Center Mall', '+919911111006', 'New', 'active', CURRENT_DATE - INTERVAL '45 days', 320.00, 640.00, 'New customer, verify address once'),
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Sunita More', '+919900000007', 'sunita.more@example.com', 'House 9, Sai Nagar', 'Dwarka', 'Behind Dwarka Circle', '+919911111007', 'Regular', 'paused', CURRENT_DATE - INTERVAL '200 days', 150.00, 2750.00, 'On family vacation, temporarily paused'),
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Deepak Yadav', '+919900000008', 'deepak.yadav@example.com', 'Room 18, Worker Colony', 'Satpur', 'Near Satpur MIDC Gate', '+919911111008', 'Regular', 'active', CURRENT_DATE - INTERVAL '180 days', 330.00, 2970.00, 'Cash payment likely this week'),
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Kavita Nair', '+919900000009', 'kavita.nair@example.com', 'Flat 12, Rail View Apartments', 'Nashik Road', 'Near Railway Station', '+919911111009', 'Regular', 'active', CURRENT_DATE - INTERVAL '150 days', 300.00, 3300.00, 'Needs bilingual bill summary'),
  ((SELECT id FROM agencies WHERE name = 'Sharma News Agency'), 'Rakesh Gupta', '+919900000010', 'rakesh.gupta@example.com', 'Shop 3, Cidco Market', 'Cidco', 'Next to Hanuman Mandir', '+919911111010', 'Risky', 'active', CURRENT_DATE - INTERVAL '280 days', 320.00, 3840.00, 'Needs repeated follow-up for payment');

-- Subscriptions
INSERT INTO subscriptions (customer_id, newspaper_id, rate, start_date, status, plan_type, auto_renew, pause_from, pause_to)
VALUES
  ((SELECT id FROM customers WHERE phone = '+919900000001'), (SELECT id FROM newspapers WHERE name = 'Times of India'), 500.00, CURRENT_DATE - INTERVAL '420 days', 'active', 'monthly', true, NULL, NULL),
  ((SELECT id FROM customers WHERE phone = '+919900000001'), (SELECT id FROM newspapers WHERE name = 'Lokmat'), 150.00, CURRENT_DATE - INTERVAL '420 days', 'active', 'monthly', true, NULL, NULL),
  ((SELECT id FROM customers WHERE phone = '+919900000002'), (SELECT id FROM newspapers WHERE name = 'Times of India'), 320.00, CURRENT_DATE - INTERVAL '300 days', 'active', 'monthly', true, NULL, NULL),
  ((SELECT id FROM customers WHERE phone = '+919900000003'), (SELECT id FROM newspapers WHERE name = 'The Hindu'), 580.00, CURRENT_DATE - INTERVAL '250 days', 'active', 'monthly', true, NULL, NULL),
  ((SELECT id FROM customers WHERE phone = '+919900000004'), (SELECT id FROM newspapers WHERE name = 'Dainik Bhaskar'), 180.00, CURRENT_DATE - INTERVAL '500 days', 'active', 'monthly', true, NULL, NULL),
  ((SELECT id FROM customers WHERE phone = '+919900000005'), (SELECT id FROM newspapers WHERE name = 'Times of India'), 500.00, CURRENT_DATE - INTERVAL '360 days', 'active', 'monthly', true, NULL, NULL),
  ((SELECT id FROM customers WHERE phone = '+919900000005'), (SELECT id FROM newspapers WHERE name = 'Economic Times'), 350.00, CURRENT_DATE - INTERVAL '360 days', 'active', 'monthly', true, NULL, NULL),
  ((SELECT id FROM customers WHERE phone = '+919900000006'), (SELECT id FROM newspapers WHERE name = 'Times of India'), 320.00, CURRENT_DATE - INTERVAL '45 days', 'active', 'monthly', true, NULL, NULL),
  ((SELECT id FROM customers WHERE phone = '+919900000007'), (SELECT id FROM newspapers WHERE name = 'Lokmat'), 150.00, CURRENT_DATE - INTERVAL '200 days', 'paused', 'monthly', true, CURRENT_DATE - INTERVAL '4 days', CURRENT_DATE + INTERVAL '10 days'),
  ((SELECT id FROM customers WHERE phone = '+919900000008'), (SELECT id FROM newspapers WHERE name = 'Dainik Bhaskar'), 180.00, CURRENT_DATE - INTERVAL '180 days', 'active', 'monthly', true, NULL, NULL),
  ((SELECT id FROM customers WHERE phone = '+919900000008'), (SELECT id FROM newspapers WHERE name = 'Lokmat'), 150.00, CURRENT_DATE - INTERVAL '180 days', 'active', 'monthly', true, NULL, NULL),
  ((SELECT id FROM customers WHERE phone = '+919900000009'), (SELECT id FROM newspapers WHERE name = 'The Hindu'), 300.00, CURRENT_DATE - INTERVAL '150 days', 'active', 'monthly', true, NULL, NULL),
  ((SELECT id FROM customers WHERE phone = '+919900000010'), (SELECT id FROM newspapers WHERE name = 'Times of India'), 320.00, CURRENT_DATE - INTERVAL '280 days', 'active', 'monthly', true, NULL, NULL);

-- Customer holiday for paused customer
INSERT INTO customer_holidays (customer_id, from_date, to_date, reason)
VALUES (
  (SELECT id FROM customers WHERE phone = '+919900000007'),
  CURRENT_DATE - INTERVAL '4 days',
  CURRENT_DATE + INTERVAL '10 days',
  'Vacation trip with family'
);

-- Sample deliveries for today
INSERT INTO deliveries (customer_id, newspaper_id, date, status, notes, timestamp)
VALUES
  ((SELECT id FROM customers WHERE phone = '+919900000001'), (SELECT id FROM newspapers WHERE name = 'Times of India'), CURRENT_DATE, 'delivered', 'Delivered at gate', NOW()),
  ((SELECT id FROM customers WHERE phone = '+919900000001'), (SELECT id FROM newspapers WHERE name = 'Lokmat'), CURRENT_DATE, 'delivered', 'Delivered at gate', NOW()),
  ((SELECT id FROM customers WHERE phone = '+919900000003'), (SELECT id FROM newspapers WHERE name = 'The Hindu'), CURRENT_DATE, 'delivered', 'Delivered on time', NOW()),
  ((SELECT id FROM customers WHERE phone = '+919900000004'), (SELECT id FROM newspapers WHERE name = 'Dainik Bhaskar'), CURRENT_DATE, 'missed', 'Customer reported no paper today', NOW()),
  ((SELECT id FROM customers WHERE phone = '+919900000005'), (SELECT id FROM newspapers WHERE name = 'Times of India'), CURRENT_DATE, 'delivered', 'Delivered on porch', NOW()),
  ((SELECT id FROM customers WHERE phone = '+919900000005'), (SELECT id FROM newspapers WHERE name = 'Economic Times'), CURRENT_DATE, 'delivered', 'Delivered on porch', NOW()),
  ((SELECT id FROM customers WHERE phone = '+919900000008'), (SELECT id FROM newspapers WHERE name = 'Dainik Bhaskar'), CURRENT_DATE, 'delivered', 'Reached before 7 AM', NOW()),
  ((SELECT id FROM customers WHERE phone = '+919900000008'), (SELECT id FROM newspapers WHERE name = 'Lokmat'), CURRENT_DATE, 'delivered', 'Reached before 7 AM', NOW()),
  ((SELECT id FROM customers WHERE phone = '+919900000009'), (SELECT id FROM newspapers WHERE name = 'The Hindu'), CURRENT_DATE, 'wet_paper', 'Left outside in rain', NOW()),
  ((SELECT id FROM customers WHERE phone = '+919900000010'), (SELECT id FROM newspapers WHERE name = 'Times of India'), CURRENT_DATE, 'pending', 'Waiting for admin review', NOW());

-- Bills for current month
INSERT INTO bills (
  customer_id, agency_id, month, year, amount, discount, late_fee,
  final_amount, due_date, status, generated_at, paid_at, pdf_url
)
VALUES
  ((SELECT id FROM customers WHERE phone = '+919900000002'), (SELECT id FROM agencies WHERE name = 'Sharma News Agency'), EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER, 320.00, 0.00, 0.00, 320.00, CURRENT_DATE - INTERVAL '15 days', 'unpaid', CURRENT_DATE - INTERVAL '20 days', NULL, 'https://example.com/bills/meena-desai-current-month.pdf'),
  ((SELECT id FROM customers WHERE phone = '+919900000004'), (SELECT id FROM agencies WHERE name = 'Sharma News Agency'), EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER, 180.00, 0.00, 20.00, 200.00, CURRENT_DATE - INTERVAL '32 days', 'unpaid', CURRENT_DATE - INTERVAL '37 days', NULL, 'https://example.com/bills/ramesh-joshi-current-month.pdf'),
  ((SELECT id FROM customers WHERE phone = '+919900000010'), (SELECT id FROM agencies WHERE name = 'Sharma News Agency'), EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER, 320.00, 0.00, 0.00, 320.00, CURRENT_DATE - INTERVAL '8 days', 'unpaid', CURRENT_DATE - INTERVAL '13 days', NULL, 'https://example.com/bills/rakesh-gupta-current-month.pdf'),
  ((SELECT id FROM customers WHERE phone = '+919900000001'), (SELECT id FROM agencies WHERE name = 'Sharma News Agency'), EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER, 650.00, 0.00, 0.00, 650.00, CURRENT_DATE - INTERVAL '5 days', 'paid', CURRENT_DATE - INTERVAL '12 days', CURRENT_DATE - INTERVAL '3 days', 'https://example.com/bills/suresh-patil-current-month.pdf'),
  ((SELECT id FROM customers WHERE phone = '+919900000005'), (SELECT id FROM agencies WHERE name = 'Sharma News Agency'), EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER, 850.00, 0.00, 0.00, 850.00, CURRENT_DATE - INTERVAL '4 days', 'paid', CURRENT_DATE - INTERVAL '11 days', CURRENT_DATE - INTERVAL '2 days', 'https://example.com/bills/anil-tiwari-current-month.pdf'),
  ((SELECT id FROM customers WHERE phone = '+919900000003'), (SELECT id FROM agencies WHERE name = 'Sharma News Agency'), EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER, 580.00, 0.00, 0.00, 580.00, CURRENT_DATE + INTERVAL '3 days', 'unpaid', CURRENT_DATE - INTERVAL '2 days', NULL, 'https://example.com/bills/vinod-kumar-current-month.pdf'),
  ((SELECT id FROM customers WHERE phone = '+919900000006'), (SELECT id FROM agencies WHERE name = 'Sharma News Agency'), EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER, 320.00, 0.00, 0.00, 320.00, CURRENT_DATE + INTERVAL '5 days', 'unpaid', CURRENT_DATE - INTERVAL '1 day', NULL, 'https://example.com/bills/priya-shah-current-month.pdf'),
  ((SELECT id FROM customers WHERE phone = '+919900000007'), (SELECT id FROM agencies WHERE name = 'Sharma News Agency'), EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER, 150.00, 0.00, 0.00, 150.00, CURRENT_DATE + INTERVAL '6 days', 'unpaid', CURRENT_DATE - INTERVAL '1 day', NULL, 'https://example.com/bills/sunita-more-current-month.pdf'),
  ((SELECT id FROM customers WHERE phone = '+919900000008'), (SELECT id FROM agencies WHERE name = 'Sharma News Agency'), EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER, 330.00, 0.00, 0.00, 330.00, CURRENT_DATE + INTERVAL '4 days', 'unpaid', CURRENT_DATE - INTERVAL '2 days', NULL, 'https://example.com/bills/deepak-yadav-current-month.pdf'),
  ((SELECT id FROM customers WHERE phone = '+919900000009'), (SELECT id FROM agencies WHERE name = 'Sharma News Agency'), EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER, 300.00, 0.00, 0.00, 300.00, CURRENT_DATE + INTERVAL '7 days', 'unpaid', CURRENT_DATE - INTERVAL '1 day', NULL, 'https://example.com/bills/kavita-nair-current-month.pdf');

-- Payments for paid bills
INSERT INTO payments (
  bill_id, customer_id, amount, mode, txn_id, status, gateway, paid_at, received_by, notes
)
VALUES
  (
    (SELECT id FROM bills WHERE customer_id = (SELECT id FROM customers WHERE phone = '+919900000001') AND month = EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER AND year = EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER),
    (SELECT id FROM customers WHERE phone = '+919900000001'),
    650.00,
    'UPI',
    'pay_suresh_001',
    'success',
    'razorpay',
    CURRENT_DATE - INTERVAL '3 days',
    (SELECT id FROM users WHERE phone = '+919876543210'),
    'Paid via Google Pay'
  ),
  (
    (SELECT id FROM bills WHERE customer_id = (SELECT id FROM customers WHERE phone = '+919900000005') AND month = EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER AND year = EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER),
    (SELECT id FROM customers WHERE phone = '+919900000005'),
    850.00,
    'Card',
    'pay_anil_001',
    'success',
    'razorpay',
    CURRENT_DATE - INTERVAL '2 days',
    (SELECT id FROM users WHERE phone = '+919876543210'),
    'Paid via Razorpay card checkout'
  );

-- Complaints (2 open)
INSERT INTO complaints (
  customer_id, delivery_boy_id, agency_id, category, description, photo_url, status, raised_at
)
VALUES
  (
    (SELECT id FROM customers WHERE phone = '+919900000004'),
    (SELECT id FROM delivery_boys WHERE phone = '+919812345601'),
    (SELECT id FROM agencies WHERE name = 'Sharma News Agency'),
    'Missing Paper',
    'Paper was not delivered on time for two consecutive days.',
    'https://example.com/complaints/missing-paper-ramesh.jpg',
    'open',
    CURRENT_TIMESTAMP - INTERVAL '1 day'
  ),
  (
    (SELECT id FROM customers WHERE phone = '+919900000009'),
    (SELECT id FROM delivery_boys WHERE phone = '+919812345602'),
    (SELECT id FROM agencies WHERE name = 'Sharma News Agency'),
    'Wet Newspaper',
    'Newspaper was left near the gate and got wet in the rain.',
    'https://example.com/complaints/wet-paper-kavita.jpg',
    'open',
    CURRENT_TIMESTAMP - INTERVAL '6 hours'
  );

-- Attendance for today
INSERT INTO attendance (delivery_boy_id, date, clock_in, clock_out, status, leave_reason)
VALUES
  (
    (SELECT id FROM delivery_boys WHERE phone = '+919812345601'),
    CURRENT_DATE,
    CURRENT_DATE + TIME '05:45:00',
    CURRENT_DATE + TIME '11:30:00',
    'present',
    NULL
  ),
  (
    (SELECT id FROM delivery_boys WHERE phone = '+919812345602'),
    CURRENT_DATE,
    CURRENT_DATE + TIME '06:00:00',
    CURRENT_DATE + TIME '11:45:00',
    'present',
    NULL
  );

COMMIT;
