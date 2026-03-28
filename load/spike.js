import http from "k6/http";
import { sleep, check } from "k6";

export const options = {
  stages: [
    { duration: "5s", target: 0 }, // start at 0
    { duration: "10s", target: 50 }, // ramp up to 50 in 10s
    { duration: "20s", target: 50 }, // staytime at 50 for 20s
    { duration: "10s", target: 0 }, // ramp down to 0 in 10s
  ],
  thresholds: {
    http_req_duration: ["p(95)<1000", "p(99)<2000"],
    http_req_failed: ["rate<0.2"], // Allow higher error rate under spike
  },
};

const PRODUCT_URL = "http://localhost:8003";
const AUTH_URL = "http://localhost:8001";

export default function () {
  // Spike test focuses on product catalog and authentication

  // Get products
  let productsRes = http.get(`${PRODUCT_URL}/products`);
  check(productsRes, {
    "products status": (r) => r.status === 200,
  });

  sleep(0.5);

  // Try login
  let loginRes = http.post(
    `${AUTH_URL}/login`,
    JSON.stringify({
      email: `spike-${Math.random()}@example.com`,
      password: "secure123",
    }),
    {
      headers: { "Content-Type": "application/json" },
    },
  );

  check(loginRes, {
    "login status": (r) => r.status === 200 || r.status === 401,
  });

  sleep(0.5);
}
