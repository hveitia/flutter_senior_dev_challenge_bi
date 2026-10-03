#!/usr/bin/env bash
# One-time local setup: activates the versioned git hooks and resolves
# dependencies for the whole workspace.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

git config core.hooksPath .githooks
echo "Git hooks enabled from .githooks/"

flutter pub get
echo "Workspace ready."
