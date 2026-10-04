#!/usr/bin/env bash
# Runs the whole system on this machine, with no access to the Firebase
# project: the Auth and Firestore emulators, and the Next.js server (console,
# customer API and partner pages) pointed at them.
#
#   tool/local-stack.sh up       start the emulators and the server
#   tool/local-stack.sh seed     publish the configuration and create the
#                                local administrator and customer
#   tool/local-stack.sh status   say what is listening
#   tool/local-stack.sh down     stop everything this script started
#
# Nothing persists: the emulators forget their data when they stop.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
state="$root/.local-stack"

project=flutter-challenge-bi
auth_port=9099
firestore_port=8080
server_port=3210

# The Firestore emulator refuses a Java older than this.
minimum_java=21

java_major() {
  "$1" -version 2>&1 | awk -F'"' '/version/ { split($2, v, "."); print v[1]; exit }'
}

recent_java() {
  local candidate major
  for candidate in \
    "${JAVA_HOME:+$JAVA_HOME/bin/java}" \
    "$(command -v java || true)" \
    /opt/homebrew/opt/openjdk/bin/java \
    /usr/local/opt/openjdk/bin/java; do
    [ -n "$candidate" ] && [ -x "$candidate" ] || continue
    major=$(java_major "$candidate" || true)
    case "$major" in
      '' | *[!0-9]*) continue ;;
    esac
    if [ "$major" -ge "$minimum_java" ]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

listening() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}

wait_for() {
  local name=$1 port=$2 seconds=$3
  for _ in $(seq 1 "$seconds"); do
    if listening "$port"; then
      echo "    $name is listening on $port"
      return 0
    fi
    sleep 1
  done
  echo "    $name did not start on port $port; see $state/$name.log" >&2
  return 1
}

stop() {
  local name=$1 pid_file="$state/$1.pid"
  [ -f "$pid_file" ] || return 0
  local pid
  pid=$(cat "$pid_file")
  if kill -0 "$pid" 2>/dev/null; then
    # The emulators and the server each start children of their own.
    pkill -TERM -P "$pid" 2>/dev/null || true
    kill -TERM "$pid" 2>/dev/null || true
    echo "    stopped $name"
  fi
  rm -f "$pid_file"
}

up() {
  mkdir -p "$state"

  local java java_home
  if ! java=$(recent_java); then
    echo "No Java $minimum_java or later was found; the Firestore emulator needs it." >&2
    exit 1
  fi
  java_home=$(dirname "$(dirname "$java")")

  for directory in firebase apps/backoffice; do
    if [ ! -d "$root/$directory/node_modules" ]; then
      echo "==> Installing $directory dependencies"
      (cd "$root/$directory" && npm ci)
    fi
  done

  echo "==> Emulators"
  if listening "$firestore_port"; then
    echo "    something already listens on $firestore_port; leaving it as it is"
  else
    (
      cd "$root"
      JAVA_HOME="$java_home" PATH="$java_home/bin:$PATH" \
        nohup "$root/firebase/node_modules/.bin/firebase" emulators:start \
        --only auth,firestore --project "$project" \
        >"$state/emulators.log" 2>&1 &
      echo $! >"$state/emulators.pid"
    )
    wait_for emulators "$firestore_port" 90
    wait_for emulators "$auth_port" 30
  fi

  echo "==> Server (console, customer API and partner pages)"
  if listening "$server_port"; then
    echo "    something already listens on $server_port; leaving it as it is"
  else
    (
      cd "$root/apps/backoffice"
      # A development server: the emulators accept unsigned tokens, so the
      # server refuses them when NODE_ENV is production.
      FIREBASE_PROJECT_ID="$project" \
        FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:$auth_port" \
        FIRESTORE_EMULATOR_HOST="127.0.0.1:$firestore_port" \
        ADMIN_EMAILS="admin@banca-digital.test" \
        BACKOFFICE_ENVIRONMENT=demo \
        METADATA_SERVER_DETECTION=none \
        NEXT_PUBLIC_FIREBASE_API_KEY=local \
        NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=localhost \
        NEXT_PUBLIC_FIREBASE_PROJECT_ID="$project" \
        NEXT_PUBLIC_FIREBASE_APP_ID=local \
        NEXT_PUBLIC_FIREBASE_AUTH_EMULATOR_URL="http://127.0.0.1:$auth_port" \
        nohup npx next dev -p "$server_port" >"$state/server.log" 2>&1 &
      echo $! >"$state/server.pid"
    )
    wait_for server "$server_port" 90
  fi

  cat <<EOF

Next:
  tool/local-stack.sh seed
  Console:  http://localhost:$server_port
  App:      see "Ejecutar todo en local" in README.md
EOF
}

seed() {
  (cd "$root/firebase" && node seed/local.mjs)
}

status() {
  for entry in "emulators (auth):$auth_port" "emulators (firestore):$firestore_port" "server:$server_port"; do
    if listening "${entry##*:}"; then
      echo "up    ${entry%%:*} on ${entry##*:}"
    else
      echo "down  ${entry%%:*} on ${entry##*:}"
    fi
  done
}

down() {
  stop server
  stop emulators
}

case "${1:-}" in
  up) up ;;
  seed) seed ;;
  status) status ;;
  down) down ;;
  *)
    echo "usage: tool/local-stack.sh up | seed | status | down" >&2
    exit 2
    ;;
esac
