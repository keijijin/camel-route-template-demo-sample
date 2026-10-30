#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
command -v curl >/dev/null || { echo "curl required"; exit 1; }
command -v java >/dev/null || { echo "java required"; exit 1; }
for app in a b; do
  test -f "app-$app/target/app-$app-1.0.0.jar" || { echo "Run mvn clean verify first"; exit 1; }
done
TMP="$(mktemp -d)"
PID_A=""
PID_B=""
cleanup() {
  [[ -z "$PID_A" ]] || kill "$PID_A" 2>/dev/null || true
  [[ -z "$PID_B" ]] || kill "$PID_B" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT
java -jar app-a/target/app-a-1.0.0.jar >"$TMP/app-a.log" 2>&1 &
PID_A=$!
java -jar app-b/target/app-b-1.0.0.jar >"$TMP/app-b.log" 2>&1 &
PID_B=$!
wait_for() {
  local port="$1" pid="$2"
  for ((i=0;i<60;i++)); do
    kill -0 "$pid" 2>/dev/null || { echo "Process $pid exited"; return 1; }
    if curl --fail --silent "http://localhost:$port/hello" > /dev/null; then return 0; fi
    sleep 1
  done
  echo "Timeout waiting for port $port"
  return 1
}
wait_for 8081 "$PID_A" || { cat "$TMP/app-a.log"; exit 1; }
wait_for 8082 "$PID_B" || { cat "$TMP/app-b.log"; exit 1; }
A="$(curl --fail --silent http://localhost:8081/hello)"
B="$(curl --fail --silent http://localhost:8082/hello)"
[[ "$A" =~ ^route=APP-A,\ pid=([0-9]+)$ ]] || { echo "Bad app-a response: $A"; exit 1; }
RESPONSE_PID_A="${BASH_REMATCH[1]}"
[[ "$B" =~ ^route=APP-B,\ pid=([0-9]+)$ ]] || { echo "Bad app-b response: $B"; exit 1; }
RESPONSE_PID_B="${BASH_REMATCH[1]}"
[[ "$RESPONSE_PID_A" != "$RESPONSE_PID_B" ]] || { echo "Same JVM PID"; exit 1; }
[[ "$RESPONSE_PID_A" == "$PID_A" && "$RESPONSE_PID_B" == "$PID_B" ]] || { echo "PID mismatch; another process may own a port"; exit 1; }
echo "Independent JVMs confirmed: A=$PID_A B=$PID_B"
kill "$PID_A" 2>/dev/null || true
wait "$PID_A" 2>/dev/null || true
PID_A=""
for ((i=0;i<10;i++)); do
  if curl --fail --silent http://localhost:8082/hello | grep -q "pid=$PID_B"; then
    echo "Isolation confirmed: app-b still responds after app-a stops"
    exit 0
  fi
  sleep 1
done
echo "App-b did not survive app-a shutdown"
exit 1
