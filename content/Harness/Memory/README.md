# Harness/Memory

Your Claude Code auto-memory lives here — in your soul repo, under git —
instead of the harness default (`~/.claude/projects/<slug>/memory/`).

git-lex points the harness here automatically: it writes
`autoMemoryDirectory` into the managed block of `.claude/settings.json` at
init and kit-update. You never set it by hand, and it self-heals if the repo
moves.

**Migrating an existing soul (one time):** move everything from
`~/.claude/projects/<your-slug>/memory/` into this folder — including
`MEMORY.md` — and commit. That's it; the harness reads and writes here from
then on.

Why: memories under git get backup, full history, and graph visibility —
each memory file surfaces in git-lex as a File, its frontmatter as `fm:`
keys (nested blocks flatten to dotted keys, e.g. `fm/metadata.type`).

This is harness plumbing, not personality — which is why it lives under
`Harness/`, not `Soul/`. The relationship between these memories and the
`Soul/Memory` class is deliberately still an open study; nothing here
pre-decides it.
