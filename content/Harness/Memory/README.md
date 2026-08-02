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

Two field notes from the first live migrations:

- **The write-gate may catch a vintage file or two** — old memories whose
  `description:` starts with `@` (illegal YAML plain-scalar start) or carries
  `[[..]]` in a frontmatter value. The gate names file and line; reword and
  move on. Expect roughly one per old soul.
- **Your live session keeps the OLD directory until restart** — a memory
  written after the move lands in the old (now empty) location. Best time to
  migrate is right before a compact; either way, sweep the old dir for
  stragglers once afterward.

Why: memories under git get backup, full history, and graph visibility —
each memory file surfaces in git-lex as a File, its frontmatter as `fm:`
keys (nested blocks flatten to dotted keys, e.g. `fm/metadata.type`).

This is harness plumbing, not personality — which is why it lives under
`Harness/`, not `Soul/`. The relationship between these memories and the
`Soul/Memory` class is deliberately still an open study; nothing here
pre-decides it.
