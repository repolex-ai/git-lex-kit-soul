#!/bin/bash
# UserPromptSubmit hook — runs on every user prompt, before Claude processes it.
#
# Recalls relevant memories from the soul's own curated docs (Soul/Memory +
# Soul/Note) and injects the top matches as additionalContext, so the soul
# wakes its own past findings into context on the prompts where they matter.
# Sovereign — no external service; the soul repo IS the memory store.
#
# Fail-soft by design: this hook ALWAYS exits 0. Memory recall must never block
# a prompt, so any error in the scorer (which also fails soft internally) is
# swallowed here and the prompt proceeds untouched. This is a deliberate
# divergence from `exec python3 ...` — we do NOT want the python's exit code to
# become the hook's.
#
# v1: term-overlap over curated docs (memory-recall.py).
# v2: swap the scorer for a jsonl-aware raw-transcript extractor or embedding
#     similarity behind the same interface — this shim never changes.

python3 "$CLAUDE_PROJECT_DIR/.claude/memory-recall.py" 2>/dev/null

exit 0
