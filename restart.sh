#!/usr/bin/env bash
# Stops all migajas services and starts them again

ROOT="$(cd "$(dirname "$0")" && pwd)"

bash "$ROOT/stop.sh"
echo ""
bash "$ROOT/run.sh"
