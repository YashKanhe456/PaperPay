"use strict";

const assert = require("assert");
const { describe, it } = require("node:test");
const http = require("http");

function fakePool() {
  return {
    query: () => Promise.resolve({ rows: [] }),
    end: () => Promise.resolve(),
  };
}

// Make require("../src/db/pool") return a function that hands out the fake pool.
const poolModule = require("../src/db/pool");
poolModule.exports = fakePool;

const app = require("../src/app");

async function request({ method = "GET", path: reqPath, headers = {}, body }) {
  return new Promise((resolve, reject) => {
    const server = http.createServer(app);
    server.listen(0, "127.0.0.1", () => {
      const addr = server.address();
      if (!addr) {
        server.close();
        return reject(new Error("server did not get an address"));
      }
      const port = addr.port;
      const options = {
        hostname: "127.0.0.1",
        port,
        path: reqPath,
        method,
        headers: {
          "Content-Type": "application/json",
          ...headers,
        },
      };
      const req = http.request(options, (res) => {
        res.resume();
        let data = "";
        res.on("data", (chunk) => { data += chunk; });
        res.on("end", () => {
          let parsed = null;
          try { parsed = JSON.parse(data); } catch (err) {}
          server.close();
          resolve({ status: res.statusCode, body: parsed, raw: data });
        });
      });
      req.on("error", (err) => {
        server.close();
        reject(err);
      });
      if (body) req.write(JSON.stringify(body));
      req.end();
    });
    server.on("error", reject);
  });
}

describe("authorization smoke checks", () => {
  it("health should be reachable without auth", async () => {
    const r = await request({ path: "/api/health" });
    assert.strictEqual(r.status, 200);
    assert.ok(r.body && typeof r.body === "object", "health body should be an object");
  });

  it("customer-app/me should be 401 without a token", async () => {
    const r = await request({ path: "/api/customer-app/me" });
    assert.strictEqual(r.status, 401);
  });

  it("customer-app/me should be 401 with a tampered token", async () => {
    const r = await request({
      path: "/api/customer-app/me",
      headers: { Authorization: "Bearer tampered.token.value" },
    });
    assert.strictEqual(r.status, 401);
  });

  it("bills should be 401 without a token", async () => {
    const r = await request({ path: "/api/bills" });
    assert.strictEqual(r.status, 401);
  });
});
