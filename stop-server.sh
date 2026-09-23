#!/bin/bash
echo "Stopping backend (:8080) ..."
kill $(lsof -ti :8080) 2>/dev/null && echo "  stopped" || echo "  not running"

echo "Stopping nginx ..."
sudo systemctl stop nginx 2>/dev/null && echo "  stopped" || echo "  not running"

echo "Stopping ngrok ..."
kill $(lsof -ti :4040) 2>/dev/null && echo "  stopped" || echo "  not running"
