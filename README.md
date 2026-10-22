# Abla Redis

A Redis client written in [Abla](https://github.com/AndreBaltazar8/ablac).
It speaks RESP directly over Abla's bounded TCP transport, with no hiredis,
C wrapper, or sidecar.

## Features

- reusable authenticated connections;
- RESP2 plus common RESP3 value decoding;
- binary-safe command arguments and bulk strings;
- username/password ACL authentication and database selection;
- bounded connection and read timeouts;
- typed simple, bulk, integer, array, map, set, push, null, and error values;
- convenience operations for `GET`, `SET`, `DEL`, `INCR`, `EXPIRE`, and `PING`;
- Docker/Icy service-name resolution;
- environment and secret-file configuration; and
- a nonblocking client for event loops (`src/async.ab`): pipelined commands
  answered in order, hostnames resolved without blocking (`abla/dns/async`),
  verified TLS, AUTH/SELECT on connect, reconnects, and
  timeouts for unanswered or never-sent commands.

## Import

```abla
import github("AndreBaltazar8/abla-redis")
```

For sibling-checkout development:

```abla
import "../../abla-redis/src/redis.ab"
```

## Example

```abla
import github("AndreBaltazar8/abla-redis")

fun main: int {
    val cache = redisClient(redisConfigFromEnvironment())
    val stored = cache.set("greeting", "hello")
    val found = cache.get("greeting")
    cache.close()
    if (!stored.succeeded()) 1
    else if (found.text == "hello") 0
    else 2
}
```

For a service loop that must never block, use the async client:

```abla
import "../../abla-redis/src/async.ab"

fun main: int {
    var cache = redisAsyncClient(redisAsyncOptionsFromEnvironment())
    val id = cache.get("greeting")
    while (cache.pending() > 0) cache.step(50)
    for (reply in cache.takeReplies()) if (reply.id == id) println(reply.value.text)
    cache.close()
    0
}
```

`REDIS_TLS=1` and `REDIS_CA_FILE` configure TLS for it.

`command(["HSET", "user:42", "name", "Andre"])` exposes the full Redis
command surface. Arguments are always encoded as bulk strings, so application
data never becomes protocol syntax.

## Configuration

- `REDIS_HOST` (default `127.0.0.1`)
- `REDIS_PORT` (default `6379`)
- `REDIS_USERNAME` (optional ACL username)
- `REDIS_PASSWORD` or `REDIS_PASSWORD_FILE`
- `REDIS_DATABASE` (default `0`)
- `REDIS_CONNECT_TIMEOUT_MS` (default `3000`)
- `REDIS_READ_TIMEOUT_MS` (default `5000`)

In Icy, expose those values on the application service and point
`REDIS_HOST` at the Redis service name on the shared deployment network. No
localhost port publishing is required between the services.

## Testing

`make check` runs protocol fixtures. `make test` additionally starts a temporary
`redis:7-alpine` container and verifies authentication, reads, writes, counters,
expiry, null replies, and recovery after a server error; for the async client
it also covers pipelining, MULTI/EXEC, a wrong password, a mid-run restart,
a TLS server with a throwaway CA (and a wrong CA refused), and a lookup
against a nameserver that never answers leaving `step(0)` nonblocking.

## Scope

This package currently targets the direct Linux TCP backend. The blocking
client is plain TCP; the async client adds TLS and nonblocking pipelining.
Sentinel, Cluster redirections, client-side caching, and pub/sub are future
layers; ordinary commands and RESP3 values are already represented
without constraining those additions.

Licensed under the Mozilla Public License 2.0.
