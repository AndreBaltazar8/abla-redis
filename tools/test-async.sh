#!/usr/bin/env bash
# Runs tests/async_test.ab against temporary redis:7-alpine servers: one
# password-protected (restarted mid-run) and one TLS-only with a throwaway CA.
set -euo pipefail

project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
compiler=${ABLAC:-ablac}
container="abla-redis-async-test-$$"
password='abla-async-secret'
certs=$(mktemp -d)

cleanup() {
    docker rm -f "$container" "$container-tls" >/dev/null 2>&1 || true
    rm -rf "$certs"
}
trap cleanup EXIT

free_port() { python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }

openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=abla test ca' \
    -keyout "$certs/ca.key" -out "$certs/ca.pem" 2>/dev/null
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=other ca' \
    -keyout "$certs/other.key" -out "$certs/other.pem" 2>/dev/null
openssl req -newkey rsa:2048 -nodes -subj '/CN=localhost' \
    -keyout "$certs/server.key" -out "$certs/server.csr" 2>/dev/null
printf 'subjectAltName=DNS:localhost\n' > "$certs/san.ext"
openssl x509 -req -in "$certs/server.csr" -CA "$certs/ca.pem" -CAkey "$certs/ca.key" -CAcreateserial \
    -days 1 -extfile "$certs/san.ext" -out "$certs/server.pem" 2>/dev/null
chmod 644 "$certs"/*

port=$(free_port)
tls_port=$(free_port)
docker run --detach --name "$container" --publish "127.0.0.1:$port:6379" \
    redis:7-alpine redis-server --requirepass "$password" >/dev/null
docker run --rm --detach --name "$container-tls" --publish "127.0.0.1:$tls_port:6380" -v "$certs:/certs:ro" \
    redis:7-alpine redis-server --requirepass "$password" --port 0 --tls-port 6380 \
    --tls-cert-file /certs/server.pem --tls-key-file /certs/server.key --tls-ca-cert-file /certs/ca.pem \
    --tls-auth-clients no >/dev/null
for _ in $(seq 1 50); do
    if docker exec "$container" redis-cli -a "$password" ping 2>/dev/null | grep -q PONG; then break; fi
    sleep 0.1
done
sleep 0.5

mkdir -p "$project_root/build"
"$compiler" build "$project_root/tests/async_test.ab" -o "$project_root/build/async-test" --fast --no-cache
log="$certs/test.log"
REDIS_PORT="$port" REDIS_TLS_PORT="$tls_port" REDIS_PASSWORD="$password" \
    REDIS_CA="$certs/ca.pem" REDIS_OTHER_CA="$certs/other.pem" "$project_root/build/async-test" > "$log" &
tester=$!
for _ in $(seq 1 200); do
    if grep -q RESTART_SIGNAL "$log" 2>/dev/null; then break; fi
    sleep 0.1
done
sleep 2
docker restart --time 0 "$container" >/dev/null
status=0
wait "$tester" || status=$?
if [[ $status -ne 0 ]]; then
    printf 'async test failed with %s\n' "$status" >&2
    exit "$status"
fi
printf '%s\n' 'Redis async pipelining, errors, MULTI/EXEC, auth failure, restart, and TLS passed'
