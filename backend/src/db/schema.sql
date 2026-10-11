CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(15) UNIQUE NOT NULL,
  email VARCHAR(100),
  role VARCHAR(20) CHECK (role IN
    ('agency_admin','customer')),
  agency_id UUID,
  language VARCHAR(5) DEFAULT 'hi',
  theme VARCHAR(10) DEFAULT 'light',
  pin VARCHAR(6),
  fcm_token TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE agencies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  owner_id UUID REFERENCES users(id),
  address TEXT,
  city VARCHAR(50),
  state VARCHAR(50),
  pincode VARCHAR(10),
  gst_number VARCHAR(20),
  subscription_plan VARCHAR(20) DEFAULT 'free',
  subscription_expiry DATE,
  status VARCHAR(20) DEFAULT 'active',
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id UUID REFERENCES agencies(id),
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(15) NOT NULL,
  email VARCHAR(100),
  address TEXT,
  area VARCHAR(50),
  landmark VARCHAR(100),
  gps_lat DECIMAL(10,8),
  gps_lng DECIMAL(11,8),
  alt_contact VARCHAR(15),
  category VARCHAR(20) DEFAULT 'New',
  status VARCHAR(20) DEFAULT 'active',
  start_date DATE,
  total_outstanding DECIMAL(10,2) DEFAULT 0,
  lifetime_value DECIMAL(10,2) DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE newspapers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id UUID REFERENCES agencies(id),
  name VARCHAR(100) NOT NULL,
  language VARCHAR(30),
  type VARCHAR(20) DEFAULT 'daily',
  cost_price DECIMAL(8,2),
  selling_price DECIMAL(8,2) NOT NULL,
  publisher VARCHAR(100),
  status VARCHAR(20) DEFAULT 'active'
);

CREATE TABLE delivery_boys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id UUID REFERENCES agencies(id),
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(15),
  area VARCHAR(50),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(id),
  newspaper_id UUID REFERENCES newspapers(id),
  rate DECIMAL(8,2) NOT NULL,
  start_date DATE,
  end_date DATE,
  status VARCHAR(20) DEFAULT 'active',
  plan_type VARCHAR(20) DEFAULT 'monthly',
  auto_renew BOOLEAN DEFAULT true,
  pause_from DATE,
  pause_to DATE
);

CREATE TABLE deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(id),
  delivery_boy_id UUID REFERENCES delivery_boys(id),
  newspaper_id UUID REFERENCES newspapers(id),
  date DATE NOT NULL,
  status VARCHAR(30) CHECK (status IN
    ('delivered','pending','missed',
     'customer_holiday','wrong_paper','wet_paper'))
    DEFAULT 'pending',
  photo_proof_url TEXT,
  gps_lat DECIMAL(10,8),
  gps_lng DECIMAL(11,8),
  timestamp TIMESTAMP,
  notes TEXT,
  UNIQUE (customer_id, newspaper_id, date)
);

CREATE TABLE bills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(id),
  agency_id UUID REFERENCES agencies(id),
  month INTEGER NOT NULL,
  year INTEGER NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  discount DECIMAL(10,2) DEFAULT 0,
  late_fee DECIMAL(10,2) DEFAULT 0,
  final_amount DECIMAL(10,2) NOT NULL,
  due_date DATE,
  status VARCHAR(20) DEFAULT 'unpaid',
  generated_at TIMESTAMP DEFAULT NOW(),
  paid_at TIMESTAMP,
  pdf_url TEXT,
  notes TEXT
);

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bill_id UUID REFERENCES bills(id),
  customer_id UUID REFERENCES customers(id),
  amount DECIMAL(10,2) NOT NULL,
  mode VARCHAR(30),
  txn_id VARCHAR(100),
  status VARCHAR(20) DEFAULT 'pending',
  gateway VARCHAR(30),
  paid_at TIMESTAMP,
  received_by UUID REFERENCES users(id),
  notes TEXT
);

CREATE TABLE attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_boy_id UUID REFERENCES delivery_boys(id),
  date DATE NOT NULL,
  clock_in TIMESTAMP,
  clock_out TIMESTAMP,
  status VARCHAR(20) DEFAULT 'present',
  leave_reason TEXT,
  UNIQUE (delivery_boy_id, date)
);

