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
- Docker/Icy service-name resolution; and
- environment and secret-file configuration.

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
expiry, null replies, and recovery after a server error.

## Scope

This package currently targets the direct Linux TCP backend. TLS, Sentinel,
Cluster redirections, client-side caching, and asynchronous pub/sub loops are
future layers; ordinary commands and RESP3 values are already represented
without constraining those additions.

Licensed under the Mozilla Public License 2.0.
