#!/usr/bin/env bash
# Stop the web app and kiwix-serve started by start.sh.
set -u
cd "$(dirname "$0")"

stop_one() {  # $1 = name, $2 = pidfile
  if [ -f "$2" ] && kill -0 "$(cat "$2")" 2>/dev/null; then
    kill "$(cat "$2")" && echo "$1 stopped (pid $(cat "$2"))"
  else
    echo "$1 not running"
  fi
  rm -f "$2"
}

stop_one "app" run/app.pid
stop_one "kiwix-serve" run/kiwix.pid
