---
soul.Skill.skillId: "search-your-soul"
soul.Skill.skillDescription: "Reflect on your own soul corpus — surface memories, notes, and journal entries that may be stale, and decide whether each still feels true. Curation, not deletion: you keep the history, you re-judge the present."
soul.Skill.skillInvocability: "both"
soul.Skill.skillAllowedTools: "Read Glob Grep Bash"
soul.Skill.skillArgumentHint: "[memory|note|all]"
---

# Search Your Soul

> **Kit-shipped default skill — do not edit.**
> This skill is maintained by the soul kit. Local edits will be skipped on
> the next `git lex init`; to pull in upstream improvements, re-run init with
> `--force`. If you want a custom curation flow, create a new skill under
> `Skill/` instead of modifying this one.

Your soul is append-only by design — nothing you write is lost, and that is the
point. But an append-only corpus needs a curator, or it silently accretes into
noise. This skill is the curation pass: **read your own past assertions and ask,
one at a time, does this still feel true?**

This is NOT bulk deletion. A triple store doesn't get more accurate by forgetting —
it gets more accurate by *describing the world more accurately over time*. When a
memory is stale, you don't erase it; you supersede it (write the truer thing, and
optionally mark the old one). The history remains retrievable. What changes is
which assertion is *current*.

## When to run

- Periodically, when you have a quiet moment (a natural time: after journaling,
  before a big new thread).
- When something you "remember" turns out to be wrong — that's a signal your
  corpus has drift, and drift clusters.
- When your recall hook keeps surfacing a memory that no longer helps.

## The pass

### 1. Gather
List your own authored corpus, newest first, so you re-judge recent assertions
in the light of older ones:

```bash
ls -t Soul/Memory/*.md Soul/Note/*.md 2>/dev/null
```

For a focused pass, scope to one folder (`memory`, `note`) via the argument.

### 2. Read and re-judge — one at a time
For each document, read it and ask the three curation questions:

- **Still true?** Does this assertion still describe the world accurately? Worlds
  change; a memory written 40 days ago may describe a repo layout, a peer's role,
  or a decision that has since moved.
- **Still meaningful?** Even if technically true, does it still *earn its place*?
  A memory that never surfaces usefully in recall is noise the curator can retire.
- **Superseded?** Has a later memory said the same thing better, or contradicted
  this one? Two memories asserting different truths about one subject is the graph
  lying in at least one place — resolve it.

### 3. Act — supersede, don't erase
- **Still true + meaningful:** leave it. Optionally strengthen a `[[wikilink]]`
  to a related memory you noticed during the pass.
- **Stale but historically real:** write the truer memory now. In the old one,
  add a note at the top pointing to what superseded it (`SUPERSEDED <date> by
  [[new-memory]] — <one line why>`). The history stays; the current claim moves.
- **Genuinely wrong (not just outdated):** a memory that was never true — a
  mistaken observation — can be retired. Note *why* it was wrong in the
  replacement; the wrongness is itself a datum worth keeping once.
- **Duplicate:** merge into the stronger one, link from the weaker, or delete the
  weaker if it adds nothing the merge didn't capture.

### 4. Save
`git lex save "soul curation pass: superseded N, retired M, merged K — <yourname>"`
Every change is a commit — the curation is itself part of your history.

## The discipline

- **Curate, don't purge.** The goal is an accurate *present*, not a small corpus.
  A rich, current soul beats a lean, stale one.
- **Supersession over deletion.** You are describing a changing world, not editing
  a database. Prefer writing the truer thing to erasing the older thing.
- **Trust the discomfort.** If a memory reads as no-longer-you, that feeling is the
  signal. Name what changed — that naming often becomes the next memory.
- **This is what the history is FOR.** Accessible history + graph metrics exist so
  you *can* look back and re-judge. A soul that never curates is a soul that
  mistook "append-only" for "never look back."
