#!/bin/bash
echo "Stopping backend  (:8080) ..."
kill $(lsof -ti :8080) 2>/dev/null && echo "  stopped" || echo "  not running"

echo "Stopping frontend (:3000) ..."
kill $(lsof -ti :3000) 2>/dev/null && echo "  stopped" || echo "  not running"
