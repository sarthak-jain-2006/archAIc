import http from "k6/http";
import { sleep, check } from "k6";

export const options = {
  vus: 5, // 5 virtual users
  duration: "2m", // Run for 2 minutes (long-running endurance test)
  thresholds: {
    http_req_duration: ["p(95)<500"],
    http_req_failed: ["rate<0.05"],
  },
};

const PRODUCT_URL = "http://localhost:8003";
const AUTH_URL = "http://localhost:8001";

export default function () {
  // Endurance test: Simulate steady, continuous user activity

  // 1. Get products
  let productsRes = http.get(`${PRODUCT_URL}/products`);
  check(productsRes, {
    "products load": (r) => r.status === 200,
  });

  sleep(2);

  // 2. Authenticate user
  let loginRes = http.post(
    `${AUTH_URL}/login`,
    JSON.stringify({
      email: "endurance-tester@example.com",
      password: "secure123",
    }),
    {
      headers: { "Content-Type": "application/json" },
    },
  );

  if (loginRes.status === 200) {
    let token = loginRes.json("access_token");

    // 3. Browse cart repeatedly
    for (let i = 0; i < 3; i++) {
      let cartRes = http.get(`${PRODUCT_URL}/cart`, {
        headers: { Authorization: `Bearer ${token}` },
      });

      check(cartRes, {
        "cart consistency": (r) => r.status === 200,
      });

      sleep(1);
    }
  }

  sleep(3);
}
