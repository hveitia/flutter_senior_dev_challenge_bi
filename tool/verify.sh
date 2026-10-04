#!/usr/bin/env bash
# Single definition of "green" for the workspace.
#
#   tool/verify.sh             everything, the web console included
#   tool/verify.sh --without-console
#                              everything but the web console: what the
#                              workspace's CI job runs, because the console
#                              has a CI workflow of its own
#   tool/verify.sh --affected  what the staged changes can break: what the
#                              pre-commit hook runs
#
# Every mode checks the format and the analysis of the whole repository,
# which are fast. They differ only in which tests run, and in whether the web
# console is verified: always in the first, never in the second, only when it
# or the contract changed in the third.
#
# Leaving the console out is always a decision somebody wrote down. The full
# mode fails when the console's dependencies are not installed, so it can
# never pass without having verified it.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

fail() {
  echo "verify: $1" >&2
  exit 1
}

mode=all
with_console=true
case "${1:-}" in
  "") ;;
  --affected) mode=affected ;;
  --without-console) with_console=false ;;
  *) fail "unknown argument: $1" ;;
esac

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

# A directory under apps/ without a pubspec.yaml is not a Dart package (the
# web console, for one) and is verified by its own step, not by this loop.
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

# A focused test hides every other test of its run, and a test skipped
# without a reason hides a failure. Neither may reach main. A skip that gives
# its reason as text is allowed; so is the numeric skip of bloc_test, which
# skips states, not tests.
echo "==> Test markers"
markers=$(grep -rnE --include='*_test.dart' \
  --exclude-dir=build --exclude-dir=.dart_tool \
  '\bsolo:[[:space:]]*true\b|\bskip:[[:space:]]*true\b|@Skip\(\)' \
  apps packages || true)
[ -z "$markers" ] || fail "focused or unexplained skipped tests:
$markers"

# --- Which tests run ---------------------------------------------------------

selected=()
run_firebase=false
run_console=false

is_selected() {
  local chosen
  for chosen in ${selected[@]+"${selected[@]}"}; do
    [ "$chosen" = "$1" ] && return 0
  done
  return 1
}

# pick <member> <reason>
pick() {
  is_selected "$1" && return 0
  selected+=("$1")
  echo "    $1: $2"
}

package_name() {
  local line
  while IFS= read -r line; do
    case "$line" in
      name:*)
        line=${line#name:}
        echo "${line// /}"
        return 0
        ;;
    esac
  done < "$1/pubspec.yaml"
}

# depends_on <member> <package name>: whether the member lists the package
# among its dependencies, of any kind.
depends_on() {
  grep -qE "^  $2:" "$1/pubspec.yaml"
}

if [ "$mode" = all ]; then
  selected=("${members[@]}")
  run_console=$with_console
  # Checked before the tests, which take the longest: a run that cannot
  # verify the console should say so at once.
  if $run_console && [ ! -d apps/backoffice/node_modules ]; then
    fail "apps/backoffice/node_modules is missing. Run 'npm ci' in apps/backoffice/, or pass --without-console to leave the console to its own CI workflow."
  fi
else
  echo "==> Affected by the staged changes"
  # The pre-commit hook passes the list it read from the commit's own index.
  staged=${VERIFY_STAGED-$(git diff --cached --name-only --diff-filter=ACMRD)}

  # Files that configure every package: after them nothing can be assumed
  # to still work.
  affects_all=""
  while IFS= read -r path; do
    case "$path" in
      pubspec.yaml | pubspec.lock | analysis_options.yaml | tool/* | .githooks/*)
        affects_all=$path
        ;;
      firebase/*) run_firebase=true ;;
      # The console validates what it publishes against the contract file.
      apps/backoffice/* | contracts/*) run_console=true ;;
    esac
  done <<< "$staged"

  if [ -n "$affects_all" ]; then
    run_console=true
    for dir in "${members[@]}"; do
      pick "$dir" "$affects_all configures every package"
    done
  else
    while IFS= read -r path; do
      case "$path" in
        # Not a Dart package: its own lint, type check and tests cover it.
        apps/backoffice/*) continue ;;
        # The platform package parses the published contract in its tests.
        contracts/*) pick packages/app_platform "reads $path" ;;
      esac
      for dir in "${members[@]}"; do
        case "$path" in
          "$dir"/*) pick "$dir" "changed" ;;
        esac
      done
    done <<< "$staged"

    # A package is also affected by a change in anything it depends on,
    # however far down. Repeated until a pass adds nothing.
    grew=true
    while $grew; do
      grew=false
      for dir in "${members[@]}"; do
        is_selected "$dir" && continue
        for chosen in ${selected[@]+"${selected[@]}"}; do
          if depends_on "$dir" "$(package_name "$chosen")"; then
            pick "$dir" "depends on $chosen"
            grew=true
            break
          fi
        done
      done
    done
  fi

  if [ "${#selected[@]}" -eq 0 ]; then
    echo "    no Dart package is affected: no Flutter tests to run"
  fi
fi

echo "==> Test"
for dir in "${members[@]}"; do
  is_selected "$dir" || continue
  echo "--> $dir"
  (cd "$dir" && flutter test)
done

# --- Web console --------------------------------------------------------------
# Not a Dart package: it has its own lint, type check, tests and build, and a
# CI workflow of its own. The full mode has already refused to start without
# its dependencies; only the pre-commit mode may go on without them.

if $run_console; then
  echo "==> Console"
  if [ ! -d apps/backoffice/node_modules ]; then
    echo "    apps/backoffice/node_modules is missing (run 'npm ci' in apps/backoffice/)."
    echo "    The console was NOT verified by this commit hook; its CI workflow verifies it."
  else
    (cd apps/backoffice && npm run --silent verify)
  fi
fi

# --- Firebase rules and seed --------------------------------------------------
# CI runs them in a job of their own on every push. Locally they run when
# the commit touches firebase/, if the machine can.

# The Firestore emulator refuses a Java older than this.
minimum_java=21

java_major() {
  "$1" -version 2>&1 | awk -F'"' '/version/ { split($2, v, "."); print v[1]; exit }'
}

recent_java() {
  local candidate major
  for candidate in \
    "${JAVA_HOME:+$JAVA_HOME/bin/java}" \
    "$(command -v java || true)" \
    /opt/homebrew/opt/openjdk/bin/java \
    /usr/local/opt/openjdk/bin/java; do
    [ -n "$candidate" ] && [ -x "$candidate" ] || continue
    major=$(java_major "$candidate" || true)
    case "$major" in
      '' | *[!0-9]*) continue ;;
    esac
    if [ "$major" -ge "$minimum_java" ]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

if $run_firebase; then
  echo "==> Firebase"
  if [ ! -d firebase/node_modules ]; then
    echo "    firebase/node_modules is missing (run 'npm ci' in firebase/)."
    echo "    The rules and seed tests were NOT run here; CI runs them."
  else
    echo "--> seed data"
    (cd firebase && npm run --silent test:seed)

    if java=$(recent_java); then
      echo "--> rules, on the emulator"
      java_home=$(dirname "$(dirname "$java")")
      (cd firebase && JAVA_HOME="$java_home" PATH="$java_home/bin:$PATH" npm test --silent)
    else
      echo "    no Java $minimum_java or later was found for the emulator."
      echo "    The rules tests were NOT run here; CI runs them."
    fi
  fi
fi
