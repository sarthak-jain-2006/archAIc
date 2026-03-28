import http from "k6/http";
import { sleep, check } from "k6";

export const options = {
  stages: [
    { duration: "10s", target: 10 }, // ramp up to 10
    { duration: "10s", target: 20 }, // ramp to 20
    { duration: "10s", target: 50 }, // ramp to 50
    { duration: "10s", target: 100 }, // ramp to 100
    { duration: "20s", target: 100 }, // stay at 100
    { duration: "20s", target: 0 }, // ramp down
  ],
  thresholds: {
    http_req_duration: ["p(95)<2000", "p(99)<5000"],
    http_req_failed: ["rate<0.5"], // Allow high error rate during stress
  },
};

const PRODUCT_URL = "http://localhost:8003";
const AUTH_URL = "http://localhost:8001";
const PAYMENT_URL = "http://localhost:8004";

export default function () {
  // Stress test: Push system to its limits

  // Heavy product catalog requests
  let productsRes = http.get(`${PRODUCT_URL}/products`);
  check(productsRes, {
    "products status": (r) => r.status === 200,
  });

  sleep(0.3);

  // Multiple authentication attempts
  let loginRes = http.post(
    `${AUTH_URL}/login`,
    JSON.stringify({
      email: `stress-${Math.random()}@example.com`,
      password: "secure123",
    }),
    {
      headers: { "Content-Type": "application/json" },
    },
  );

  if (loginRes.status === 200) {
    let token = loginRes.json("access_token");

    // Add to cart
    http.post(
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

    sleep(0.2);

    // Get cart
    http.get(`${PRODUCT_URL}/cart`, {
      headers: { Authorization: `Bearer ${token}` },
    });

    sleep(0.2);

    // Try checkout
    http.post(`${PAYMENT_URL}/create-checkout-session`, null, {
      headers: { Authorization: `Bearer ${token}` },
    });
  }

  sleep(0.5);
}
