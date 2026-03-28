import { NextRequest, NextResponse } from "next/server";

import { callPaymentService, jsonFromResponse } from "@/lib/storefront-server";

type CheckoutPayload = {
  checkout_url: string;
  amount_usd: number;
  session_id: string;
  trace_id: string;
  simulated?: boolean;
};

function createSimulatedCheckout(origin: string): CheckoutPayload {
  return {
    checkout_url: `${origin}/microservice-fe/checkout?simulated=1`,
    amount_usd: 49.99,
    session_id: `cs_sim_${Date.now()}`,
    trace_id: `trace_sim_${Date.now()}`,
    simulated: true,
  };
}

export async function POST(request: NextRequest) {
  const authorization = request.headers.get("authorization");
  const allowFallback =
    (process.env.SIMULATE_CHECKOUT_FALLBACK ?? "true").toLowerCase() === "true";

  try {
    const response = await callPaymentService("/create-checkout-session", {
      method: "POST",
      authorization,
    });
    const payload = (await jsonFromResponse(response)) as Record<
      string,
      unknown
    > | null;

    if (!response.ok) {
      if (allowFallback) {
        return NextResponse.json(
          createSimulatedCheckout(request.nextUrl.origin),
          { status: 200 },
        );
      }

      return NextResponse.json(payload, { status: response.status });
    }

    const normalized: CheckoutPayload = {
      checkout_url: String(
        payload?.checkout_url ??
          `${request.nextUrl.origin}/microservice-fe/checkout?simulated=1`,
      ),
      amount_usd: Number(payload?.amount_usd ?? payload?.amount ?? 0),
      session_id: String(payload?.session_id ?? `cs_${Date.now()}`),
      trace_id: String(payload?.trace_id ?? `trace_${Date.now()}`),
      simulated: Boolean(payload?.simulated ?? false),
    };

    return NextResponse.json(normalized, { status: 200 });
  } catch {
    if (allowFallback) {
      return NextResponse.json(
        createSimulatedCheckout(request.nextUrl.origin),
        { status: 200 },
      );
    }

    return NextResponse.json(
      { detail: "Checkout unavailable" },
      { status: 503 },
    );
  }
}
