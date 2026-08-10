#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
compiler=${ABLAC:-$project_root/../ablac/build/ablac}
container="abla-redis-test-$$"
password='abla-test-secret'

cleanup() {
    docker rm -f "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --rm --detach --name "$container" --publish 127.0.0.1::6379 \
    redis:7-alpine redis-server --requirepass "$password" >/dev/null
port=$(docker port "$container" 6379/tcp | awk -F: 'NR == 1 { print $NF }')

ready=false
for _ in $(seq 1 40); do
    if docker exec "$container" redis-cli -a "$password" ping 2>/dev/null |
        grep -q PONG; then
        ready=true
        break
    fi
    sleep 0.1
done
if [[ $ready != true ]]; then
    printf '%s\n' 'Redis test container did not become ready' >&2
    exit 1
fi

mkdir -p "$project_root/build"
"$compiler" build "$project_root/tests/integration_test.ab" \
    -o "$project_root/build/integration-test" --fast --no-cache
"$compiler" build "$project_root/tests/auth_failure_test.ab" \
    -o "$project_root/build/auth-failure-test" --fast --no-cache
REDIS_HOST=127.0.0.1 REDIS_PORT="$port" REDIS_PASSWORD="$password" \
    "$project_root/build/integration-test"
REDIS_HOST=127.0.0.1 REDIS_PORT="$port" REDIS_PASSWORD=definitely-wrong \
    "$project_root/build/auth-failure-test"

printf '%s\n' 'Redis RESP, authentication rejection, persistence, null, and error recovery passed'
