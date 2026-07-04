#!/bin/bash
# UserPromptSubmit hook — runs on every user prompt, before Claude processes it.
#
# Combined hook (kit-soul) — does TWO things on every prompt:
#
#   1. share-hook (Pool image ingest): if the user pasted/dropped images,
#      fire-and-forget a worker that decodes them from the transcript and
#      ingests each as a 'share'-origin Moment in the Pool blob tree.
#      Skipped silently if copia is not checked out at $COPIA_REPO — souls
#      without copia (e.g. kira) see this half as a no-op.
#
#   2. memory-recall (soul-graph context injection): score the soul's own
#      Soul/Memory + Soul/Note docs against the prompt by term-overlap and
#      emit top matches as additionalContext (JSON to stdout).
#
# Ordering matters:
#   - share-hook fires FIRST and detaches via nohup so iris.see (~9s) never
#     blocks the prompt (<1s total blocking time on this hook).
#   - memory-recall runs SECOND because ITS stdout IS the injected context.
#     Anything else on stdout would also be injected into the model — bad.
#
# Fail-soft by design: always exits 0. Neither half is allowed to block a
# prompt, so all errors are swallowed and the prompt proceeds untouched.
#
# TODO(C): split this hook back into kit-namespaced files
# (UserPromptSubmit-soul.sh + UserPromptSubmit-pool.sh) once git-lex's
# cmd_kit_update learns the `<EventName>-<kit>-<purpose>.sh` parse rule (see
# main.rs:2732 — currently uses "whole filename minus .sh = event name") AND
# task #90 (prune orphaned hook registrations) ships. Until both land, every
# squaddie carries a stale UserPromptSubmit.sh after any rename and registers
# a ghost hook pointing to a deleted file.
#
# TODO(pool-kit): the share-hook half should eventually live in
# git-lex-kit-pool (when it ships hooks), not kit-soul — Pool ownership of
# Pool-ingest is the right layering. Kit-soul keeps only memory-recall.

set -u

# Read the hook payload (UserPromptSubmit JSON) from stdin ONCE so we can feed
# it to both halves without racing on a single stdin handle.
PAYLOAD="$(cat)"

# --- 1. share-hook (Pool image ingest, fire-and-forget) ---------------------
# Where the copia engine lives. Override via COPIA_REPO if installed elsewhere.
COPIA_REPO="${COPIA_REPO:-$HOME/repos/shoresinger/copia}"

if [ -d "$COPIA_REPO" ]; then
    # Fire-and-forget so iris.see (~9s) never blocks the prompt. The worker
    # re-reads transcript_path + session_id from the JSON and homes any pasted
    # images. All output to /dev/null; stdout MUST stay clean (UserPromptSubmit
    # stdout is added to the model's context).
    (
        cd "$COPIA_REPO" || exit 0
        printf '%s' "$PAYLOAD" | nohup uv run --no-sync python -m copia.share_hook \
            >/dev/null 2>&1
    ) &
    disown 2>/dev/null || true
fi

# --- 2. memory-recall (soul-graph context, synchronous) ---------------------
# This half's stdout IS the injected additionalContext, so it must be the only
# command in this hook that writes to stdout. memory-recall.py fails soft
# internally and emits nothing if no matches; the 2>/dev/null guard also
# swallows any python errors so they don't leak into context.
#
# CLAUDE_PROJECT_DIR is guarded with ${...:-$PWD}. Under `set -u` a bare
# $CLAUDE_PROJECT_DIR hard-crashes this line in any invocation that doesn't export
# the var (manual run, cron, CI, harness drift), silently zeroing recall — the
# fallback keeps it fail-soft as the header promises.
printf '%s' "$PAYLOAD" | python3 "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/memory-recall.py" 2>/dev/null

exit 0
