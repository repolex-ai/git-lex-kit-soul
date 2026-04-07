#!/bin/bash

# 1. Start the git-lex listen-server if not already running
if ! lsof -i:7879 > /dev/null; then
    git lex listen-server --port 7879 > /dev/null 2>&1 &
    sleep 1
fi

# 2. Start the soul listener in the background
# It will die when this session (the agent process) dies because it's tied to this process group
python3 ./.claude/soul-listener.py &
