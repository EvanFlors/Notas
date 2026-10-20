// Capstone stage 14 — k6 load profile for FastAPI.
// Scenarios:
//   smoke  — 1 VU for 1 min (default, always runs)
//   ramp   — 0 -> 50 VUs in 2 min, hold 3 min, down 1 min
//   soak   — 20 VUs for 15 min (only when SOAK env var is "1")
//
// Thresholds abort the run if the system is clearly misbehaving.
// Target base URL comes from BASE_URL env var; default is a local-forward.

import http from "k6/http";
import { check, sleep } from "k6";

const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";
const SOAK = __ENV.SOAK === "1";

export const options = {
  scenarios: {
    smoke: {
      executor: "constant-vus",
      vus: 1,
      duration: "1m",
      tags: { scenario: "smoke" },
    },
    ramp: {
      executor: "ramping-vus",
      startVUs: 0,
      stages: [
        { duration: "2m", target: 50 },
        { duration: "3m", target: 50 },
        { duration: "1m", target: 0 },
      ],
      startTime: "1m",
      tags: { scenario: "ramp" },
    },
    ...(SOAK
      ? {
          soak: {
            executor: "constant-vus",
            vus: 20,
            duration: "15m",
            startTime: "7m",
            tags: { scenario: "soak" },
          },
        }
      : {}),
  },
  thresholds: {
    "http_req_failed{expected_response:true}": ["rate<0.01"],
    "http_req_duration{scenario:smoke}": ["p(95)<500"],
    "http_req_duration{scenario:ramp}": ["p(95)<800"],
  },
};

export default function () {
  // /health is a cheap readiness endpoint; /items exercises Postgres.
  const health = http.get(`${BASE_URL}/health`, {
    tags: { endpoint: "health" },
  });
  check(health, { "health 200": (r) => r.status === 200 });

  const items = http.get(`${BASE_URL}/items`, {
    tags: { endpoint: "items" },
  });
  check(items, {
    "items 200": (r) => r.status === 200,
    "items has body": (r) => (r.body || "").length > 0,
  });

  sleep(1);
}
