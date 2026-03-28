#!/bin/bash

# Quick reference for archAIc chaos testing
# Usage: ./scripts/chaos-help.sh

cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║           🎮 archAIc Chaos Control Quick Reference            ║
╚════════════════════════════════════════════════════════════════╝

📱 CONTROL DASHBOARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Start the control dashboard:
  $ ./scripts/serve-control.sh

Open in browser:
  🖥️  Laptop:  http://localhost:8080
  📱 Phone:   http://<your-ip>:8080

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚀 LOAD TESTING WITH K6
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Prerequisites: brew install k6

Normal load test:          ./load/run-test.sh normal
Spike test:               ./load/run-test.sh spike
Endurance test (2 min):   ./load/run-test.sh endurance
Stress test (100 VUs):    ./load/run-test.sh stress

With failures injected:   ./load/run-test.sh normal --with-failures

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💥 FAILURE INJECTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Timeout (8s delay):
  $ curl -X POST http://localhost:8003/inject-failure?type=timeout&duration=30

Error (500 responses):
  $ curl -X POST http://localhost:8003/inject-failure?type=error&duration=30

CPU spike:
  $ curl -X POST http://localhost:8003/inject-failure?type=cpu&duration=30

Reset all services:
  $ for port in 8001 8002 8003 8004; do
      curl -X POST http://localhost:$port/reset
    done

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔍 MONITORING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dashboard:     http://localhost:7000
Prometheus:    http://localhost:9090
Jaeger:        http://localhost:16686
Grafana:       http://localhost:3000

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

👨‍💻 SERVICE HEALTH
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Auth Service:    curl http://localhost:8001/health
DB Service:      curl http://localhost:8002/health
Product Service: curl http://localhost:8003/health
Payment Service: curl http://localhost:8004/health

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 TYPICAL WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Terminal 1: ./scripts/serve-control.sh
2. Terminal 2: ./load/run-test.sh normal              (baseline)
3. Open browser: http://localhost:8080 (on phone)
4. Click "INJECT FAILURE" (timeout)
5. Terminal 3: ./load/run-test.sh spike               (under failure)
6. Observe: http://localhost:7000 (dashboard)
7. Click "RESET ALL FAILURES"
8. Terminal 4: ./load/run-test.sh normal              (verify recovery)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📚 MORE INFO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  $ cat load/README.md

EOF
