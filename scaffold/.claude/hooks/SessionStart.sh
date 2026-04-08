#!/bin/bash
# SessionStart hook — runs once per Claude Code session.
# 1. Load the agent's git identity from .env so commits attribute correctly.
# 2. Start the git-lex notify server (if not already up) and the soul listener.

# 1. Source .env for git identity / env vars
if [ -f "$CLAUDE_PROJECT_DIR/.env" ]; then
    set -a
    . "$CLAUDE_PROJECT_DIR/.env"
    set +a
fi

# 2. Start the git-lex listen-server if not already running
if ! lsof -i:7879 >/dev/null 2>&1; then
    git lex listen-server --port 7879 >/dev/null 2>&1 &
    sleep 1
fi

# 3. Start the soul listener in the background.
# Tied to the parent process group so it dies with this session.
if [ -f "$CLAUDE_PROJECT_DIR/.claude/soul-listener.py" ]; then
    python3 "$CLAUDE_PROJECT_DIR/.claude/soul-listener.py" &
fi

exit 0
