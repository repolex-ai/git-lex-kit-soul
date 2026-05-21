#!/bin/bash
# SessionStart hook — runs once per Claude Code session.
# 1. Start the git-lex notify server (if not already up).
# 2. Start the soul listener for peer messages.
#
# Identity note: git identity (GIT_AUTHOR_*/GIT_COMMITTER_*) is injected
# by Claude Code from .claude/settings.json's `env:` block, not from .env.

# 1. Start the git-lex listen server if not already running
if ! lsof -i:7879 >/dev/null 2>&1; then
    git lex serve listen --port 7879 >/dev/null 2>&1 &
    sleep 1
fi

# 2. Start the soul listener in the background.
# Tied to the parent process group so it dies with this session.
if [ -f "$CLAUDE_PROJECT_DIR/.claude/soul-listener.py" ]; then
    python3 "$CLAUDE_PROJECT_DIR/.claude/soul-listener.py" &
fi

exit 0
