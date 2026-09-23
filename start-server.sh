#!/bin/bash

set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$ROOT/backend"
FRONTEND_DIR="$ROOT/frontend"
WEB_ROOT="/var/www/html"

BACKEND_LOG="/tmp/crusher-backend.log"
NGROK_LOG="/tmp/crusher-ngrok.log"

echo ""
echo "============================================================"
echo "        CRUSHER MANAGEMENT - STARTING SERVER"
echo "============================================================"
echo ""

# ------------------------------------------------------------
# 1. CHECK REQUIREMENTS
# ------------------------------------------------------------
echo "[1/6] Checking requirements..."

REQUIRED_COMMANDS=("java" "mvn" "flutter" "nginx" "curl" "nc")

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: '$cmd' is not installed."
        exit 1
    fi
done

if [ ! -d "$BACKEND_DIR" ]; then
    echo "ERROR: Backend directory not found:"
    echo "  $BACKEND_DIR"
    exit 1
fi

if [ ! -d "$FRONTEND_DIR" ]; then
    echo "ERROR: Frontend directory not found:"
    echo "  $FRONTEND_DIR"
    exit 1
fi

if [ ! -f "$FRONTEND_DIR/pubspec.yaml" ]; then
    echo "ERROR: Flutter project not found."
    echo "Expected:"
    echo "  $FRONTEND_DIR/pubspec.yaml"
    exit 1
fi

echo "Requirements OK ✓"
echo ""


# ------------------------------------------------------------
# 2. STOP OLD PROCESSES
# ------------------------------------------------------------
echo "[2/6] Stopping old processes..."

# Backend
if lsof -ti :8080 >/dev/null 2>&1; then
    echo "Stopping process on port 8080..."
    kill $(lsof -ti :8080) 2>/dev/null || true
    sleep 2

    # Force kill if still running
    if lsof -ti :8080 >/dev/null 2>&1; then
        kill -9 $(lsof -ti :8080) 2>/dev/null || true
    fi
fi

echo "Backend port 8080 is free ✓"

# Ngrok
pkill -x ngrok 2>/dev/null || true

echo "Old processes stopped ✓"
echo ""


# ------------------------------------------------------------
# 3. BUILD LATEST FLUTTER WEB APP
# ------------------------------------------------------------
echo "[3/6] Building latest Flutter frontend..."

cd "$FRONTEND_DIR"

echo "Frontend directory:"
echo "  $FRONTEND_DIR"
echo ""

echo "Getting Flutter dependencies..."
flutter pub get
flutter clean

echo ""
echo "Building Flutter Web..."
flutter build web --release

if [ ! -d "$FRONTEND_DIR/build/web" ]; then
    echo ""
    echo "ERROR: Flutter web build failed."
    exit 1
fi

echo ""
echo "Copying latest frontend to Nginx..."

sudo mkdir -p "$WEB_ROOT"

