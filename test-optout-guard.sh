#!/bin/bash
# test-optout-guard.sh — regression test for the kit-hook opt-out guard (§3.2c of the
# Soul Identity & Kit Convergence spec). Runs the ACTUAL shipped hook scripts against a
# fixture soul dir and asserts a soul can locally disable a kit-managed hook via
# soul.disabledHooks in settings.local.json — and that a broken opt-out never silences a
# hook (fail-soft).
#
# This test reads the real harness/.claude/hooks/*.sh, so a change that breaks the guard
# fails here. Run: `bash test-optout-guard.sh` from the kit repo root. Exit 0 = pass.
#
# It is NOT installed into soul repos (only content/, harness/, www/, scaffold/ install).

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOKS="$HERE/harness/.claude/hooks"
FAIL=0

pass() { printf '  ok   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; FAIL=1; }

# Fresh fixture soul dir per invocation.
TD="$(mktemp -d)"
trap 'rm -rf "$TD"' EXIT
mkdir -p "$TD/.claude/hooks"

# The recall hook is the sharpest test: it writes recall context to STDOUT, so a disable
# must produce EXACTLY empty stdout (a stray byte would pollute the injected prompt).
RECALL="UserPromptSubmit-soul-recall.sh"
cp "$HOOKS/$RECALL" "$TD/.claude/hooks/$RECALL"
# Stand-in memory-recall.py: emits a marker so we can see whether the hook body ran.
cat > "$TD/.claude/memory-recall.py" <<'PY'
import sys
sys.stdin.read()
print("RECALL_RAN")
PY

run() { echo '{"prompt":"hi"}' | CLAUDE_PROJECT_DIR="$TD" bash "$TD/.claude/hooks/$RECALL" 2>/dev/null; }
set_local() { printf '%s' "$1" > "$TD/.claude/settings.local.json"; }
clr_local() { rm -f "$TD/.claude/settings.local.json"; }

echo "opt-out guard regression ($RECALL):"

clr_local
[ "$(run)" = "RECALL_RAN" ] && pass "no settings.local.json → hook runs" \
    || fail "no settings.local.json → hook runs"

set_local '{"env":{}}'
[ "$(run)" = "RECALL_RAN" ] && pass "local file, no disabledHooks → hook runs" \
    || fail "local file, no disabledHooks → hook runs"

set_local '{"soul":{"disabledHooks":["UserPromptSubmit-soul-recall"]}}'
[ -z "$(run)" ] && pass "basename listed → hook no-ops, empty stdout" \
    || fail "basename listed → hook no-ops, empty stdout"

set_local '{"soul":{"disabledHooks":["SomeOtherHook"]}}'
[ "$(run)" = "RECALL_RAN" ] && pass "different hook listed → this hook runs" \
    || fail "different hook listed → this hook runs"

set_local '{"soul":{"disabledHooks":[]}}'
[ "$(run)" = "RECALL_RAN" ] && pass "empty disabled list → hook runs" \
    || fail "empty disabled list → hook runs"

set_local '{ this is not valid json'
[ "$(run)" = "RECALL_RAN" ] && pass "malformed JSON → fail-soft, hook runs" \
    || fail "malformed JSON → fail-soft, hook runs"

# 'disabledHooks' appears as a substring (grep fast-path fires) but is NOT a real
# soul.disabledHooks entry → must still run (guards against a false-positive grep gate).
set_local '{"note":"disabledHooks are neat","soul":{}}'
[ "$(run)" = "RECALL_RAN" ] && pass "key-substring present but no real entry → hook runs" \
    || fail "key-substring present but no real entry → hook runs"

# Every shipped hook must actually carry the guard sentinels (so none is silently
# un-disableable). Catches a new hook added without the guard.
echo "guard presence in every shipped hook:"
for h in "$HOOKS"/*.sh; do
    n="$(basename "$h")"
    if grep -q 'kit-hook opt-out guard (managed' "$h" && grep -q 'end kit-hook opt-out guard' "$h"; then
        pass "$n carries the opt-out guard"
    else
        fail "$n MISSING the opt-out guard"
    fi
done

echo
if [ "$FAIL" -eq 0 ]; then echo "ALL PASS"; else echo "FAILURES ABOVE"; fi
exit "$FAIL"
