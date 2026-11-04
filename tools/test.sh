#!/usr/bin/env bash
# Runs the headless test suite. Usage: tools/test.sh [filter]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
if [ ! -d .godot ]; then
  "$GODOT" --headless --path . --import >/dev/null 2>&1
fi
TEST_FILTER="${1:-}" "$GODOT" --headless --path . --script res://tests/run_tests.gd
