#!/usr/bin/env bash
# FYTR9 check runner: full test suite + headless boot smoke test (plan §0.6, §12).
set -euo pipefail
cd "$(dirname "$0")"

GODOT_BIN="${GODOT_BIN:-godot}"

echo "== engine =="
"$GODOT_BIN" --version

echo
echo "== test suite =="
"$GODOT_BIN" --headless --path project --script res://tests/test_runner.gd

echo
echo "== boot smoke test =="
boot_output="$("$GODOT_BIN" --headless --path project --quit-after 3 2>&1)" || {
	echo "$boot_output"
	echo "boot smoke: FAILED (nonzero exit)"
	exit 1
}
if [[ -n "$boot_output" ]]; then
	echo "$boot_output"
fi
if grep -qE "SCRIPT ERROR|^ERROR" <<<"$boot_output"; then
	echo "boot smoke: FAILED (errors in boot output)"
	exit 1
fi
echo "boot smoke: OK"

echo
echo "ALL CHECKS PASSED"
