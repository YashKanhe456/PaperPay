"use strict";

const dotenv = require("dotenv");
dotenv.config();

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const pool = require("./db/pool");
const authRoutes = require("./routes/auth");
const attendanceRoutes = require("./routes/attendance");
const billRoutes = require("./routes/bills");
const cashCollectionRoutes = require("./routes/cashCollections");
const customerRoutes = require("./routes/customers");
const customerAppRoutes = require("./routes/customerApp");
const deliveryRoutes = require("./routes/deliveries");
const paymentRoutes = require("./routes/payments");
const reportRoutes = require("./routes/reports");
const uploadRoutes = require("./routes/uploads");
const newspaperRoutes = require("./routes/newspapers");
const subscriptionRoutes = require("./routes/subscriptions");
const deliveryBoyRoutes = require("./routes/deliveryBoys");
const notificationRoutes = require("./routes/notifications");
const agencyRoutes = require("./routes/agencies");
const settingsRoutes = require("./routes/settings");
const { generalLimiter } = require("./middleware/rateLimit");

const app = express();

// Prefer an explicit allowlist from the environment. When no Origin header is
// sent (curl, the Flutter mobile app, or same-origin requests) the browser
// never enforces CORS, so those callers are unaffected and continue to work.
const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS || "")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);
const corsOptions = allowedOrigins.length
  ? {
      origin: (origin, callback) => {
        if (!origin) {
          return callback(null, true);
        }
        if (allowedOrigins.includes(origin)) {
          return callback(null, true);
        }
        return callback(
          new Error("Not allowed by CORS"),
          false,
        );
      },
      methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
      allowedHeaders: [
        "Content-Type",
        "Authorization",
        "Accept",
      ],
      credentials: true,
    }
  : false;

app.use(cors(corsOptions));
app.use(helmet());
app.use(express.json());
app.use(generalLimiter);

app.use("/api/auth", authRoutes);
app.use("/api/attendance", attendanceRoutes);
app.use("/api/bills", billRoutes);
app.use("/api/cash-collections", cashCollectionRoutes);
app.use("/api/customers", customerRoutes);
app.use("/api/customer-app", customerAppRoutes);
app.use("/api/deliveries", deliveryRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/reports", reportRoutes);
app.use("/api/upload", uploadRoutes);
app.use("/api/newspapers", newspaperRoutes);
app.use("/api/subscriptions", subscriptionRoutes);
app.use("/api/delivery-boys", deliveryBoyRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/agencies", agencyRoutes);
app.use("/api/settings", settingsRoutes);

app.get("/api/health", async (req, res) => {
  try {
    const result = await pool.query("SELECT NOW()");
    return res.status(200).json({
      status: "ok",
      db: "connected",
      timestamp: result.rows[0].now,
    });
  } catch (error) {
    return res.status(500).json({ status: "error" });
  }
});

// Global unhandled error handler
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, _next) => {
  console.error("Unhandled error:", err);
  return res.status(500).json({ success: false, message: "Internal server error" });
});

module.exports = app;
