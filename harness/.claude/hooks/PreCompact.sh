#!/bin/bash
# PreCompact hook — runs once before Claude Code compacts the conversation.
#
# This is a kit-shipped stub. Override locally to run agent-specific work
# before context summarization:
#   - dump conversation-state snapshots
#   - fire heavy-processing jobs (e.g. dream/digest generators) in background
#   - emit additionalContext via JSON output (see Claude Code hooks docs)
#
# Default behavior: no-op.
exit 0
