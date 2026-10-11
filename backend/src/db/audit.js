const pool = require("./pool");

/**
 * Writes an entry to audit_logs.
 * All fields are optional except userId, action, entity.
 *
 * @param {object} opts
 * @param {string}  opts.userId
 * @param {string}  opts.action   - e.g. "CREATE", "UPDATE", "DELETE"
 * @param {string}  opts.entity   - e.g. "customer", "bill", "payment"
 * @param {string}  [opts.entityId]
 * @param {object}  [opts.oldValue]
 * @param {object}  [opts.newValue]
 * @param {string}  [opts.ip]
 * @param {object}  [opts.client]  - pass a pg client for transactional use
 */
async function writeAuditLog({
  userId,
  action,
  entity,
  entityId = null,
  oldValue = null,
  newValue = null,
  ip = null,
  client = null,
}) {
  if (!userId || !action || !entity) {
    return; // silently skip if essential fields are missing
  }

  const db = client || pool;

  try {
    await db.query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, old_value, new_value, ip, timestamp)
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
      [
        userId,
        action,
        entity,
        entityId,
        oldValue ? JSON.stringify(oldValue) : null,
        newValue ? JSON.stringify(newValue) : null,
        ip,
      ],
    );
  } catch (_) {
    // Audit log failures should never crash the main operation
  }
}

module.exports = { writeAuditLog };
