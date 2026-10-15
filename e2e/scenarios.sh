#!/usr/bin/env bash
# End-to-end scenarios, run by bynk-lang/bynk-dev against the app served with
# `bynk dev`. BYNK_DEV_URL is the app's base URL. A failing command fails the
# run (the script runs under `bash -eo pipefail`).
#
# Replace these with scenarios for your own app. Assert on what a caller sees:
# status codes, bodies, and state carried between requests.
set -euo pipefail

url="${BYNK_DEV_URL:?run this through bynk-lang/bynk-dev}"

# Fetch a URL, print the body, and fail unless the status is the expected one.
expect_status() {
  local want="$1" method="$2" path="$3" body
  body=$(mktemp)
  got=$(curl -sS -X "$method" -o "$body" -w '%{http_code}' "$url$path")
  if [ "$got" != "$want" ]; then
    echo "::error::$method $path: expected $want, got $got: $(cat "$body")"
    exit 1
  fi
  cat "$body"
}

echo "a counter starts at zero"
test "$(expect_status 200 GET /counters/visits)" = 0

echo "each hit counts up, and the count is kept between requests"
test "$(expect_status 201 POST /counters/visits/hit)" = 1
test "$(expect_status 201 POST /counters/visits/hit)" = 2
test "$(expect_status 200 GET /counters/visits)" = 2

echo "counters are independent"
test "$(expect_status 200 GET /counters/other)" = 0

# --- Recipes ----------------------------------------------------------------
# Patterns the larger examples (bynk-lang/shop) needed. Copy what your app does.
#
# Several contexts. `bynk dev` serves each on its own port, in name order, so
# the first is not necessarily the one with the HTTP routes. Use the per-worker
# variable: the worker name upper-cased, with `-` and `.` as `_`, so context
# `shop.orders` is BYNK_DEV_URL_SHOP_ORDERS. And set `ready-path` in e2e.yml to
# a route that crosses a Service Binding: the first call across one fails
# until it has connected. A route behind auth answers 401 before it crosses,
# which counts as ready, so also retry the first authenticated call:
#
#   for _ in $(seq 1 30); do
#     [ "$(curl -s -o /dev/null -w '%{http_code}' "$orders/some/route")" = 200 ] && break
#     sleep 1
#   done
#
# Bearer tokens. A `Bearer` actor verifies an HS256 JWT. Pass the secret to the
# server with `wrangler-args: --var AUTH_JWT_SECRET:...` in e2e.yml, put the
# same value in the job's env, and sign tokens here:
#
#   b64() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
#   token() {   # token <subject> [extra JSON claims, such as ,"admin":true]
#     local h p s
#     h=$(printf '{"alg":"HS256","typ":"JWT"}' | b64)
#     p=$(printf '{"sub":"%s"%s,"exp":4102444800}' "$1" "${2:-}" | b64)
#     s=$(printf '%s.%s' "$h" "$p" | openssl dgst -sha256 -hmac "$AUTH_JWT_SECRET" -binary | b64)
#     printf '%s.%s.%s' "$h" "$p" "$s"
#   }
#   curl -H "Authorization: Bearer $(token alice)" "$url/me"
#
# Events. Delivery is asynchronous, so an assertion that depends on a
# subscriber must poll, with a bound, rather than read on the next line:
#
#   for _ in $(seq 1 20); do
#     [ "$(curl -fsS "$ledger/total")" = 3 ] && break
#     sleep 1
#   done
#   test "$(curl -fsS "$ledger/total")" = 3
#
# Cron. Add `--test-scheduled` to `wrangler-args` and fire a handler by hand:
#   curl "$url/__scheduled?cron=*/5+*+*+*+*"
