# 🎮 archAIc Chaos Control Dashboard

Control failure injection, load testing, and system observability from your phone or laptop.

## Features

- **Failure Injection**: Inject timeouts, errors, crashes, and CPU spikes into microservices
- **Load Testing**: Run k6 load tests with different patterns (normal, spike, endurance, stress)
- **Phone-Friendly UI**: Large buttons and responsive design for mobile control
- **Real-Time Monitoring**: See the effects on the dashboard (http://localhost:7000)

## Quick Start

### 1. Start the Control Dashboard

```bash
chmod +x scripts/serve-control.sh
./scripts/serve-control.sh
```

The dashboard will be available at: **http://localhost:8080**

Open it on your phone using your laptop's IP address:

```bash
# Find your IP
ipconfig getifaddr en0  # macOS
hostname -I             # Linux

# Then open on phone: http://<your-ip>:8080
```

### 2. Verify Services Are Running

Ensure these services are accessible:

- **Auth Service**: http://localhost:8001
- **DB Service**: http://localhost:8002
- **Product Service**: http://localhost:8003
- **Payment Service**: http://localhost:8004

Check health:

```bash
curl http://localhost:8001/health
curl http://localhost:8002/health
curl http://localhost:8003/health
curl http://localhost:8004/health
```

## Load Testing

### Prerequisites

Install k6:

```bash
brew install k6        # macOS
apt install k6         # Ubuntu/Debian
choco install k6       # Windows
```

### Run Tests

**Normal Load Test** (10 VUs, 30s):

```bash
chmod +x load/run-test.sh
./load/run-test.sh normal
```

**Spike Test** (sudden traffic spike, 50 VUs):

```bash
./load/run-test.sh spike
```

**Endurance Test** (5 VUs, 2 minutes):

```bash
./load/run-test.sh endurance
```

**Stress Test** (0→100 VUs, pushes system to limits):

```bash
./load/run-test.sh stress
```

**Run With Failures** (inject failures during test):

```bash
./load/run-test.sh normal --with-failures
```

## Failure Injection

### Via Control Dashboard

1. Open http://localhost:8080
2. Select failure type, service, and duration
3. Click **INJECT FAILURE**

### Via Command Line

**Timeout Failure** (8 second response delay):

```bash
curl -X POST "http://localhost:8003/inject-failure?type=timeout&duration=30"
```

**Error Failure** (500 responses):

```bash
curl -X POST "http://localhost:8003/inject-failure?type=error&duration=30"
```

**CPU Spike**:

```bash
curl -X POST "http://localhost:8003/inject-failure?type=cpu&duration=30"
```

**Reset Failures**:

```bash
curl -X POST "http://localhost:8003/reset"
curl -X POST "http://localhost:8002/reset"
curl -X POST "http://localhost:8001/reset"
curl -X POST "http://localhost:8004/reset"
```

## Load Test Scripts

### normal.js

- **VUs**: 10 virtual users
- **Duration**: 30 seconds
- **Scenario**: Full user journey (login → products → cart → checkout)
- **Goal**: Establish baseline performance under normal load

### spike.js

- **Pattern**: 0 → 50 → 0 VUs
- **Total Duration**: 45 seconds (5s ramp, 20s peak, 10s ramp down)
- **Goal**: Test system response to sudden traffic spikes

### endurance.js

- **VUs**: 5 virtual users
- **Duration**: 2 minutes
- **Scenario**: Repeated cart operations
- **Goal**: Find memory leaks, connection pool issues, resource exhaustion

### stress.js

- **Pattern**: 0 → 100 VUs over 40 seconds, then ramp down
- **Total Duration**: 70 seconds
- **Goal**: Push system beyond capacity to find breaking points

## Monitoring During Tests

Watch the effects on the dashboard:

```bash
# Terminal 1: Start control dashboard
./scripts/serve-control.sh

# Terminal 2: Monitor services
kubectl logs -f deployment/product-service -n archaics

# Terminal 3: Run load test
./load/run-test.sh spike

# Terminal 4 (laptop): Open dashboard
open http://localhost:7000
```

## Typical Workflow

1. **Baseline Test**

   ```bash
   ./load/run-test.sh normal
   # Record response times, error rates
   ```

2. **Inject Failure**

   ```bash
   # Via dashboard or CLI
   curl -X POST "http://localhost:8003/inject-failure?type=timeout&duration=60"
   ```

3. **Test Under Failure**

   ```bash
   ./load/run-test.sh normal
   # Observe degradation and resilience
   ```

4. **Spike Test**

   ```bash
   ./load/run-test.sh spike
   # Check if system recovers
   ```

5. **Stress Test**

   ```bash
   ./load/run-test.sh stress --with-failures
   # Find limits and breaking points
   ```

6. **Reset and Verify**
   ```bash
   curl -X POST http://localhost:8003/reset
   ./load/run-test.sh normal
   # Confirm full recovery
   ```

## Mobile Control

The dashboard is optimized for mobile:

- **Large buttons** (25px padding) for finger-friendly control
- **Responsive grid** adapts to portrait and landscape
- **Live response log** shows real-time feedback
- **No dependencies** (pure HTML/CSS/JS)

### From Phone:

1. Get your laptop IP:

   ```bash
   ipconfig getifaddr en0  # macOS
   ```

2. Open on phone: `http://<laptop-ip>:8080`

3. Control failures and load tests from your phone
4. Watch effects on laptop dashboard at `http://localhost:7000`

## Troubleshooting

### "Cannot connect to service"

- Verify services are running: `kubectl get pods -n archaics`
- Check port-forwards are active if using Kubernetes
- Ensure firewall allows local connections

### k6 not found

```bash
brew install k6  # macOS
```

### Control dashboard not loading

```bash
# Make sure server is running
./scripts/serve-control.sh

# Check if port 8080 is in use
lsof -i :8080
```

### Failures not injecting

- Verify service endpoints are accessible
- Check response in control dashboard log
- Manually test: `curl -X POST http://localhost:8003/inject-failure?type=error&duration=30`

## Advanced: Custom k6 Scripts

Create a new test in `load/` directory:

```javascript
// load/custom.js
import http from "k6/http";
import { sleep, check } from "k6";

export const options = {
  vus: 5,
  duration: "30s",
};

export default function () {
  let res = http.get("http://localhost:8003/products");
  check(res, { "status 200": (r) => r.status === 200 });
  sleep(1);
}
```

Run it:

```bash
./load/run-test.sh custom
```

## Architecture

```
Control Dashboard (8080)
    ↓
    ├─→ Inject Failures → Microservices:8001-8004
    └─→ Run k6 Tests → Load on Services
         ↓
    Monitor Dashboard (7000)
         ↓
    Prometheus (9090)
    Jaeger (16686)
    Grafana (3000)
```

## See Also

- Dashboard: http://localhost:7000
- Prometheus: http://localhost:9090
- Jaeger: http://localhost:16686
- Grafana: http://localhost:3000
