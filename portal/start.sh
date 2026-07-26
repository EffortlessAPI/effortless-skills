#!/usr/bin/env bash
# start.sh — bring up the Rulebook Portal: one `docker compose up --build`
# builds and runs all three services (db, api, web). Docker is the only
# prerequisite — no host npm install, no host-run Node/Vite processes.
#
# Ctrl-C tears everything down. This portal is read-only and every service is
# an ephemeral projection of effortless-rulebook.json + skills/ + rulespeak/ —
# nothing here is durable state.
set -euo pipefail
cd "$(dirname "$0")"

cleanup() {
  echo; echo "▸ shutting down…"
  docker compose down
}
trap cleanup EXIT INT TERM

echo "▸ building and starting db + api + web (docker compose up --build)…"
echo
echo "  Portal UI  → http://localhost:8080"
echo "  API        → http://localhost:5177"
echo "  Postgres   → localhost:55432 (scratch, tmpfs)"
echo "  Ctrl-C to stop everything."
echo

docker compose up --build
