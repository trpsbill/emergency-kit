#!/usr/bin/env bash
# Start kiwix-serve and the web app. Safe to run at boot (cron @reboot or a
# systemd unit — see README). Idempotent: skips anything already running.
set -u
cd "$(dirname "$0")"
mkdir -p run
[ -f .env ] && . ./.env
[ "${1:-}" = "--debug" ] && export KIT_DEBUG=1

KIWIX_PORT="${KIWIX_PORT:-8080}"
APP_PORT="${APP_PORT:-8000}"
KIWIX_BIN="${KIWIX_BIN:-./kiwix/kiwix-tools_linux-x86_64-3.8.1/kiwix-serve}"

is_running() {  # $1 = pidfile
  [ -f "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null
}

if is_running run/kiwix.pid; then
  echo "kiwix-serve already running (pid $(cat run/kiwix.pid))"
else
  setsid nohup "$KIWIX_BIN" --port "$KIWIX_PORT" ./kiwix/zims/*.zim \
    > kiwix-serve.log 2>&1 &
  echo $! > run/kiwix.pid
  echo "kiwix-serve started on :$KIWIX_PORT (pid $!)"
fi

if is_running run/app.pid; then
  echo "app already running (pid $(cat run/app.pid))"
else
  setsid nohup ./venv/bin/uvicorn app:app --host 0.0.0.0 --port "$APP_PORT" \
    > app.log 2>&1 &
  echo $! > run/app.pid
  echo "app started on :$APP_PORT (pid $!)"
fi

sleep 2
curl -sf -o /dev/null "http://localhost:$KIWIX_PORT/" \
  && echo "kiwix-serve OK: http://localhost:$KIWIX_PORT" \
  || echo "WARNING: kiwix-serve not responding on :$KIWIX_PORT (see kiwix-serve.log)"
curl -sf -o /dev/null "http://localhost:$APP_PORT/" \
  && echo "web UI OK:      http://localhost:$APP_PORT" \
  || echo "WARNING: app not responding on :$APP_PORT (see app.log)"
