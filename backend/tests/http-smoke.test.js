/**
 * HTTP smoke tests.
 *
 * The Express app is started on an ephemeral port with an unreachable dummy
 * database URL, so nothing here touches a real database. These tests cover the
 * behaviour that a reviewer can check without credentials:
 *   - CORS allow-list (allowed origin gets the header, unknown origin does not)
 *   - helmet security headers
 *   - unauthenticated requests to protected routes return 401
 *   - unknown routes return 404
 */
const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");

process.env.DATABASE_URL = "postgres://paperpay:paperpay@127.0.0.1:1/paperpay_test";
process.env.CORS_ALLOWED_ORIGINS = "http://localhost:3000";
process.env.JWT_SECRET = "test-secret-not-used";

const app = require("../src/app");
const pool = require("../src/db/pool");

let server;
let port;

test.before(async () => {
  server = app.listen(0);
  await new Promise((resolve) => server.once("listening", resolve));
  port = server.address().port;
});

test.after(async () => {
  if (server) {
    await new Promise((resolve) => server.close(resolve));
  }
  await pool.end().catch(() => {});
});

function request(path, { method = "GET", headers = {}, body } = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      { host: "127.0.0.1", port, path, method, headers },
      (res) => {
        let payload = "";
        res.on("data", (chunk) => {
          payload += chunk;
        });
        res.on("end", () =>
          resolve({ status: res.statusCode, headers: res.headers, body: payload })
        );
      }
    );

    req.on("error", reject);
    if (body !== undefined) {
      req.write(body);
    }
    req.end();
  });
}

test("helmet adds the nosniff header", async () => {
  const res = await request("/api/health");
  assert.equal(res.headers["x-content-type-options"], "nosniff");
});

test("rate limiting is applied to the API", async () => {
  const res = await request("/api/health");
  assert.equal(res.headers["ratelimit-limit"], "100");
});

test("CORS: an allow-listed origin receives the CORS header", async () => {
  const res = await request("/api/health", { headers: { Origin: "http://localhost:3000" } });
  assert.equal(res.headers["access-control-allow-origin"], "http://localhost:3000");
});

test("CORS: an unknown origin receives no CORS header", async () => {
  const res = await request("/api/health", { headers: { Origin: "http://evil.example" } });
  assert.equal(res.headers["access-control-allow-origin"], undefined);
});

test("CORS: preflight from an unknown origin is not approved", async () => {
  const res = await request("/api/customers", {
    method: "OPTIONS",
    headers: {
      Origin: "http://evil.example",
      "Access-Control-Request-Method": "GET",
    },
  });

  assert.equal(res.headers["access-control-allow-origin"], undefined);
});

test("health check reports a database error instead of crashing", async () => {
  const res = await request("/api/health");
  assert.equal(res.status, 500);
  assert.equal(JSON.parse(res.body).status, "error");
});

test("protected routes reject unauthenticated requests with 401", async () => {
  const routes = [
    { path: "/api/customers" },
    { path: "/api/bills" },
    { path: "/api/bills/defaulters" },
    { path: "/api/reports/dashboard" },
    { path: "/api/settings" },
    { path: "/api/newspapers?agency_id=00000000-0000-0000-0000-000000000000" },
    { path: "/api/delivery-boys?agency_id=00000000-0000-0000-0000-000000000000" },
    { path: "/api/subscriptions?agency_id=00000000-0000-0000-0000-000000000000" },
    { path: "/api/cash-collections" },
    { path: "/api/deliveries/today?agency_id=00000000-0000-0000-0000-000000000000" },
    { path: "/api/attendance?delivery_boy_id=00000000-0000-0000-0000-000000000000&month=1&year=2026" },
    { path: "/api/notifications" },
    { path: "/api/agencies/me" },
    { path: "/api/customer-app/me" },
  ];

  for (const route of routes) {
    const res = await request(route.path);
    assert.equal(res.status, 401, `${route.path} should require authentication`);
  }
});

test("mutating routes reject unauthenticated requests with 401", async () => {
  const posts = [
    "/api/customers",
    "/api/bills/generate",
    "/api/payments/cash",
    "/api/notifications/register-token",
    "/api/notifications/send",
    "/api/deliveries/mark",
    "/api/attendance/clockin",
    "/api/upload/delivery-photo",
  ];

  for (const path of posts) {
    const res = await request(path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
    });
    assert.equal(res.status, 401, `POST ${path} should require authentication`);
  }
});

test("a malformed bearer token is rejected with 401", async () => {
  const res = await request("/api/customers", { headers: { Authorization: "Bearer not-a-jwt" } });
  assert.equal(res.status, 401);
});

test("unknown routes return 404", async () => {
  const res = await request("/api/does-not-exist");
  assert.equal(res.status, 404);
});
