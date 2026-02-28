#!/usr/bin/env bash
# Stops all QuickNotes services

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo -e "${YELLOW}Stopping migajas...${NC}"

# Stop via saved PIDs if available
if [ -f "$ROOT/.dev_pids" ]; then
    PIDS=$(cat "$ROOT/.dev_pids")
    for PID in $PIDS; do
        if kill "$PID" 2>/dev/null; then
            echo -e "  Stopped PID $PID"
        fi
    done
    rm -f "$ROOT/.dev_pids"
fi

# Kill any remaining processes by name/pattern
pkill -f "migajas-backend" 2>/dev/null && echo -e "  Stopped backend (migajas-backend)" || true
pkill -f "vite.*migajas" 2>/dev/null && echo -e "  Stopped frontend (vite)" || true

echo -e "${GREEN}All services stopped.${NC}"
