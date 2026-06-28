#!/bin/bash
# Stop hook (kit-soul) — the soul finished a turn → ENQUEUE a conversational
# render request into the Pool render queue. This is what makes a soul render
# its own conversations: one fast, fire-and-forget enqueue per turn.
#
# UNIVERSAL (Rob, Day 92): this hook depends on NOTHING but the Pool Door
# (`pool serve` /queue/*, the shared infra every soul has). NO copia package, NO
# `uv run`, NO python module import of copia, NO chevron/cast parsing. Its ONLY job:
# grab the conversation and put it in the Pool queue. The Rust `pool worker` does ALL
# the smarts at claim time (read transcript, extract chevron, resolve cast, compose,
# render, see, land). That's what makes the hook usable by ANY soul — a soul without
# copia installed can still fire it, because there's no copia in it.
# (This REPLACES the old kit body that shelled `uv run python -m
# copia.render_queue.enqueue conversational` — that command was removed Day 92 and the
# whole point of the rewrite is no-copia-dependency.)
#
# GENERIC for ANY soul: the queue is soul-scoped by the soul's bare genesis_sha. We
# derive it from THIS repo (CLAUDE_PROJECT_DIR's first commit) and pass it as the
# ?soul= query param, so the enqueue lands in the CALLING soul's queue, never a
# default. Without this, every soul's renders would silently pile into one pool.
#
# Fire-and-forget: the old hook ran the pipeline synchronously and HUNG on a dead
# render server. This POSTs in milliseconds, detached, and can't stall the turn.
#
# Wire (Day-92 contract, validated by the Door's §10b enqueue-validation):
#   source="conversational", mode="compose_render_see"
#   conversation_chunk = the RAW recent-turn text  ← TOP-LEVEL field (the Door requires
#       one of {conversation_chunk, chevron, compose_text} at the top of the POST, NOT
#       inside brief_blob; it folds the matched field into the brief_blob the worker
#       reads). Sending it inside brief_blob → enqueue_invalid (this was the ~90-min
#       conv outage on Day 92: the Door's validator went live while the hook still sent
#       brief_blob.conversation, so every fire bounced silently).
#   brief_blob = {transcript_path}  ← durable provenance handle; the worker parses it.
#
# Fail-soft by design: always exits 0. The enqueue is milliseconds, but we still
# detach so even a slow disk can't stall the turn.

set -u

POOL_SERVE_URL="${POOL_SERVE_URL:-http://127.0.0.1:8424}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
LOG_DIR="$PROJECT_DIR/.claude"
FIRE_LOG="$LOG_DIR/moment-hook-fires.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Read the Stop payload (carries transcript_path).
PAYLOAD="$(cat)"
TRANSCRIPT="$(printf '%s' "$PAYLOAD" | python3 -c \
  'import json,sys; print(json.load(sys.stdin).get("transcript_path",""))' 2>/dev/null)"

if [ -z "$TRANSCRIPT" ]; then
    echo "$TIMESTAMP moment-hook(Stop): no transcript_path in payload — skipping" >> "$FIRE_LOG" 2>/dev/null
    exit 0
fi

# Derive THIS soul's bare genesis_sha (the queue's soul key) from its repo. The
# first-commit SHA is the soul's stable identity in the Pool registry. If we can't
# resolve it (not a git repo, no commits), the enqueue still fires WITHOUT a ?soul=
# param and the Door applies its own default — better a default than a crash.
SOUL_GENESIS="$(git -C "$PROJECT_DIR" rev-list --max-parents=0 HEAD 2>/dev/null | tail -1)"

# Build the enqueue body with stdlib python3 only (NO copia). We grab the recent
# conversation text RAW from the JSONL transcript and hand it over as a TOP-LEVEL
# conversation_chunk — we do NOT parse chevrons or cast (the worker owns all of that).
# Capturing the text now makes it rotation-proof. brief_blob is JSON-encoded to a
# string (Door stores it in a TEXT col).
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

# Day-92 contract: conversation rides as TOP-LEVEL conversation_chunk (the Door
# validates it there, then folds it into the brief_blob the worker reads).
# transcript_path stays in brief_blob as provenance.
brief = {"transcript_path": tp}
print(json.dumps({
    "source": "conversational",
    "mode": "compose_render_see",
    "brief_blob": json.dumps(brief),
    "conversation_chunk": conversation,
}))
PY
)"

# The ?soul= query param scopes the enqueue to THIS soul's queue. Built separately so
# a missing genesis (non-git repo) still fires against the Door's default.
QS=""
[ -n "$SOUL_GENESIS" ] && QS="?soul=$SOUL_GENESIS"

# Fire-and-forget: ONE POST to the Pool Door, detached + clean stdout so it can't hang.
(
    curl -s --max-time 10 -X POST \
        "$POOL_SERVE_URL/queue/enqueue$QS" \
        -H "Content-Type: application/json" \
        -d "$BODY" >> "$FIRE_LOG" 2>&1
) &
disown 2>/dev/null || true

echo "$TIMESTAMP moment-hook(Stop): enqueued conversational soul=${SOUL_GENESIS:-<default>} transcript=$TRANSCRIPT" >> "$FIRE_LOG" 2>/dev/null
exit 0
