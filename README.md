# example-template

A template for a Bynk example app in the `bynk-lang` org: a small working
service wired to the org's CI, end-to-end checks, deploy and
[canary](https://github.com/bynk-lang/.github/blob/main/canary/README.md), so a
new example starts with all of that and only needs its own code.

Click **Use this template** to start one.

## What you get

```text
bynk.toml                       project manifest (rename the project)
src/example/count.bynk          commons: a pure function, unit-tested
src/example/app.bynk            context: an agent (a Durable Object) behind an HTTP service
tests/example/count.bynk        the unit test
e2e/scenarios.sh                end-to-end scenarios, run against the served app (and recipes for tokens, events, cron, several contexts)
BYNK_VERSION                    the Bynk version every workflow uses; the canary proposes moving it
.github/workflows/
  ci.yml                        format check, type check, tests (bynk-ci)
  e2e.yml                       serves the app with `bynk dev`, runs e2e/scenarios.sh (bynk-dev)
  bynk-canary.yml               re-runs all of it against each new Bynk release, and proposes the move
  deploy.yml                    dry run on pull requests, deploy to Cloudflare on main
.github/dependabot.yml          keeps the actions current
```

The app counts: `POST /counters/:name/hit` adds one and returns the new count,
and `GET /counters/:name` reads it. Replace it with your own.

## Make it yours

1. **Rename.** Change `name` in `bynk.toml`, and the `example` context and
   commons names under `src/` and `tests/`. Keep the layout: contexts and
   commons in `src/`, suites in `tests/`.
2. **Write the app**, then update the unit tests and `e2e/scenarios.sh` to
   match. Assert on what a caller sees: status codes, bodies, and state kept
   between requests. The unit tests cover the pure logic; the scenarios cover
   the wiring.
3. **Check it** before you push:

   ```sh
   bynkc fmt --check . && bynkc check . && bynkc test .
   bynk dev                              # then try it in a browser or with curl
   ```

   To run the scenarios the way CI does, serve the app and run the script with
   `BYNK_DEV_URL` set, or push and let `e2e.yml` do it.
4. **Describe it.** Replace this README: what the app shows off, its routes,
   how to run it, and any limits from Bynk today.

## Enrol in the canary

The canary re-runs a repository's checks against every new Bynk release and
opens a `canary` issue here when one breaks it. To take part:

1. **Set the workflow.** `bynk-canary.yml` is already here. Check `kind`
   (`example`), `source` and `deploy-dry-run` suit your app. It must be on the
   default branch, because `repository_dispatch` runs nothing else.
2. **Register the repository.** Add an entry to
   [`canary/repos.json`](https://github.com/bynk-lang/.github/blob/main/canary/repos.json)
   in `bynk-lang/.github`, in a pull request:

   ```json
   { "repo": "bynk-lang/your-example", "kind": "example", "description": "What it shows off" }
   ```

3. **Install the canary App** on the repository (org settings → GitHub Apps →
   the canary App → Configure → Repository access).

Then dispatch it once by hand and check a run appears in this repository's
Actions tab:

```sh
gh workflow run dispatch-canary.yml -R bynk-lang/.github -f repos=bynk-lang/your-example
```

### Baseline and canary versions

`ci.yml`, `e2e.yml` and `deploy.yml` all read the Bynk version from
[`BYNK_VERSION`](BYNK_VERSION) (`version-file: BYNK_VERSION`), so a red build
on a push or pull request means your change broke something, not that a new
compiler came out. The canary passes each newer release in. When one passes,
it opens a pull request moving `BYNK_VERSION` to it, with its checks run at
that version; merge it to move every workflow at once.

That needs the org's bump App (the `BUMP_APP_ID` and `BUMP_APP_KEY` secrets,
passed with `secrets: inherit` in `bynk-canary.yml`). Outside the org, move
`BYNK_VERSION` by hand.

## Beyond one context

The counter is one context. For an app with several, [`bynk-lang/shop`](https://github.com/bynk-lang/shop)
is the worked example: four contexts over Service Bindings and events, with
authentication and end-to-end scenarios. The recipes at the foot of
[`e2e/scenarios.sh`](e2e/scenarios.sh) are what it needed beyond this template:
per-worker URLs, a warm-up for the first call across a Service Binding, signing
bearer tokens, polling for events, and firing cron.

## Limits to know about

Things Bynk can't do yet that an example will run into, with where they are
tracked:

- **An agent can't call another context.** It faults at runtime
  ([accuser/bynk#1960](https://github.com/accuser/bynk/issues/1960)), so do the
  cross-context calls in a service and keep the agent to its own state.
- **Events and `bynk deploy` don't compose.** A subscriber must consume the
  emitter, so the Service Bindings form a cycle and the deploy is refused
  ([accuser/bynk#1961](https://github.com/accuser/bynk/issues/1961)). If your app
  subscribes across contexts, set `deploy-dry-run: false` in `bynk-canary.yml`
  and make `deploy.yml` manual, with a comment naming the issue.
- **The `system` test tier wires no event fan-out**
  ([accuser/bynk#1959](https://github.com/accuser/bynk/issues/1959)), so test
  event-driven flows in the end-to-end scenarios.
- **A local named like a service collides in tests.** A `let level` beside a
  `service level` makes the generated test file redeclare it (`TS2451`). Pick
  another name in the test.

## Deploy

[`deploy.yml`](.github/workflows/deploy.yml) does an offline dry run on every
pull request, and deploys on every push to `main` once these repository secrets
exist (until then it warns and skips):

| Secret | Value |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | A Cloudflare API token with Workers deploy scope. |
| `CLOUDFLARE_ACCOUNT_ID` | The Cloudflare account ID. |

**When a deploy changes `bynk.deploy.lock`,** as the first one does because it
records what was deployed, bynk-deploy opens a pull request that commits it, through the org's bump App (the workflow mints its token). Merge it: later deploys rely on what it records. Without the App, the workflow uploads the new lock as an artifact named `bynk.deploy.lock` to commit instead.

## License

Licensed under either of [MIT](LICENSE-MIT) or [Apache-2.0](LICENSE-APACHE) at
your option.
