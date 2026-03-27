# DB Service API

Base URL (local): `http://localhost:8002`

This service injects/propagates `X-Trace-ID` for all requests.

## Header Conventions

### Request Headers

| Header                           | Required                      | Notes                              |
| -------------------------------- | ----------------------------- | ---------------------------------- |
| `Content-Type: application/json` | Required for `POST /cart/add` | JSON body endpoint                 |
| `X-Trace-ID`                     | Optional on all routes        | If omitted, service generates UUID |

### Response Headers (all routes)

| Header                           | Present | Notes                                      |
| -------------------------------- | ------- | ------------------------------------------ |
| `Content-Type: application/json` | Yes     | JSON response payload                      |
| `X-Trace-ID`                     | Yes     | Echoes incoming trace ID or generated UUID |

## Routes

### 1) GET `/products`

Fetch all products.

- Request headers:
  - `X-Trace-ID` (optional)
- Request body: none

- Success response (`200`):

```json
[
  {
    "id": "p1",
    "name": "Wireless Headphones",
    "price": 79.99,
    "stock": 50
  }
]
```

- Common error responses:
  - `503` injected DB error (`type=error`)

Note: when failure mode is `bad_data`, this route intentionally returns corrupted values such as `name: null` and `price: -1`.

### 2) POST `/cart/add`

Add a product to a user cart and decrement stock.

- Request headers:
  - `Content-Type: application/json` (required)
  - `X-Trace-ID` (optional)
- Request body:

```json
{
  "user_id": "alice",
  "product_id": "p1",
  "quantity": 2
}
```

- Success response (`200`):

```json
{
  "status": "added",
  "cart": [
    {
      "product_id": "p1",
      "name": "Wireless Headphones",
      "price": 79.99,
      "quantity": 2
    }
  ],
  "trace_id": "<uuid>"
}
```

- Common error responses:
  - `404` product not found
  - `409` insufficient stock
  - `503` injected DB error (`type=error`)

### 3) GET `/cart/{user_id}`

Fetch cart for specific user ID.

- Request headers:
  - `X-Trace-ID` (optional)
- Path params:
  - `user_id` (required)
- Request body: none

- Success response (`200`):

```json
{
  "user_id": "alice",
  "items": [
    {
      "product_id": "p1",
      "name": "Wireless Headphones",
      "price": 79.99,
      "quantity": 2
    }
  ],
  "total": 159.98,
  "trace_id": "<uuid>"
}
```

- Common error responses:
  - `503` injected DB error (`type=error`)

### 4) GET `/health`

Health and current failure mode.

- Request headers:
  - `X-Trace-ID` (optional)
- Request body: none

- Success response (`200`):

```json
{
  "status": "healthy",
  "service": "db-service",
  "failure": null
}
```

### 5) POST `/inject-failure?type=<timeout|error|cpu|crash|bad_data>`

Enable failure injection mode.

- Request headers:
  - `X-Trace-ID` (optional)
- Query params:
  - `type` (required): `timeout`, `error`, `cpu`, `crash`, `bad_data`
- Request body: none

- Success response (`200`):

```json
{
  "injected": "bad_data",
  "service": "db-service"
}
```

- Common error responses:
  - `400` invalid failure type

### 6) POST `/reset`

Disable failure injection mode.

- Request headers:
  - `X-Trace-ID` (optional)
- Request body: none

- Success response (`200`):

```json
{
  "status": "reset",
  "service": "db-service"
}
```
