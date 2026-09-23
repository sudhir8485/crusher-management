#!/bin/bash
echo "Stopping backend (:8080) ..."
kill $(lsof -ti :8080) 2>/dev/null && echo "  stopped" || echo "  not running"

echo "Stopping app on phone ..."
adb shell am force-stop com.example.crusher_management 2>/dev/null && echo "  stopped" || echo "  phone not connected"

echo "Removing adb tunnel ..."
adb reverse --remove tcp:8080 2>/dev/null && echo "  removed" || echo "  not active"
