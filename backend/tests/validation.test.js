/**
 * Validation / hardening unit tests for code paths that need no database.
 */
const test = require("node:test");
const assert = require("node:assert/strict");

const { stripSslModeFromConnectionString } = require("../src/db/pool");
const upload = require("../src/middleware/upload");

test("sslmode is removed from the connection string so TLS config wins", () => {
  const stripped = stripSslModeFromConnectionString(
    "postgresql://user:secret@db.example.com:5432/paperpay?sslmode=no-verify"
  );

  assert.equal(stripped.includes("sslmode"), false);
  assert.equal(stripped.includes("no-verify"), false);
  assert.equal(stripped.startsWith("postgresql://user:secret@db.example.com:5432/paperpay"), true);
});

test("uselibpqcompat is removed as well", () => {
  const stripped = stripSslModeFromConnectionString(
    "postgres://user:secret@db.example.com/paperpay?sslmode=require&uselibpqcompat=true"
  );

  assert.equal(stripped.includes("uselibpqcompat"), false);
  assert.equal(stripped.includes("sslmode"), false);
});

test("connection strings that are already clean are left usable", () => {
  const original = "postgres://user:secret@db.example.com/paperpay";
  assert.equal(stripSslModeFromConnectionString(original), original);
});

test("a missing connection string passes through untouched", () => {
  assert.equal(stripSslModeFromConnectionString(undefined), undefined);
  assert.equal(stripSslModeFromConnectionString(""), "");
});

test("upload filenames cannot escape the upload directory", () => {
  assert.equal(upload.sanitizeFilename("../../etc/passwd"), "passwd");
  assert.equal(upload.sanitizeFilename("..\\..\\windows\\system32\\cmd.exe"), "cmd.exe");
  assert.equal(upload.sanitizeFilename("C:\\Users\\hp\\secret.png"), "secret.png");
  assert.equal(upload.sanitizeFilename("a b.png"), "a_b.png");
  assert.equal(upload.sanitizeFilename("invoice (1).pdf"), "invoice__1_.pdf");
  assert.equal(upload.sanitizeFilename(""), "upload");
  assert.equal(upload.sanitizeFilename("..."), "upload");
});

test("only image and pdf mime types are accepted", () => {
  assert.equal(upload.allowedMimeTypes.has("image/png"), true);
  assert.equal(upload.allowedMimeTypes.has("image/jpeg"), true);
  assert.equal(upload.allowedMimeTypes.has("application/pdf"), true);
  assert.equal(upload.allowedMimeTypes.has("image/svg+xml"), false);
  assert.equal(upload.allowedMimeTypes.has("text/html"), false);
});
