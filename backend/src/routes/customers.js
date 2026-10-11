const express = require("express");

const auth = require("../middleware/auth");
const agencyAccess = require("../middleware/agencyAccess");
const { requireRole } = require("../middleware/requireRole");
const customerController = require("../controllers/customerController");

const router = express.Router();

// Customer records are administrative data: only an agency admin may manage them.
router.use(auth, requireRole("agency_admin"));

router.get("/defaulters", agencyAccess(), customerController.getDefaulters);
router.get("/", agencyAccess(), customerController.listCustomers);
router.post("/", agencyAccess(), customerController.createCustomer);
router.get("/:id", agencyAccess({ resourceTable: "customers" }), customerController.getCustomerById);
router.put("/:id", agencyAccess({ resourceTable: "customers" }), customerController.updateCustomer);
router.delete("/:id", agencyAccess({ resourceTable: "customers" }), customerController.deleteCustomer);
router.post(
  "/:id/pause",
  agencyAccess({ resourceTable: "customers" }),
  customerController.pauseCustomer
);
router.post(
  "/:id/resume",
  agencyAccess({ resourceTable: "customers" }),
  customerController.resumeCustomer
);

module.exports = router;
