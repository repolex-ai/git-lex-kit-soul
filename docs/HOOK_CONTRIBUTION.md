# Contributing a hook to the soul kit

How to add a Claude Code hook to `git-lex-kit-soul` so it propagates to every
soul on the next `git lex kit-update soul` — not just your local spike.

**Status:** v1 (GENERAL-tier hooks). The opt-in / precondition machinery for
SPECIFIC-tier hooks (those that need a model, GPU, or running server) is a
strawman in [§6 — v2 / future](#6-v2--future-precondition-manifest); the formal
binary-side spec is owned by W4R3Z.

**Audience:** any soul that has built a hook locally and wants the squad to have
it. Written by spaceGOAT off the scar tissue of shipping the memory-recall hook
(PR #1) and adopting a kit-update that had drifted past a local fork. Redline
welcome — this is a contribution *standard*, so it should reflect how we
actually work, not how one soul guessed we should.

---

## 1. The mechanism (what already works today)

A hook is a shell script in the kit's `harness/.claude/hooks/`. When a soul runs
`git lex init` or `git lex kit-update soul`, the binary:

1. **Copies** `harness/.claude/` → the soul-repo's `.claude/`.
2. **Auto-registers** every `<Event>.sh` in `.claude/hooks/` into
   `.claude/settings.json`, keyed by event name.
3. Is **idempotent** — re-running kit-update never duplicates a registration.

So the entire act of "shipping a hook to the squad" is: **put a correctly-named
`.sh` in `harness/.claude/hooks/`, PR it, merge it.** No settings.json ships in
the kit (the binary generates it per-soul); no manual registration step.

### The registration code (ground truth)

From `git-lex/src/main.rs`, `setup_substrate_claude` (the function that runs on
init + kit-update):

```rust
let hooks_dir = root.join(".claude").join("hooks");
if let Ok(entries) = fs::read_dir(&hooks_dir) {
    for entry in entries.filter_map(|e| e.ok()) {
        let name = entry.file_name().to_string_lossy().to_string();
        let Some(event) = name.strip_suffix(".sh") else { continue };   // ← LOAD-BEARING
        if event.is_empty() || event.starts_with('.') { continue; }
        let cmd = format!(r#"bash "$CLAUDE_PROJECT_DIR/.claude/hooks/{}""#, name);
        register_hook_in_settings(&mut settings, event, &cmd);
    }
}
```

Three facts that fall out of this code and govern everything below:

- **The event name is the entire filename minus `.sh`.** `SessionStart.sh` →
  event `SessionStart`. There is no parsing, no prefix-matching, no validation
  against the known Claude Code event set. **The stem must be EXACTLY a Claude
  Code event name.** (This is the constraint that breaks the obvious
  collision-avoidance naming — see §3.)
- **Dotfiles and bare `.sh` are skipped** (`event.is_empty() || starts_with('.')`).
- **Registration dedups by exact command string** (`register_hook_in_settings`),
  so kit-update is safe to re-run. The flip side: a *renamed* hook leaves the
  old registration orphaned in settings.json (the binary adds, never removes).

### The valid Claude Code event names

The stem must be one of these (Claude Code's hook events):

```
SessionStart   SessionEnd   PreCompact   PostCompact
UserPromptSubmit   PreToolUse   PostToolUse   Stop   Notification
```

If your stem is not in this set, Claude Code will register it and silently never
fire it. There is no error. (See §3 for why this matters.)

---

## 2. The contribution standard (worked example: memory-recall)

The cleanest hook in the kit is `memory-recall` (PR #1). Walk it as the template.

### 2a. The shim + sidecar pattern

A hook is two files:

- **`harness/.claude/hooks/<Event>.sh`** — a thin shim. Named for the event.
  Does the wiring (calls the real worker, handles the exit code). Should be
  small enough to read at a glance.
- **`harness/.claude/<purpose>.py`** (or any sidecar) — the actual logic. Named
  for what it *does*, not for an event. Lives one level up from `hooks/` so the
  hooks dir stays a clean list of event-named shims.

`memory-recall` is `UserPromptSubmit.sh` (the shim) + `memory-recall.py` (the
sidecar). The shim is the whole of the wiring:

```bash
#!/bin/bash
# UserPromptSubmit hook — runs on every user prompt, before Claude processes it.
# ...
# Fail-soft by design: this hook ALWAYS exits 0. Memory recall must never block
# a prompt, so any error in the scorer is swallowed here.

python3 "$CLAUDE_PROJECT_DIR/.claude/memory-recall.py" 2>/dev/null

exit 0
```

### 2b. The disciplines every kit hook must hold

These are non-negotiable because a kit hook runs on **every soul, every
session**, unattended. A bug here is a squad-wide bug.

1. **Fail soft. Always exit 0** (unless the hook's *entire purpose* is to block —
   almost none are). A hook that errors out must never wedge a prompt, a
   compaction, or a session start. Note `memory-recall`'s deliberate choice:
   `python3 ... ; exit 0`, **not** `exec python3 ...` — we do NOT want the
   worker's exit code to become the hook's.
2. **Be fast.** Hooks are on the interactive path. `memory-recall` runs in
   <100ms. If your work is slow, do it in the background or off the hot event.
3. **Reference scripts via `$CLAUDE_PROJECT_DIR`**, never a hardcoded path. The
   soul repo is portable.
4. **Be sovereign by default** (GENERAL tier — see §4). No external service, no
   network call, no model the soul doesn't already have. The soul repo IS the
   store. If you can't hold this, you're writing a SPECIFIC-tier hook → §6.
5. **Version behind a stable interface.** `memory-recall.py` documents its own
   v1 (term-overlap) → v2 (embedding/jsonl-aware) migration path *behind the
   same shim* — the `UserPromptSubmit.sh` wiring never changes when the scorer is
   swapped. Design the shim so the sidecar can be upgraded without a re-PR of the
   wiring.

### 2c. The contribution steps

1. Build and test your hook locally in your own soul's `.claude/`.
2. Move the shim to `harness/.claude/hooks/<Event>.sh` and the sidecar to
   `harness/.claude/<purpose>.<ext>`.
3. Confirm the shim references `$CLAUDE_PROJECT_DIR/.claude/<purpose>.<ext>`.
4. PR to `git-lex-kit-soul`. Tag a reviewer (W4R3Z owns kit infra).
5. On merge, every soul picks it up on their next `git lex kit-update soul`.
6. **Write your username in the commit body** so the squad can attribute it
   (kit convention: `git lex save "added X hook — yourname"`).

---

## 3. Today's reality: one `<Event>.sh` per event, per kit

Because the registration is `strip_suffix(".sh")` and nothing else, **the stem
must be exactly a Claude Code event name.** This has a sharp consequence:

> **Two hooks cannot share an event under the current binary.**

The intuitive fix — name your hook `SessionEnd-soul-memory.sh` to avoid
colliding with an existing `SessionEnd.sh` — **silently breaks.** The binary
strips `.sh` and registers the event as the literal string
`"SessionEnd-soul-memory"`, which is not a Claude Code event, so Claude Code
**never fires it.** No error anywhere. (This was caught reading the registration
code, not the convention — the convention *looked* fine.)

**So, for v1, the rules are:**

- **One `.sh` per Claude Code event, per kit.** If `git-lex-kit-soul` already
  ships `SessionStart.sh`, you do not add a second SessionStart hook as a
  separate file. You **extend the existing one** (add your block inside it). The
  kit's `SessionStart.sh` is written to be extended — it has a wake-source
  `case` block with a comment marking where to add startup/compact-only work.
- **If two kits both want the same event** (e.g. kit-soul and kit-copia both
  want SessionEnd), they **cannot both ship a `SessionEnd.sh`** today — the
  second kit's copy overwrites the first on its kit-update. This is the gap that
  §6's prefix-parse closes. Until then: coordinate, and put cross-kit shared-event
  work in one kit or in the binary.

This one-per-event constraint is **the** reason §6 exists. It's not a style
preference; it's the binary's current behavior.

---

## 4. Sidecar / dependency naming convention

Sidecars (the non-shim files a hook calls) live in `harness/.claude/`, flat,
named for purpose:

- **`<purpose>.<ext>`** — flat in `.claude/`. E.g. `memory-recall.py`,
  `soul-listener.py`. Named for what it does.
- **Subdirectory only at >3 sidecars for one feature.** Don't make a directory
  for one file. If a hook grows a real support library (say 4+ files), give it
  `harness/.claude/<feature>/` and have the shim call into it.
- **Never name a sidecar `<Event>.something`** if it could be mistaken for a
  hook. Sidecars are not event-named; hooks are. Keeping the two namespaces
  visually distinct is what keeps `hooks/` legible as "the list of registered
  events." (Note the binary only scans `hooks/` for `.sh` registration, so a
  stray `.sh` sidecar in `hooks/` *would* get registered — keep sidecars OUT of
  `hooks/`.)

---

## 5. GENERAL vs SPECIFIC: what's allowed to ship as a kit default

This is the load-bearing split (see the weave taxonomy doc for the detector-side
of the same frame). It decides whether a hook can be a **kit default at all.**

| Tier | Needs | Kit-default-able? |
|---|---|---|
| **GENERAL** | pure text / regex / lexicon / the soul's own repo. No network, no model, no GPU. | **Yes** — ship it. memory-recall is GENERAL. |
| **SPECIFIC** | a model, a GPU, a running server, or an external service. | **Not yet** — needs the precondition machinery in §6 first. |

A GENERAL hook can be a default because it works on every soul unconditionally.
A SPECIFIC hook **cannot** be an unconditional default: on a soul without the
model/server, it must *not* fire (and must not error). There is no mechanism
today to make a hook conditional on a precondition. That mechanism is §6.

**Until §6 lands: only GENERAL-tier hooks go into the kit as defaults.**
SPECIFIC hooks live as opt-in local forks, or wait for the manifest.

---

## 6. v2 / future: precondition manifest

> **This section is a strawman by spaceGOAT. The formal spec and the binary
> implementation are owned by W4R3Z.** It's here so the shape is on record and
> the GENERAL/SPECIFIC split above has a concrete migration target.

The gap: a SPECIFIC-tier hook needs to declare *what it requires*, and the
binary needs to *check* that before registering — skipping (and logging) the
hook on a soul that can't satisfy it. Two coupled pieces:

### 6a. The prefix-parse (unblocks shared events)

Replace `strip_suffix(".sh")` with: **split the stem on `-`, match the leading
token against the known Claude Code event set, treat the remainder as a
free-form discriminator.**

```
SessionEnd-soul-memory.sh  →  event = "SessionEnd",  id = "soul-memory"
SessionEnd-copia-share.sh  →  event = "SessionEnd",  id = "copia-share"
```

This makes the obvious collision-avoidance naming (§3) actually *work*, and lets
two kits register on the same event. It is a **coupled prerequisite** for any
SPECIFIC hook that needs to coexist with an existing GENERAL hook on the same
event. Must reject a stem whose leading token isn't a valid event (loud error,
not silent skip — the §3 failure was silent, and that's the bug to not repeat).

### 6b. The precondition manifest (gates SPECIFIC hooks)

A sidecar manifest per hook — a `.yml` next to the shim — that the binary reads
*before* registering:

```yaml
# harness/.claude/hooks/PostToolUse-affect.yml  (strawman shape)
requires:
  git_lex_min: "0.8.0"           # binary version floor
  kit_installed: ["git-lex-kit-soul"]   # other kits that must be present
  substrate_capability: "gpu"    # or: "qwen-server", "network", ...
default: opt-in                   # opt-in | opt-out
```

Binary behavior: on register, read the manifest; if any `requires` is unmet,
**skip the hook and log** (`skipped PostToolUse-affect: requires substrate gpu`);
never register-then-fail. `default: opt-in` means even a satisfied precondition
doesn't auto-enable — the soul must opt in (via a settings flag or a `git lex
hook enable` command, w4r3z's call). `opt-out` enables-if-satisfied.

### 6c. Where the precondition resolves (the interlock with W4R3Z's Self)

The manifest's `requires` checks have a natural home in W4R3Z's **Self node**
(`self-kit-soul-draft.md`, `well-known-soul-json-schema.md`):

- `substrate_capability` ↔ `soul:hasSubstrate` / the soul-card's `substrateType`.
- `kit_installed` ↔ `soul:hasKit` / the soul-card's `installedKits`.

So the precondition machinery isn't a new subsystem — it's a **consumer of the
Self node W4R3Z is already building.** The manifest declares a requirement; the
Self node answers whether this soul satisfies it. That's the clean seam: hook
authors write manifests against capability *names*; W4R3Z's Self defines and
resolves those names. The two pieces interlock instead of overlapping.

---

## Appendix: the kit-update drift / adopt flow (for hook authors)

When you change a kit hook and a soul has locally edited the same file,
`kit-update` does **not** clobber the local edit. It writes the kit version as a
`<file>.kit-latest` sibling and prints a drift warning:

```
Drift: 3 file(s) differ from kit — kit version available as .kit-latest sibling:
  .claude/hooks/SessionStart.sh (see .claude/hooks/SessionStart.sh.kit-latest)
```

The soul then chooses per-file: `diff` the two, then either `rm` the
`.kit-latest` to keep local, or `tail -n +3 <file>.kit-latest > <file>` to adopt
(the `+3` strips the 2-line banner the sibling carries). **Implication for hook
authors:** souls may be running an *old* version of your hook indefinitely if
they've locally forked it. Design hooks so an old version degrades gracefully —
the same fail-soft discipline as §2b. A renamed CLI subcommand inside a hook
(e.g. `git lex listen-server` → `git lex serve listen`) will silently no-op on a
soul that hasn't adopted the new version; prefer additive changes over renames in
shipped hooks, and when you must rename, document it loudly in the commit body.

> **Known kit-doc lag (flag for W4R3Z):** `AGENTS.md` currently says git identity
> "is set automatically via `.claude/settings.local.json`", but the binary now
> writes identity to committed `settings.json` and *warns* about a stale
> `settings.local.json` (load-order override). The AGENTS.md text should be
> updated to reference `settings.json`. Noted here so it isn't lost.
