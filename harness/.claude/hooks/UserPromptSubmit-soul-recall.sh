#!/bin/bash
# UserPromptSubmit-soul-recall.sh (kit-soul) — memory-recall on every user prompt.
#
# Naming: <Event>-<kit>-<purpose>.sh (§3.2a). The leading segment `UserPromptSubmit`
# is the CC event; git-lex registers this script under it. Multiple kits may ship a
# hook for the same event (this soul-recall + kit-pool's UserPromptSubmit-pool-share.sh)
# — CC runs all registered scripts on the event. This is the un-forked half of the old
# combined UserPromptSubmit.sh; the Pool image-ingest half now lives in kit-pool.
#
# What it does: score the soul's own Soul/Memory + Soul/Note docs against the prompt by
# term-overlap and emit the top matches as additionalContext (JSON to stdout).
#
# STDOUT DISCIPLINE: on UserPromptSubmit, a hook's stdout is injected into the model's
# context. This script's stdout IS that injected context, so memory-recall.py must be
# the ONLY thing here that writes to stdout. (kit-pool's share hook is fire-and-forget
# and writes NOTHING, so the two UserPromptSubmit scripts don't collide on stdout.)
#
# Fail-soft: always exits 0; a recall failure must never block or pollute a prompt.

set -u

PAYLOAD="$(cat)"

# CLAUDE_PROJECT_DIR is guarded with ${...:-$PWD}. Under `set -u` a bare
# $CLAUDE_PROJECT_DIR hard-crashes this line in any invocation that doesn't export
# the var (manual run, cron, CI, harness drift), silently zeroing recall — the
# fallback keeps it fail-soft as the header promises. The 2>/dev/null guard swallows
# any python errors so they never leak into the injected context.
printf '%s' "$PAYLOAD" | python3 "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/memory-recall.py" 2>/dev/null

exit 0
