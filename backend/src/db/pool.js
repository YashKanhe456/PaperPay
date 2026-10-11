"use strict";

const { Pool } = require("pg");

let currentPool = null;

function createPool() {
  const rawUrl = process.env.DATABASE_URL || "";

  const rejectUnauthorized = process.env.DB_SSL_REJECT_UNAUTHORIZED === undefined
    ? true
    : process.env.DB_SSL_REJECT_UNAUTHORIZED !== "false";

  const ssl = process.env.DB_SSL === "false"
    ? false
    : rejectUnauthorized
      ? { rejectUnauthorized: true }
      : { rejectUnauthorized: false };

  const pool = new Pool({
    connectionString: rawUrl,
    ssl,
  });

  return pool;
}

function getPool() {
  return currentPool;
}

function setPool(pool) {
  currentPool = pool;
}

function clearPool() {
  currentPool = null;
}

module.exports = {
  // Preferred API for app startup: createPool() then assign .pool = result.
  createPool,
  getPool,
  setPool,
  clearPool,
  // Legacy convenience for probes and tests: hand out the active pool, or
  // create one lazily if none exists.
  pool: null,
};

// Backward compatibility: if something required pool and then called pool(),
// hand out a lazily-created pool instance.
module.exports.pool = function legacyPool() {
  if (!module.exports.pool._instance) {
    module.exports.pool._instance = createPool();
  }
  return module.exports.pool._instance;
};
module.exports.pool._instance = null;
