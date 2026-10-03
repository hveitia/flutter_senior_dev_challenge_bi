#!/usr/bin/env bash
# Single definition of "green" for the workspace. Used by the pre-commit hook
# and by CI so both always check exactly the same things.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

fail() {
  echo "verify: $1" >&2
  exit 1
}

# The root pubspec.yaml is the list of what gets tested. Globbing directories
# instead would silently skip a package that has no tests yet.
members=()
in_workspace=false
while IFS= read -r line; do
  case "$line" in
    workspace:*) in_workspace=true ;;
    "  - "*) if $in_workspace; then members+=("${line#  - }"); fi ;;
    *) in_workspace=false ;;
  esac
done < pubspec.yaml

[ "${#members[@]}" -gt 0 ] || fail "no workspace members found in pubspec.yaml"

for dir in "${members[@]}"; do
  [ -d "$dir/test" ] || fail "workspace member $dir has no test/ directory"
done

for dir in apps/* packages/*; do
  [ -f "$dir/pubspec.yaml" ] || continue
  case " ${members[*]} " in
    *" $dir "*) ;;
    *) fail "$dir has a pubspec.yaml but is not a workspace member" ;;
  esac
done

# Only the Dart code of this repository: Node dependencies under firebase/
# bring Dart files of their own.
echo "==> Format"
dart format --output=none --set-exit-if-changed apps packages

echo "==> Analyze"
flutter analyze

echo "==> Test"
for dir in "${members[@]}"; do
  echo "--> $dir"
  (cd "$dir" && flutter test)
done
