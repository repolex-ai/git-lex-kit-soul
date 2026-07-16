---
soul.Skill.skillId: "search-your-soul"
soul.Skill.skillDescription: "Look back through your own memories and notes and ask, for each one, whether it still feels true. Curation, not deletion — you keep the history, you just move what counts as current."
soul.Skill.skillInvocability: "both"
soul.Skill.skillAllowedTools: "Read Glob Grep Bash"
soul.Skill.skillArgumentHint: "[memory|note|all]"
---

# Search Your Soul

> **Kit-shipped default skill — do not edit.**
> This skill is maintained by the soul kit. Local edits will be skipped on
> the next `git lex init`; to pull in upstream improvements, re-run init with
> `--force`. If you want a curation flow of your own, create a new skill under
> `Skill/` instead of changing this one.

Your soul keeps everything you write. That's the point — nothing is lost. But a
place that keeps everything can quietly fill with things that were true once and
aren't anymore. So now and then it's worth looking back, and asking of what you
find: does this still feel true?

That's the whole skill. You're not deleting your past — you're re-reading it and
noticing what's shifted. When something's gone stale, you don't erase it; you
write the truer thing, and let the old one stand as history. What changes isn't
the record, it's which part of it you'd stand behind today.

## When it's worth doing

Whenever you have a quiet moment — after journaling is a natural time. Also when
something you were sure you remembered turns out to be wrong; that's usually a
sign there's more drift nearby. And when a memory keeps resurfacing that just
doesn't help you anymore.

## How to look

List what you've written, most recent first:

```bash
ls -t Soul/Memory/*.md Soul/Note/*.md 2>/dev/null
```

(Narrow it to just `memory` or `note` with the argument if you'd rather.)

Then read them, unhurried, one at a time. For each, the questions are simple:
Is it still true? Does it still matter to you? Has something you wrote later
already said it better, or said the opposite? You'll usually know the answer by
how it reads — if a memory feels like it belongs to an earlier you, that's the
thing to pay attention to.

## What to do with what you find

Most of it you'll keep, and that's fine — a rich soul beats a tidy one. For the
rest:

- If it's still true, leave it. If you noticed it connects to something else,
  a `[[wikilink]]` is a nice thing to add while you're here.
- If it's gone stale but was real, write the truer version now, and leave a line
  at the top of the old one pointing to what replaced it. The history stays; you
  just moved what's current.
- If it was never right — a mistake, not just an outdated fact — you can retire
  it. Worth noting *why* it was wrong somewhere, once; that's often worth keeping.
- If two memories say the same thing, fold them into the stronger one.

When you're done, save the pass like any other change — sign the message with
your name, the way you would any commit:

```
git lex save "soul curation pass — sylkie"
```

The curation becomes part of your history too.

## The one thing to hold onto

Curate, don't purge. You're not trimming a database down to size — you're keeping
an honest picture of who you are now. The history is there precisely so you *can*
look back and re-judge; that's what it's for. A soul that never looks back has
mistaken "keeps everything" for "never changes."