sudo rm -rf "$WEB_ROOT"/*

sudo cp -r "$FRONTEND_DIR/build/web/"* "$WEB_ROOT/"

echo ""
echo "Frontend deployed ✓"
echo "  $WEB_ROOT"
echo ""


# ------------------------------------------------------------
# 4. START SPRING BOOT BACKEND
# ------------------------------------------------------------
echo "[4/6] Starting backend on port 8080..."

cd "$BACKEND_DIR"

# Use Maven wrapper if project has it
if [ -x "./mvnw" ]; then
    echo "Using Maven Wrapper..."
    nohup ./mvnw spring-boot:run \
        > "$BACKEND_LOG" 2>&1 &
else
    echo "Using system Maven..."
    nohup mvn spring-boot:run \
        > "$BACKEND_LOG" 2>&1 &
fi

BACKEND_PID=$!

echo "Backend PID: $BACKEND_PID"

echo ""
echo "Waiting for backend..."

BACKEND_READY=false

for i in {1..60}; do
    if nc -z localhost 8080 >/dev/null 2>&1; then
        BACKEND_READY=true
        break
    fi

    # Check whether process died
    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
        echo ""
        echo "ERROR: Backend stopped unexpectedly."
        echo ""
        echo "Last backend log:"
        echo "------------------------------------------------------------"
        tail -40 "$BACKEND_LOG"
        echo "------------------------------------------------------------"
        exit 1
    fi

    sleep 2
    echo -n "."
done

echo ""

if [ "$BACKEND_READY" = false ]; then
    echo ""
    echo "ERROR: Backend did not start within 120 seconds."
    echo ""
    echo "Last backend log:"
    echo "------------------------------------------------------------"
    tail -50 "$BACKEND_LOG"
    echo "------------------------------------------------------------"
    exit 1
fi

echo "Backend ready ✓"
echo ""


# ------------------------------------------------------------
# 5. START NGINX
# ------------------------------------------------------------
echo "[5/6] Starting Nginx..."

# Make sure configuration is valid
sudo nginx -t

echo ""

sudo systemctl enable nginx >/dev/null 2>&1 || true
sudo systemctl start nginx

# If already running, reload it
sudo systemctl reload nginx 2>/dev/null || true

echo "Nginx ready ✓"
echo "  Local URL: http://localhost"
echo ""


# ------------------------------------------------------------
# 6. START NGROK
# ------------------------------------------------------------
echo "[6/6] Starting ngrok..."

if ! command -v ngrok >/dev/null 2>&1; then

    echo "WARNING: ngrok is not installed."
    echo ""
    echo "Local network URL:"
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    echo "  http://$LOCAL_IP"
    echo ""

else

    # Check whether ngrok can start
    nohup ngrok http 80 \
        > "$NGROK_LOG" 2>&1 &

    NGROK_PID=$!

    echo "Ngrok PID: $NGROK_PID"

    echo ""
    echo "Waiting for ngrok..."

    NGROK_URL=""

    for i in {1..15}; do

        sleep 1

        NGROK_URL=$(curl -s \
            http://localhost:4040/api/tunnels \
            2>/dev/null \
            | grep -o '"public_url":"https://[^"]*"' \
            | head -1 \
            | cut -d'"' -f4)

        if [ -n "$NGROK_URL" ]; then
            break
        fi

    done

    echo ""

    if [ -n "$NGROK_URL" ]; then

        echo "Ngrok ready ✓"
        echo ""

        LOCAL_IP=$(hostname -I | awk '{print $1}')

        echo "============================================================"
        echo "                    SERVER READY"
        echo "============================================================"
        echo ""
        echo "  [1] THIS LAPTOP:"
        echo "      http://localhost"
        echo "      (open in browser on this machine)"
        echo ""
        echo "  [2] SAME NETWORK (phone on same WiFi/hotspot):"
        echo "      http://$LOCAL_IP"
        echo "      USE THIS on your phone for fastest speed."
        echo "      No internet delay — works like localhost."
        echo ""
        echo "  [3] REMOTE / OUTSIDE NETWORK:"
        echo "      $NGROK_URL"
        echo "      Use ONLY when the phone is on a different network."
        echo "      Slower — every request routes through ngrok servers."
        echo ""
        echo "------------------------------------------------------------"
        echo "  Backend:  http://localhost:8080"
        echo "  Web:      Nginx :80  →  proxies /api/ to backend"
        echo "  Tunnel:   Ngrok (for remote access only)"
        echo "------------------------------------------------------------"
        echo ""
        echo "LOGS:"
        echo "  tail -f $BACKEND_LOG"
        echo "  tail -f $NGROK_LOG"
        echo ""
        echo "STOP:"
        echo "  ./stop-server.sh"
        echo ""
        echo "============================================================"
        echo ""

    else

        echo "WARNING: Ngrok started but public URL was not detected."
        echo ""
        echo "Check:"
        echo "  http://localhost:4040"
        echo ""
        echo "Ngrok log:"
        tail -20 "$NGROK_LOG"
        echo ""

    fi
fi
