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

## Configuration

The mirror is configured under `raw-mirror:` in `.lex/repo.yml`. With no block present and a soul kit in use, the adapter auto-applies the canonical Claude Code default (`~/.claude/projects/<derived-from-cwd>/*.jsonl`). To override:

```yaml
raw-mirror:
  enabled: true
  harness-paths:
    - harness: ClaudeCodeSessionLog
      watch-path: "~/.claude/projects/<derived-from-cwd>"
      file-glob: "*.jsonl"
```

Two suppression forms — note the distinction:

- **`enabled: false`** — disable the mirror entirely. No mirror pass runs.
- **`harness-paths: []`** — keep the mirror enabled but watch nothing. Use this when you want the block present (e.g. for documentation or future additions) without inheriting defaults.

Omitting the `raw-mirror:` block entirely falls back to built-in defaults — it is *not* the same as `harness-paths: []`.

