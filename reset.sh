#!/usr/bin/env bash
# Resets migajas to factory state:
# - kills the running backend
# - deletes the SQLite database
# - rebuilds and restarts the backend (empty DB, fresh schema)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ROOT="$(cd "$(dirname "$0")" && pwd)"

echo -e "${YELLOW}Stopping backend...${NC}"
pkill -f "migajas-backend" 2>/dev/null
fuser -k 8080/tcp 2>/dev/null
sleep 1

echo -e "${YELLOW}Deleting database...${NC}"
rm -f "$ROOT/backend/migajas.db" "$ROOT/backend/migajas.db-wal" "$ROOT/backend/migajas.db-shm"
echo -e "  Database removed."

echo -e "${YELLOW}Rebuilding backend...${NC}"
cd "$ROOT/backend" && CGO_CFLAGS="-Wno-discarded-qualifiers" go build -o migajas-backend .
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi

echo -e "${YELLOW}Starting backend...${NC}"
./migajas-backend > /tmp/migajas-backend.log 2>&1 &
BACKEND_PID=$!
disown $BACKEND_PID
sleep 2

STATUS=$(curl -s http://localhost:8080/api/setup/status 2>/dev/null)
echo -e "${GREEN}Backend ready. Setup status: ${STATUS}${NC}"
echo -e "${GREEN}Backend PID: $BACKEND_PID (log: /tmp/migajas-backend.log)${NC}"
echo -e "${GREEN}Open http://localhost:5173 and you will be taken to the setup page.${NC}"
