#!/bin/bash

# Builds BOTH the Flutter web app AND a network APK from the latest code.
# Use this when you want to install the app on an Android phone WITHOUT a USB cable.
#
# The APK will connect via:
#   - ngrok URL  (if available — works from anywhere, any network)
#   - Local IP   (fallback — phone and laptop must be on the same WiFi)
#
# After running this script:
#   1. Open the DOWNLOAD URL on the phone's browser
#   2. Tap the .apk file to install it  (Enable "Install unknown apps" once)
#   3. EVERY TIME you re-run this script you MUST reinstall the APK on the phone
#
# Stop everything with:  ./stop-apk.sh

set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$ROOT/backend"
FRONTEND_DIR="$ROOT/frontend"
WEB_ROOT="/var/www/html"

BACKEND_LOG="/tmp/crusher-backend.log"
NGROK_LOG="/tmp/crusher-ngrok.log"
APK_NAME="crusher-app.apk"

echo ""
echo "============================================================"
echo "     CRUSHER MANAGEMENT - BUILDING NETWORK APK"
echo "============================================================"
echo ""

# ------------------------------------------------------------
# 1. CHECK REQUIREMENTS
# ------------------------------------------------------------
echo "[1/7] Checking requirements..."

REQUIRED_COMMANDS=("java" "mvn" "flutter" "nginx" "curl" "nc")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: '$cmd' is not installed."
        exit 1
    fi
done
echo "  Requirements OK ✓"
echo ""


# ------------------------------------------------------------
# 2. STOP OLD PROCESSES
# ------------------------------------------------------------
echo "[2/7] Stopping old processes..."

if lsof -ti :8080 >/dev/null 2>&1; then
    echo "  Stopping process on port 8080..."
    kill $(lsof -ti :8080) 2>/dev/null || true
    sleep 2
    if lsof -ti :8080 >/dev/null 2>&1; then
        kill -9 $(lsof -ti :8080) 2>/dev/null || true
    fi
fi

pkill -x ngrok 2>/dev/null || true

echo "  Old processes stopped ✓"
echo ""


# ------------------------------------------------------------
# 3. BUILD LATEST FLUTTER WEB (for browser access at local IP)
# ------------------------------------------------------------
echo "[3/7] Building latest Flutter web app..."

cd "$FRONTEND_DIR"
flutter pub get
flutter clean

echo "  Building Flutter Web..."
flutter build web --release

if [ ! -d "$FRONTEND_DIR/build/web" ]; then
    echo "ERROR: Flutter web build failed."
    exit 1
fi

echo "  Deploying web to Nginx..."
sudo mkdir -p "$WEB_ROOT"
sudo rm -rf "$WEB_ROOT"/*
sudo cp -r "$FRONTEND_DIR/build/web/"* "$WEB_ROOT/"

echo "  Web build deployed ✓"
echo ""


# ------------------------------------------------------------
# 4. START BACKEND
# ------------------------------------------------------------
echo "[4/7] Starting backend on :8080..."

cd "$BACKEND_DIR"

if [ -x "./mvnw" ]; then
    nohup ./mvnw spring-boot:run > "$BACKEND_LOG" 2>&1 &
else
    nohup mvn spring-boot:run > "$BACKEND_LOG" 2>&1 &
fi

BACKEND_PID=$!
echo "  Backend PID: $BACKEND_PID"
echo "  Waiting for backend..."

BACKEND_READY=false
for i in {1..60}; do
    if nc -z localhost 8080 >/dev/null 2>&1; then
        BACKEND_READY=true; break
    fi
    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
        echo ""
        echo "ERROR: Backend stopped unexpectedly."
        echo "Last log:"
        tail -30 "$BACKEND_LOG"
        exit 1
    fi
    sleep 2; echo -n "."
done
echo ""

if [ "$BACKEND_READY" = false ]; then
    echo "ERROR: Backend did not start within 120 seconds."
    tail -30 "$BACKEND_LOG"
    exit 1
fi

echo "  Backend ready ✓"
echo ""


# ------------------------------------------------------------
# 5. START NGINX
# ------------------------------------------------------------
echo "[5/7] Starting Nginx..."

sudo nginx -t
sudo systemctl enable nginx >/dev/null 2>&1 || true
sudo systemctl start nginx
sudo systemctl reload nginx 2>/dev/null || true

echo "  Nginx ready ✓"
echo ""


# ------------------------------------------------------------
# 6. START NGROK (optional) + DETERMINE BASE URL
# ------------------------------------------------------------
echo "[6/7] Determining network URL..."

LOCAL_IP=$(hostname -I | awk '{print $1}')
BASE_URL="http://$LOCAL_IP"   # fallback: local WiFi

if command -v ngrok >/dev/null 2>&1; then

    echo "  Starting ngrok..."
    nohup ngrok http 80 > "$NGROK_LOG" 2>&1 &

    NGROK_URL=""
    for i in {1..15}; do
        sleep 1
        NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null \
            | grep -o '"public_url":"https://[^"]*"' \
            | head -1 \
            | cut -d'"' -f4)
        if [ -n "$NGROK_URL" ]; then break; fi
    done

    if [ -n "$NGROK_URL" ]; then
        BASE_URL="$NGROK_URL"
        echo "  Ngrok ready ✓  →  $NGROK_URL"
        echo "  (APK will work from ANY network)"
    else
        echo "  WARNING: ngrok started but URL not detected. Using local IP."
        echo "  (APK will only work on the same WiFi)"
    fi

else
    echo "  ngrok not installed — using local IP: $LOCAL_IP"
    echo "  (APK will only work on the same WiFi)"
fi

echo ""


# ------------------------------------------------------------
# 7. BUILD NETWORK APK
# ------------------------------------------------------------
echo "[7/7] Building APK with BASE_URL=$BASE_URL ..."

cd "$FRONTEND_DIR"

# Web build already ran flutter clean — APK build continues from warm state
flutter build apk --debug \
    --dart-define=BASE_URL="$BASE_URL"

APK_SRC="$FRONTEND_DIR/build/app/outputs/flutter-apk/app-debug.apk"

if [ ! -f "$APK_SRC" ]; then
    echo "ERROR: APK build failed."
    exit 1
fi

echo "  APK build complete ✓"

# Place APK in web root so phone can download it directly
sudo cp "$APK_SRC" "$WEB_ROOT/$APK_NAME"

DOWNLOAD_URL="$BASE_URL/$APK_NAME"

echo ""
echo "============================================================"
echo "                 NETWORK APK READY"
echo "============================================================"
echo ""
echo "  [BROWSER] Open in phone's browser (same WiFi):"
echo "    http://$LOCAL_IP"
echo ""
echo "  [APK] Download and install on phone:"
echo "    $DOWNLOAD_URL"
echo ""
echo "  !! IMPORTANT: Every time you re-run this script,   !!"
echo "  !! re-download and reinstall the APK on the phone. !!"
echo ""
echo "------------------------------------------------------------"
echo "  Backend:  http://localhost:8080"
echo "  Web:      Nginx :80  (latest build deployed)"
if [ -n "$NGROK_URL" ]; then
echo "  Public:   $NGROK_URL"
fi
echo "------------------------------------------------------------"
echo ""
echo "  LOGS:  tail -f $BACKEND_LOG"
echo "  STOP:  ./stop-apk.sh"
echo ""
echo "============================================================"
echo ""
