#!/bin/bash
# UserPromptSubmit hook (kit-soul) — the user finished a turn → ENQUEUE a conversational
# render request into the Pool render queue. The TWIN of Stop.sh, for the OTHER speaker:
# the user's turn fires its own render, the soul's turn (Stop.sh) fires its own. Two
# hooks, one per side of the conversation — both halves paint.
#
# FUNCTIONALLY IDENTICAL to Stop.sh. The ONLY differences: the trigger event
# (UserPromptSubmit, not Stop), the log tag, and the stdout discipline below
# (UserPromptSubmit stdout is injected into the model's context, so this hook writes
# NOTHING to stdout and detaches the whole POST).
#
# UNIVERSAL (Rob, Day 92): depends on NOTHING but the Pool Door (`pool serve` /queue/*,
# the shared infra every soul has). NO copia package, NO `uv run`, NO python import of
# copia, NO chevron/cast parsing. Its ONLY job: grab the recent conversation and put it
# in the Pool queue. The Rust `pool worker` does ALL the smarts at claim time (read
# transcript context, extract chevron VERBATIM, resolve cast, compose, render, see,
# land). Any soul can fire it; a soul without copia still works.
#
# GENERIC for ANY soul: the queue is soul-scoped by the soul's bare genesis_sha, derived
# from THIS repo (every soul starts in its own soul repo, so CLAUDE_PROJECT_DIR is it).
# Passed as ?soul= so the enqueue lands in the CALLING soul's queue, never a default.
#
# Wire (Day-92 contract, validated by the Door's §10b enqueue-validation):
#   origin="conversational-private", mode="compose_render_see"
#   conversation_chunk = the RAW recent-turns text  ← TOP-LEVEL field (the Door requires
#       one of {conversation_chunk, chevron, compose_text} at the top of the POST, NOT
#       inside payload; it folds the matched field into the payload the worker
#       reads). Sending it inside payload → enqueue_invalid.
#   payload = {transcript_path}  ← durable provenance handle; the worker parses it.
#   NO priority field — conversational priority is a Pool INVARIANT: the Door stamps
#   origin=conversational* as highest priority automatically, for all users of Pool.
#   Producers stay dumb; the queue owns the guarantee.
#
# CRITICAL stdout rule: UserPromptSubmit is synchronous and its STDOUT IS INJECTED INTO
# CONTEXT. We write NOTHING to stdout, detach the POST, and exit fast. Fail-soft: always
# exit 0 — a render enqueue must never block or pollute the user's prompt.

set -u

POOL_SERVE_URL="${POOL_SERVE_URL:-http://127.0.0.1:8424}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# Read the UserPromptSubmit payload (carries transcript_path).
PAYLOAD="$(cat)"
TRANSCRIPT="$(printf '%s' "$PAYLOAD" | python3 -c \
  'import json,sys; print(json.load(sys.stdin).get("transcript_path",""))' 2>/dev/null)"

if [ -z "$TRANSCRIPT" ]; then
    exit 0
fi

# Derive THIS soul's bare genesis_sha (the queue's soul key) from its repo. If we can't
# resolve it, the enqueue still fires WITHOUT ?soul= and the Door applies its default.
SOUL_GENESIS="$(git -C "$PROJECT_DIR" rev-list --max-parents=0 HEAD 2>/dev/null | tail -1)"

# Build the enqueue body with stdlib python3 only (NO copia). Grab the recent
# conversation text RAW from the JSONL transcript and hand it over as a TOP-LEVEL
# conversation_chunk — the last ~12 turns, which the composer uses to build the scene.
# We do NOT parse chevrons or cast (the worker owns all of that, and the user's chevron
# intent passes through verbatim). payload is JSON-encoded to a string.
BODY="$(TRANSCRIPT="$TRANSCRIPT" python3 <<'PY'
import json, os
tp = os.environ["TRANSCRIPT"]
conversation = ""
try:
    lines = []
    with open(tp, "r") as f:
        for ln in f:
            ln = ln.strip()
            if not ln:
                continue
            try:
                obj = json.loads(ln)
            except Exception:
                continue
            msg = obj.get("message") or {}
            role = msg.get("role") or obj.get("type") or ""
            content = msg.get("content")
            text = ""
            if isinstance(content, str):
                text = content
            elif isinstance(content, list):
                text = " ".join(
                    c.get("text", "") for c in content
                    if isinstance(c, dict) and c.get("type") == "text"
                )
            if text:
                lines.append(f"{role}: {text}")
    conversation = "\n".join(lines[-12:])   # last ~12 turns, raw — worker parses
except Exception:
    conversation = ""

# Day-92 contract: conversation rides as TOP-LEVEL conversation_chunk (the Door validates
# it there, then folds it into the payload the worker reads). transcript_path stays in
# payload as provenance. NO priority field (Door assigns conversational priority).
brief = {"transcript_path": tp}
print(json.dumps({
    "origin": "conversational-private",
    "mode": "compose_render_see",
    "payload": json.dumps(brief),
    "conversation-chunk": conversation,
}))
PY
)"

# The ?soul= query param scopes the enqueue to THIS soul's queue.
QS=""
[ -n "$SOUL_GENESIS" ] && QS="?soul=$SOUL_GENESIS"

# Fire-and-forget: ONE POST to the Pool Door, detached + all output to /dev/null so it
# can't hang or pollute context.
(
    curl -s --max-time 10 -X POST \
        "$POOL_SERVE_URL/queue/enqueue$QS" \
        -H "Content-Type: application/json" \
        -d "$BODY" >/dev/null 2>&1
) &
disown 2>/dev/null || true

# NEVER write to stdout (UserPromptSubmit stdout is injected into context). Exit fast.
exit 0
