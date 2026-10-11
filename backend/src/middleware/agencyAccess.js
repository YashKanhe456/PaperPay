const pool = require("../db/pool");

function agencyAccess(options = {}) {
  const {
    resourceTable,
    resourceIdParam = "id",
    agencyField = "agency_id",
  } = options;

  return async function checkAgencyAccess(req, res, next) {
    if (!req.user || !req.user.agency_id) {
      return res.status(403).json({ message: "Agency access denied" });
    }

    const requestedAgencyId =
      req.body?.agency_id ||
      req.params?.agency_id ||
      req.query?.agency_id ||
      req.resource?.agency_id ||
      null;

    if (requestedAgencyId) {
      if (requestedAgencyId !== req.user.agency_id) {
        return res.status(403).json({ message: "Agency access denied" });
      }

      return next();
    }

    if (!resourceTable || !req.params?.[resourceIdParam]) {
      return next();
    }

    try {
      const { rows } = await pool.query(
        `SELECT ${agencyField} FROM ${resourceTable} WHERE id = $1 LIMIT 1`,
        [req.params[resourceIdParam]]
      );

      if (!rows.length) {
        return res.status(404).json({ message: "Resource not found" });
      }

      if (rows[0][agencyField] !== req.user.agency_id) {
        return res.status(403).json({ message: "Agency access denied" });
      }

      req.resource = {
        ...(req.resource || {}),
        agency_id: rows[0][agencyField],
      };

      return next();
    } catch (error) {
      return res.status(500).json({ message: "Failed to validate agency access" });
    }
  };
}

module.exports = agencyAccess;
