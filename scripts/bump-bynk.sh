#!/usr/bin/env bash
# Move the pinned Bynk version in every workflow at once:
#   ./scripts/bump-bynk.sh 0.331.0
# The version is pinned in ci.yml, e2e.yml and deploy.yml so that a red build on
# a push or pull request means your change broke something, not that a new
# compiler came out. The canary passes newer releases in; when it shows the app
# still works, bump the pins together, in one pull request.
set -euo pipefail

new="${1:?usage: bump-bynk.sh <version>, such as 0.331.0}"
case "$new" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "not an exact version: $new" >&2; exit 2 ;;
esac

cd "$(dirname "$0")/.."
old=$(sed -n 's/^  BYNK_VERSION: \(.*\)$/\1/p' .github/workflows/deploy.yml)
[ -n "$old" ] || { echo "no BYNK_VERSION in .github/workflows/deploy.yml" >&2; exit 1; }

# Only the pins: the canary workflow's example version is prose.
sed -i.bak "s/^  BYNK_VERSION: .*/  BYNK_VERSION: $new/" .github/workflows/deploy.yml
sed -i.bak "s/\(version: \)$old\( *#\)/\1$new\2/" .github/workflows/ci.yml
sed -i.bak "s/'$old'/'$new'/" .github/workflows/e2e.yml
rm -f .github/workflows/*.bak

grep -n "$new" .github/workflows/ci.yml .github/workflows/e2e.yml .github/workflows/deploy.yml
echo "bumped $old -> $new"
