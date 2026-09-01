#!/bin/bash
ROOT="$(cd "$(dirname "$0")" && pwd)"

# Kill anything already on these ports
kill $(lsof -ti :8080) 2>/dev/null
kill $(lsof -ti :3000) 2>/dev/null
sleep 1

echo "[1/2] Starting backend on :8080 ..."
cd "$ROOT/backend"
nohup mvn spring-boot:run -q > /tmp/crusher-backend.log 2>&1 &
echo "  Backend PID: $!"

# Wait until port 8080 is actually accepting connections
until nc -z localhost 8080 2>/dev/null; do sleep 2; done
echo "  Backend ready ✓"

echo "[2/2] Starting frontend on :3000 ..."
cd "$ROOT/frontend"
nohup flutter run -d web-server --web-port 3000 --web-hostname 0.0.0.0 \
  > /tmp/crusher-frontend.log 2>&1 &
echo "  Frontend PID: $!"

until grep -q "is being served at" /tmp/crusher-frontend.log 2>/dev/null; do sleep 3; done
echo "  Frontend ready ✓"

echo ""
echo "  App: http://localhost:3000"
echo "  Logs: tail -f /tmp/crusher-backend.log"
echo "        tail -f /tmp/crusher-frontend.log"
