#!/usr/bin/env bash
# Runs only inside the NEW Gomoku folder. No remote writes by design.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -d .git ]]; then
  echo 'Already a git repo. Refusing to reinitialize.' >&2; exit 1
fi
git init -b main
git add .
git commit -m 'chore: bootstrap independent Gomoku repository and migration framework'
echo 'Local repository initialized. Remote not yet created or pushed.'
echo 'Work must create a PRIVATE Righteous1776/Gomoku repo and push main after safety review.'
