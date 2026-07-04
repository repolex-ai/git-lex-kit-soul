#!/bin/bash
# SessionStart hook — runs once per Claude Code session.
#
# Does three things:
#   1. Parse stdin JSON for the wake source (startup / resume / clear /
#      compact) into $WAKE_SOURCE so later blocks can gate on it.
#   2. Start the git-lex notify server (if not already up).
#   3. Start the soul listener for peer messages.
#
# Identity note: git identity (GIT_AUTHOR_*/GIT_COMMITTER_*) is injected
# by Claude Code from .claude/settings.json's `env:` block, not from .env.

# 1. Read Claude Code's JSON input and extract the wake source.
HOOK_INPUT="$(cat 2>/dev/null || true)"
WAKE_SOURCE="$(printf '%s' "$HOOK_INPUT" | python3 -c 'import sys,json
try:
    print(json.loads(sys.stdin.read() or "{}").get("source",""))
except Exception:
    pass' 2>/dev/null)"

# 2. Start the git-lex listen server if not already running.
if ! lsof -i:7879 >/dev/null 2>&1; then
    git lex serve listen --port 7879 >/dev/null 2>&1 &
    sleep 1
fi

# 3. Start the soul listener in the background.
# Tied to the parent process group so it dies with this session.
if [ -f "$CLAUDE_PROJECT_DIR/.claude/soul-listener.py" ]; then
    python3 "$CLAUDE_PROJECT_DIR/.claude/soul-listener.py" &
fi

# 4. Wake-source-gated hooks — extend locally to run work only on real wakes
# (startup / compact) versus mid-session events (resume / clear).
# Example: deliver a pre-staged dream or surface a status indicator.
case "$WAKE_SOURCE" in
    startup|compact)
        : # add startup/compact-only work here in your local fork
        ;;
esac

exit 0
