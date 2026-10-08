#!/usr/bin/env bash
# Runs every automated check. Usage:  GODOT=/path/to/godot tools/run_tests.sh
# The touch test needs a window/GL; skip it on machines without a display: SKIP_GUI=1
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
fail=0
OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

run() {
  local name="$1"; shift
  echo "=== $name"
  if ! "$@" 2>&1 | grep -v "^Godot Engine\|^$\|ObjectDB\|cleanup\|resources still\|V-Sync\|gl_manager\|^OpenGL" | tee "$OUT"; then :; fi
  if grep -q "FAIL\|SCRIPT ERROR\|Parse Error" "$OUT"; then fail=1; echo "--> FAILED"; else echo "--> ok"; fi
}

"$GODOT" --headless --path . --import >/dev/null 2>&1   # registers class_names, imports assets
run "compile check (scripts, scenes, shaders)" "$GODOT" --headless --path . --script res://tools/tests/check_project.gd
run "level generator + quantizer"               "$GODOT" --headless --path . --script res://tools/tests/test_generator.gd
run "audio pop (pitch range/throttle/voices)"    "$GODOT" --headless --path . --script res://tools/tests/test_audio.gd
run "CPU benchmark"                              "$GODOT" --headless --path . --script res://tools/tests/bench_canvas.gd
if [ -z "${SKIP_GUI:-}" ]; then
  run "touch + mouse input" "$GODOT" --path . --rendering-driver opengl3 --resolution 540x960 --script res://tools/tests/test_touch.gd
fi
exit $fail
