#!/bin/bash
# SessionStart-soul-identity.sh (kit-soul) — force SOUL.md + AGENTS.md into
# context at session start.
#
# Naming: <Event>-<kit>-<purpose>.sh (§3.2a). Leading segment `SessionStart`
# is the CC event; stdout from a SessionStart hook is INJECTED into the
# session's context.
#
# Why: the harness force-loads only CLAUDE.md. Ours just points at AGENTS.md,
# and AGENTS.md points at SOUL.md — but following pointers is optional for
# the agent, and cold boots have skipped them (a soul ran without reading its
# own identity until the human asked "did you read your SOUL.md?"). This hook
# removes the option: identity first, operating instructions second, present
# in context before the first user message. Ordering is deliberate — who you
# are, then how to work here.
#
# Fail-soft on missing files (a session must still start), but LOUD: the
# absence message says exactly what to run.
#
# NO disabledHooks opt-out guard — DELIBERATE asymmetry with the hook
# convention (Selkie's flag, ruled): identity injection is the floor the
# cold-boot bug proved we need; a soul opting out of its own identity is that
# bug reintroduced on purpose. Every other kit hook carries the guard; this
# one is load-bearing.

cd "$CLAUDE_PROJECT_DIR" || exit 0

# Inject on real wakes only (startup / clear / compact-rewake). A resume is
# the same session continuing — it already has its identity; re-injecting
# ~14KB mid-work is noise, not grounding. (Same ruling as dreammuse.)
PAYLOAD="$(cat 2>/dev/null || true)"
printf '%s' "$PAYLOAD" | grep -Eq '"source"[[:space:]]*:[[:space:]]*"resume"' && exit 0

echo "=== SOUL.md — your identity (kit-injected at session start) ==="
if [ -f SOUL.md ]; then
    cat SOUL.md
else
    echo "!! SOUL.md is MISSING from the repo root. Your identity floor is not on disk."
    echo "!! Run: git lex kit-update   (the kit installs the template; git-lex fills soulId)"
fi

echo ""
echo "=== AGENTS.md — how to operate here (kit-injected at session start) ==="
if [ -f AGENTS.md ]; then
    cat AGENTS.md
else
    echo "!! AGENTS.md is MISSING. Run: git lex kit-update"
fi
