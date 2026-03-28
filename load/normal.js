import http from "k6/http";
import { sleep, check } from "k6";

export const options = {
  vus: 10, // 10 virtual users
  duration: "30s", // Run for 30 seconds
  thresholds: {
    http_req_duration: ["p(95)<500", "p(99)<1000"], // 95% of requests < 500ms
    http_req_failed: ["rate<0.1"], // error rate < 10%
  },
};

const PRODUCT_URL = "http://localhost:8003";
const AUTH_URL = "http://localhost:8001";
const PAYMENT_URL = "http://localhost:8004";

export default function () {
  // 1. Get products (no auth required)
  let productsRes = http.get(`${PRODUCT_URL}/products`);
  check(productsRes, {
    "products status is 200": (r) => r.status === 200,
    "products response time < 1s": (r) => r.timings.duration < 1000,
  });

  sleep(1);

  // 2. Login
  let loginRes = http.post(
    `${AUTH_URL}/login`,
    JSON.stringify({
      email: `user-${Math.random()}@example.com`,
      password: "secure123",
    }),
    {
      headers: { "Content-Type": "application/json" },
    },
  );

  let token = null;
  if (loginRes.status === 200) {
    token = loginRes.json("access_token");
  }

  check(loginRes, {
    "login status is 200": (r) => r.status === 200,
  });

  sleep(1);

  if (token) {
    // 3. Get cart
    let cartRes = http.get(`${PRODUCT_URL}/cart`, {
      headers: { Authorization: `Bearer ${token}` },
    });

    check(cartRes, {
      "cart status is 200": (r) => r.status === 200,
    });

    sleep(1);

    // 4. Add to cart
    let addRes = http.post(
      `${PRODUCT_URL}/cart/add`,
      JSON.stringify({
        product_id: "p1",
        quantity: 1,
      }),
      {
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      },
    );

    check(addRes, {
      "add to cart status is 200": (r) => r.status === 200,
    });

    sleep(1);
  }
}
