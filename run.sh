#!/usr/bin/env bash
# Starts both backend and frontend dev servers

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo -e "${GREEN}Starting migajas...${NC}"

# Backend
echo -e "${YELLOW}[backend]${NC} Building and starting Go API on :8080"
cd "$ROOT/backend" && CGO_CFLAGS="-Wno-discarded-qualifiers" go build -o migajas-backend .
if [ ${PIPESTATUS[0]} -ne 0 ]; then echo -e "${RED}Backend build failed!${NC}"; exit 1; fi
ADDITIONAL_ALLOWED_ORIGINS="http://localhost,capacitor://localhost" ./migajas-backend > /tmp/migajas-backend.log 2>&1 &
BACKEND_PID=$!
disown $BACKEND_PID

# Frontend
echo -e "${YELLOW}[frontend]${NC} Starting SvelteKit dev server on :5173"
cd "$ROOT/frontend" && npm run dev > /tmp/migajas-frontend.log 2>&1 &
FRONTEND_PID=$!
disown $FRONTEND_PID

echo -e "${GREEN}Both servers running.${NC}"
echo "  Backend:  http://localhost:8080  (log: /tmp/migajas-backend.log)"
echo "  Frontend: http://localhost:5173  (log: /tmp/migajas-frontend.log)"
echo ""
echo -e "To stop: ${YELLOW}kill $BACKEND_PID $FRONTEND_PID${NC}"
echo "$BACKEND_PID $FRONTEND_PID" > "$ROOT/.dev_pids"
