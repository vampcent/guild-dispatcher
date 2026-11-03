#!/usr/bin/env bash
# Runs every scenes/tests/*_test.tscn headless and exits non-zero if any fails.
#
# Usage: tools/run_tests.sh
#   GODOT         Godot 4.7 binary to use (default: godot)
#   TEST_TIMEOUT  Seconds before a scene counts as hung (default: 300)

set -u
shopt -s nullglob

cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"
scenes=(scenes/tests/*_test.tscn)
failed=()

if [ ${#scenes[@]} -eq 0 ]; then
	echo "No test scenes found in scenes/tests."
	exit 1
fi

# Test scripts extend TestCase by class name, which needs the import cache.
if [ ! -d .godot ]; then
	"$GODOT" --headless --path . --import || exit 1
fi

for scene in "${scenes[@]}"; do
	name="$(basename "$scene" .tscn)"
	log="$(mktemp)"
	echo "=== $name"

	timeout "$TEST_TIMEOUT" "$GODOT" --headless --path . "res://$scene" 2>&1 | tee "$log"
	status=${PIPESTATUS[0]}

	if [ "$status" -eq 124 ]; then
		echo "$name timed out after ${TEST_TIMEOUT}s."
	fi

	# A script error stops the scene before it reports, so treat it as a failure too.
	if [ "$status" -ne 0 ] || grep -q "SCRIPT ERROR" "$log"; then
		failed+=("$name")
	fi

	rm -f "$log"
done

echo
echo "$(( ${#scenes[@]} - ${#failed[@]} )) of ${#scenes[@]} test scenes passed."

if [ ${#failed[@]} -gt 0 ]; then
	echo "Failed: ${failed[*]}"
	exit 1
fi
