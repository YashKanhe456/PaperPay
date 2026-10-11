const fs = require("fs/promises");

const express = require("express");

const auth = require("../middleware/auth");
const { requireRole } = require("../middleware/requireRole");
const upload = require("../middleware/upload");
const { uploadFile } = require("../services/cloudinary");

const router = express.Router();

async function handleUpload(req, res, folder, allowedTypes) {
  if (!req.file) {
    return res.status(400).json({ message: "File is required" });
  }

  if (allowedTypes && !allowedTypes.has(req.file.mimetype)) {
    await fs.unlink(req.file.path).catch(() => {});
    return res.status(400).json({ message: "Invalid file type" });
  }

  try {
    const result = await uploadFile(req.file.path, folder);
    await fs.unlink(req.file.path).catch(() => {});

    return res.status(201).json({
      url: result.secure_url,
      public_id: result.public_id,
    });
  } catch (error) {
    await fs.unlink(req.file.path).catch(() => {});

    if (error.message === "Cloudinary is not configured") {
      return res.status(500).json({ message: "Cloudinary is not configured" });
    }

    return res.status(500).json({ message: "File upload failed" });
  }
}

// Uploading pushes files into the agency's Cloudinary account — admins only.
router.use(auth, requireRole("agency_admin"));

router.post("/delivery-photo", upload.single("file"), async (req, res) => {
  return handleUpload(
    req,
    res,
    "deliveries",
    new Set(["image/jpeg", "image/jpg", "image/png"])
  );
});

router.post("/document", upload.single("file"), async (req, res) => {
  return handleUpload(
    req,
    res,
    "documents",
    new Set(["image/jpeg", "image/jpg", "image/png", "application/pdf"])
  );
});

router.post("/profile-photo", upload.single("file"), async (req, res) => {
  return handleUpload(
    req,
    res,
    "profiles",
    new Set(["image/jpeg", "image/jpg", "image/png"])
  );
});

module.exports = router;
