#!/usr/bin/env bash
# Single definition of "green" for the workspace. Used by the pre-commit hook
# and by CI so both always check exactly the same things.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

echo "==> Format"
dart format --output=none --set-exit-if-changed .

echo "==> Analyze"
flutter analyze

echo "==> Test"
for dir in apps/mobile packages/*; do
  if [ -d "$dir/test" ]; then
    echo "--> $dir"
    (cd "$dir" && flutter test)
  fi
done
