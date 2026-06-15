#!/usr/bin/env python3
"""memory-recall.py — graph-native memory retrieval for the UserPromptSubmit hook.

Ships with the soul kit. On every user prompt, this reads the Claude Code
UserPromptSubmit payload (JSON on stdin), scores the soul's own Memory + Note
markdown bodies against the prompt by term-overlap (with confidence + recency
boosts), and emits the top matches as `additionalContext` so they are injected
into the prompt the model sees. The soul recalls its own past findings without
any external store — the soul repo IS the memory.

v1 (this file) is keyword/term-overlap — sovereign, no dependency, runs in
<100ms over the few dozen small curated docs a soul accumulates. It deliberately
recalls ONLY from the soul's curated Soul/Memory + Soul/Note docs, not from the
raw transcript mirror (Raw/ClaudeCodeSessionLog/): raw jsonl is large and noisy
(tool calls, system reminders) and would drown the curated hits. Raw-transcript
recall is a v2 that needs either a jsonl-aware extractor (keep human+assistant
prose, drop tool_use/tool_result/system) or an embedding scorer behind this same
interface — the hook wiring never changes.

Fails soft: any error, empty prompt, or no match -> emit nothing, exit 0. Memory
recall must NEVER block a prompt.

A soul may tune the constants below for its own corpus; if you hand-edit this
file, `git lex kit-update` will preserve your version (laid alongside the new kit
version per the kit drift-handler convention) rather than clobber it.
"""

import json
import os
import re
import sys
from pathlib import Path

# --- tunables ---------------------------------------------------------------
TOP_K = 3                 # max memories injected per prompt
MIN_SCORE = 2.0           # floor: below this, a match isn't worth the tokens
BODY_CHARS = 600          # how much of each recalled memory body to inject
MIN_TERM_LEN = 4          # ignore short/stopword-ish tokens when matching

# Directories to recall from, relative to the project root.
RECALL_DIRS = ["Soul/Memory", "Soul/Note"]

# Cheap stopword guard so common words don't drive the match.
STOP = {
    "this", "that", "with", "from", "have", "what", "when", "which", "would",
    "could", "should", "about", "there", "their", "they", "them", "then",
    "into", "over", "your", "yours", "just", "like", "want", "need", "make",
    "does", "done", "here", "were", "been", "being", "also", "some", "more",
    "much", "very", "than", "thing", "things", "really",
}

_TOKEN = re.compile(r"[a-z0-9][a-z0-9\-]+")


def tokens(text: str) -> set[str]:
    return {
        t for t in _TOKEN.findall(text.lower())
        if len(t) >= MIN_TERM_LEN and t not in STOP
    }


def read_prompt() -> str:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return ""
    return (payload.get("prompt") or "").strip()


def memory_files(root: Path):
    for rel in RECALL_DIRS:
        d = root / rel
        if not d.is_dir():
            continue
        for p in sorted(d.glob("*.md")):
            # skip class templates (__Class.md) and index/readme files
            if p.name.startswith("__") or p.name in ("MEMORY.md", "README.md"):
                continue
            yield p


# very rough recency score from a leading YYYY-MM-DD in the filename.
# NOTE: the year math below uses a 2025 baseline; the boost is only a small
# tie-breaker, but bump the baseline if it ever needs recalibrating (~2028+).
_DATE = re.compile(r"(\d{4})-(\d{2})-(\d{2})")


def recency_boost(name: str) -> float:
    m = _DATE.search(name)
    if not m:
        return 0.0
    y, mo, _ = (int(g) for g in m.groups())
    # newer files get a small nudge; 2026 ~ +0.5, scaled by month
    return max(0.0, (y - 2025) + mo / 24.0) * 0.3


def score_file(p: Path, q: set[str]) -> tuple[float, str, str]:
    """Return (score, title, body_excerpt) for a memory file vs query terms."""
    try:
        text = p.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return (0.0, "", "")

    # split frontmatter from body
    body = text
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            body = text[end + 4:]

    title_match = re.search(r"^#\s+(.+)$", body, re.M)
    title = title_match.group(1).strip() if title_match else p.stem

    ft = tokens(text)
    overlap = q & ft
    if not overlap:
        return (0.0, title, "")

    # base score: overlapping terms, with title hits weighted up
    title_terms = tokens(title)
    score = sum(2.0 if t in title_terms else 1.0 for t in overlap)

    # confidence boost
    if re.search(r"confidence:\s*certain", text):
        score += 1.0
    elif re.search(r"confidence:\s*(likely|certain)", text):
        score += 0.5

    score += recency_boost(p.name)

    # excerpt: title + first substantive body lines (skip the title line itself)
    lines = [
        ln.strip() for ln in body.splitlines()
        if ln.strip() and not ln.startswith("#")
    ]
    excerpt = " ".join(lines)[:BODY_CHARS].strip()
    return (score, title, excerpt)


def main() -> int:
    prompt = read_prompt()
    if not prompt:
        return 0
    q = tokens(prompt)
    if not q:
        return 0

    # Prefer the project root Claude Code passes in; fall back to walking up
    # from this file's install location (.claude/ -> repo root).
    env_root = os.environ.get("CLAUDE_PROJECT_DIR")
    root = Path(env_root) if env_root else Path(__file__).resolve().parents[1]

    scored = []
    for p in memory_files(root):
        s, title, excerpt = score_file(p, q)
        if s >= MIN_SCORE and excerpt:
            scored.append((s, title, excerpt, p))

    if not scored:
        return 0

    scored.sort(key=lambda x: x[0], reverse=True)
    top = scored[:TOP_K]

    parts = [
        "Relevant memories recalled from your own Soul graph "
        "(soul memory-recall hook — these are YOUR past findings, surfaced "
        "because they match this prompt; verify before relying):",
    ]
    for _, title, excerpt, p in top:
        parts.append(f"\n• [[{p.stem}]] — {title}\n  {excerpt}")

    context = "\n".join(parts)
    out = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": context,
        }
    }
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        # memory recall must never block a prompt
        sys.exit(0)
