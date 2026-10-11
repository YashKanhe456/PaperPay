const fs = require("fs");
const path = require("path");
const multer = require("multer");

const uploadDir = path.join(process.cwd(), "tmp", "uploads");

if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const allowedMimeTypes = new Set([
  "image/jpeg",
  "image/jpg",
  "image/png",
  "application/pdf",
]);

/**
 * The original filename came straight from the client and was only stripped of
 * whitespace, so a name such as `../../server.js` could escape the upload
 * directory. Only a base name made of safe characters is kept.
 */
function sanitizeFilename(originalName) {
  const baseName = path.basename(String(originalName || "").replace(/\\/g, "/"));
  const safeName = baseName
    .replace(/[^A-Za-z0-9._-]/g, "_")
    .replace(/^\.+/, "_")
    .slice(-120);

  if (!safeName || /^[._]+$/.test(safeName)) {
    return "upload";
  }

  return safeName;
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${sanitizeFilename(file.originalname)}`);
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: 5 * 1024 * 1024,
  },
  fileFilter: (req, file, cb) => {
    if (!allowedMimeTypes.has(file.mimetype)) {
      cb(new Error("Only jpg, jpeg, png, and pdf files are allowed"));
      return;
    }

    cb(null, true);
  },
});

module.exports = upload;
module.exports.sanitizeFilename = sanitizeFilename;
module.exports.allowedMimeTypes = allowedMimeTypes;