CREATE TABLE cash_collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_boy_id UUID REFERENCES delivery_boys(id),
  customer_id UUID REFERENCES customers(id),
  amount DECIMAL(10,2),
  date DATE,
  submitted BOOLEAN DEFAULT false,
  admin_confirmed_at TIMESTAMP
);

CREATE TABLE complaints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(id),
  delivery_boy_id UUID REFERENCES delivery_boys(id),
  agency_id UUID REFERENCES agencies(id),
  category VARCHAR(50),
  description TEXT,
  photo_url TEXT,
  status VARCHAR(20) DEFAULT 'open',
  raised_at TIMESTAMP DEFAULT NOW(),
  resolved_at TIMESTAMP
);

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  title VARCHAR(200),
  message TEXT,
  type VARCHAR(50),
  channel VARCHAR(20),
  status VARCHAR(20) DEFAULT 'pending',
  sent_at TIMESTAMP,
  read_at TIMESTAMP
);

CREATE TABLE expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id UUID REFERENCES agencies(id),
  category VARCHAR(50),
  amount DECIMAL(10,2),
  description TEXT,
  date DATE,
  receipt_url TEXT,
  created_by UUID REFERENCES users(id)
);

CREATE TABLE holidays (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id UUID REFERENCES agencies(id),
  date DATE NOT NULL,
  description VARCHAR(200),
  applies_to_all BOOLEAN DEFAULT true
);

CREATE TABLE customer_holidays (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(id),
  from_date DATE,
  to_date DATE,
  reason TEXT
);

CREATE TABLE inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id UUID REFERENCES agencies(id),
  newspaper_id UUID REFERENCES newspapers(id),
  date DATE,
  received_qty INTEGER,
  distributed_qty INTEGER,
  unsold_qty INTEGER,
  damaged_qty INTEGER DEFAULT 0
);

CREATE TABLE publishers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id UUID REFERENCES agencies(id),
  name VARCHAR(100),
  contact VARCHAR(15),
  address TEXT,
  gst VARCHAR(20),
  payment_terms TEXT,
  status VARCHAR(20) DEFAULT 'active'
);

CREATE TABLE discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id UUID REFERENCES agencies(id),
  name VARCHAR(100),
  type VARCHAR(20),
  value DECIMAL(8,2),
  start_date DATE,
  end_date DATE,
  status VARCHAR(20) DEFAULT 'active'
);

CREATE TABLE loyalty_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(id),
  points INTEGER DEFAULT 0,
  earned_from VARCHAR(50),
  transaction_id UUID,
  expires_at DATE
);

CREATE TABLE referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID REFERENCES customers(id),
  referred_id UUID REFERENCES customers(id),
  reward_amount DECIMAL(8,2),
  status VARCHAR(20) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  action VARCHAR(100),
  entity VARCHAR(50),
  entity_id UUID,
  old_value JSONB,
  new_value JSONB,
  ip VARCHAR(50),
  timestamp TIMESTAMP DEFAULT NOW()
);

CREATE TABLE settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id UUID REFERENCES agencies(id),
  key VARCHAR(100),
  value TEXT,
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(id),
  type VARCHAR(30),
  details JSONB,
  is_default BOOLEAN DEFAULT false,
  autopay_enabled BOOLEAN DEFAULT false
);

CREATE TABLE invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bill_id UUID REFERENCES bills(id),
  invoice_number VARCHAR(50) UNIQUE,
  gst_amount DECIMAL(10,2),
  total DECIMAL(10,2),
  pdf_url TEXT,
  generated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(id),
  delivery_boy_id UUID REFERENCES delivery_boys(id),
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  comments TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) UNIQUE NOT NULL,
  discount_id UUID REFERENCES discounts(id),
  usage_limit INTEGER DEFAULT 1,
  used_count INTEGER DEFAULT 0,
  customer_id UUID REFERENCES customers(id),
  expires_at DATE
);

CREATE TABLE reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bill_id UUID REFERENCES bills(id),
  type VARCHAR(50),
  channel VARCHAR(20),
  scheduled_at TIMESTAMP,
  sent_at TIMESTAMP,
  status VARCHAR(20) DEFAULT 'pending'
);
