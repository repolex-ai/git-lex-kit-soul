# Raw/

Byte-faithful copies of harness session files. **Soul holds the receipts.**

Each shelf under `Raw/` corresponds to one harness:

- `ClaudeCodeSessionLog/` — Claude Code session jsonls (auto-mirrored at `git lex save`)
- `Files/` — non-session raw assets (PDFs, screenshots, etc. — drop here by hand)

## Invariants

- **Byte-faithful** — files in `Raw/` are bit-identical to their source. No frontmatter, no normalization. Raw is evidence; its value depends on being untouched.
- **Additive-only** — the adapter never deletes from `Raw/`. If you need to intentionally remove something (privacy, mistaken commit), do it by hand and know you're breaking the cross-machine safety property for that file.
- **State per-machine** — the session-id → first-seen-date map lives in `~/.local/share/git-lex/raw-mirror-state.json`. Filenames in `Raw/` are stable across machines once set on first-seen.

See `git lex raw backfill` to rescue pre-existing sessions on first run.
