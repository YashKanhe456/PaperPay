/**
 * requireRole(...allowedRoles)
 *
 * Rejects requests where req.user.role is not one of `allowedRoles`. This is
 * intentionally a strict gate: it does not attempt to infer permissions from
 * client-supplied fields, request bodies, or query parameters.
 *
 * Most agency-scoped endpoints already use agencyAccess, which enforces
 * ownership by agency. requireRole is for endpoints that need an explicit
 * role assertion before any agency check, or for admin-only paths.
 */
"use strict";

function requireRole(...allowedRoles) {
  if (!allowedRoles.length) {
    throw new Error("requireRole: at least one allowed role is required");
  }

  const allowed = new Set(allowedRoles);

  return function gate(req, res, next) {
    const userRole = req.user?.role;

    if (!userRole || !allowed.has(userRole)) {
      return res.status(403).json({ message: "Access denied" });
    }

    return next();
  };
}

module.exports = { requireRole };
