#!/bin/bash

# Run k6 load tests for archAIc microservices
# Usage: ./load/run-test.sh [normal|spike|endurance|stress] [--with-failures]

TEST_TYPE="${1:-normal}"
WITH_FAILURES="${2:-}"

# Check if k6 is installed
if ! command -v k6 &> /dev/null; then
  echo "❌ k6 is not installed. Install it with:"
  echo "   brew install k6"
  exit 1
fi

# Check if the test script exists
SCRIPT_FILE="./load/${TEST_TYPE}.js"
if [ ! -f "$SCRIPT_FILE" ]; then
  echo "❌ Test script not found: $SCRIPT_FILE"
  echo ""
  echo "Available tests:"
  echo "  - normal:    10 VUs for 30s"
  echo "  - spike:     0→50→0 VUs (spike test)"
  echo "  - endurance: 5 VUs for 2min (long-running)"
  echo "  - stress:    0→100 VUs (stress test)"
  exit 1
fi

# Inject failures if requested
if [ "$WITH_FAILURES" == "--with-failures" ]; then
  echo "💥 Injecting failures before load test..."
  
  # Inject timeout on product service
  curl -X POST "http://localhost:8003/inject-failure?type=timeout&duration=120" 2>/dev/null
  
  # Inject error on db service
  curl -X POST "http://localhost:8002/inject-failure?type=error&duration=120" 2>/dev/null
  
  echo "✅ Failures injected"
  sleep 2
fi

# Print test info
echo ""
echo "🚀 Starting k6 Load Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Type: $TEST_TYPE"
echo "Script: $SCRIPT_FILE"
echo "Failures: $([ "$WITH_FAILURES" == "--with-failures" ] && echo "Enabled" || echo "Disabled")"
echo ""
echo "Services tested:"
echo "  • Auth (8001)"
echo "  • DB (8002)"
echo "  • Product (8003)"
echo "  • Payment (8004)"
echo ""
echo "Press Ctrl+C to stop"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Run the k6 test with output
k6 run "$SCRIPT_FILE"

# Summary
echo ""
echo "✅ Test completed!"
echo ""
echo "💡 Tip: Check the dashboard at http://localhost:7000 to see the effects"
