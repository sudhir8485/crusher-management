#!/bin/bash
cd "$(dirname "$0")"

# Kill anything already running on these ports
kill $(lsof -ti :8080) 2>/dev/null
kill $(lsof -ti :3000) 2>/dev/null
sleep 1

echo "[1/2] Starting backend on :8080 ..."
cd backend && nohup mvn spring-boot:run -q > /tmp/crusher-backend.log 2>&1 &
BACKEND_PID=$!
echo "  Backend PID: $BACKEND_PID"

# Wait for backend to be ready
until curl -sf http://localhost:8080/actuator/health > /dev/null 2>&1; do
  sleep 2
done
echo "  Backend ready ✓"

echo "[2/2] Starting frontend on :3000 ..."
cd ../frontend && nohup flutter run -d web-server --web-port 3000 --web-hostname 0.0.0.0 > /tmp/crusher-frontend.log 2>&1 &
FRONTEND_PID=$!
echo "  Frontend PID: $FRONTEND_PID"

until grep -q "is being served at" /tmp/crusher-frontend.log 2>/dev/null; do
  sleep 3
done
echo "  Frontend ready ✓"

echo ""
echo "  App running at: http://localhost:3000"
echo "  Backend logs:   tail -f /tmp/crusher-backend.log"
echo "  Frontend logs:  tail -f /tmp/crusher-frontend.log"
