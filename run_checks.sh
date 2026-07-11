#!/usr/bin/env bash
# FYTR9 check runner: full test suite + headless boot smoke test (plan §0.6, §12).
set -euo pipefail
cd "$(dirname "$0")"

GODOT_BIN="${GODOT_BIN:-godot}"

echo "== engine =="
"$GODOT_BIN" --version

echo
echo "== import (refresh caches) =="
"$GODOT_BIN" --headless --path project --import >/dev/null 2>&1 || {
	echo "import: FAILED"
	exit 1
}
echo "import: OK"

echo
echo "== test suite =="
test_output="$("$GODOT_BIN" --headless --path project --script res://tests/test_runner.gd 2>&1)" || {
	echo "$test_output"
	exit 1
}
echo "$test_output"
if grep -q "SCRIPT ERROR" <<<"$test_output"; then
	echo "test suite: FAILED (script errors during tests — see above)"
	exit 1
fi
# Positive completion: a run that ends without exactly one PASS summary with
# nonzero counts did not finish normally, whatever its exit code said.
if [[ "$(grep -c '^PASS: ' <<<"$test_output")" -ne 1 ]]; then
	echo "test suite: FAILED (no single PASS summary — run did not complete normally)"
	exit 1
fi
if grep -q "^PASS: 0 suites\|, 0 checks," <<<"$test_output"; then
	echo "test suite: FAILED (PASS with zero suites/checks — discovery broken)"
	exit 1
fi

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
if ! grep -q "Godot Engine" <<<"$boot_output"; then
	echo "boot smoke: FAILED (no engine banner — boot did not actually run)"
	exit 1
fi
echo "boot smoke: OK"

echo
echo "ALL CHECKS PASSED"
