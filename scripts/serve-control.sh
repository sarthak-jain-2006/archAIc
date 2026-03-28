#!/bin/bash

# Simple HTTP server to serve the control page
# Usage: ./scripts/serve-control.sh

PORT=${1:-8080}
CONTROL_PAGE="./scripts/control-page.html"

if [ ! -f "$CONTROL_PAGE" ]; then
  echo "Error: control-page.html not found at $CONTROL_PAGE"
  exit 1
fi

echo "🎮 Starting Control Dashboard on http://localhost:$PORT"
echo "📱 Open this URL on your phone or laptop to control failures and load tests"
echo ""
echo "Services should be running on:"
echo "  • Auth Service: http://localhost:8001"
echo "  • DB Service: http://localhost:8002"
echo "  • Product Service: http://localhost:8003"
echo "  • Payment Service: http://localhost:8004"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Use Python's built-in HTTP server
python3 -m http.server $PORT --directory "$(dirname "$CONTROL_PAGE")"
