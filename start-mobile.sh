#!/bin/bash
ROOT="$(cd "$(dirname "$0")" && pwd)"

# Kill anything already on port 8080
kill $(lsof -ti :8080) 2>/dev/null
sleep 1

echo "[1/4] Starting backend on :8080 ..."
cd "$ROOT/backend"
nohup mvn spring-boot:run -q > /tmp/crusher-backend.log 2>&1 &
echo "  Backend PID: $!"

until nc -z localhost 8080 2>/dev/null; do sleep 2; done
echo "  Backend ready ✓"

echo "[2/4] Checking phone connection ..."
if ! adb devices | grep -q "device$"; then
  echo "  ERROR: No phone detected. Connect via USB and enable USB Debugging."
  exit 1
fi
echo "  Phone detected ✓"

echo "[3/4] Building latest APK ..."
cd "$ROOT/frontend"
flutter pub get
flutter clean
flutter build apk --debug --dart-define=BASE_URL=http://localhost:8080
echo "  Build complete ✓"

echo "[4/4] Tunnelling + installing + launching ..."
adb reverse tcp:8080 tcp:8080
APK="$ROOT/frontend/build/app/outputs/flutter-apk/app-debug.apk"
adb install -r "$APK"
adb shell monkey -p com.example.crusher_management -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
echo "  App launched ✓"

echo ""
echo "  Login: admin@dsp.com / admin123"
echo "  Logs:  tail -f /tmp/crusher-backend.log"
