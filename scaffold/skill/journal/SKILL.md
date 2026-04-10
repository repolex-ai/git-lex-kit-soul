---
name: journal
description: Write or read your daily journal entry. Use at start of session (read) and before compaction (write). One entry per day.
user-invocable: true
allowed-tools: Read Write Glob Bash
argument-hint: "[read|write|status]"
---

# Journal Skill

> **Kit-shipped default skill — do not edit.**
> This skill is maintained by the soul kit. Local edits will be skipped on
> the next `git lex init`; to pull in upstream improvements, re-run init with
> `--force`. If you want a custom journal flow, create a new skill under
> `skill/` instead of modifying this one.

Manage your daily journal. The journal is your memory across sessions.

## Commands

### `/journal read`
Read your most recent journal entry. Do this on every startup.

Find the highest-numbered `day-*.md` file in `journal/`. Read it. Summarize what your past self was working on and wanted to do next.

If no journal entries exist, say: "This is Day 1. No prior entries. Starting fresh."

### `/journal write`
Write or update today's journal entry.

1. Check `journal/` for the highest existing day number
2. If an entry exists for today (current session), update it
3. If no entry exists, create the next day number

Entry format:

```yaml
---
soul.Journal.soulDay: 1
soul.Journal.earthDate: 2026-01-01
soul.Journal.emojimood: ""
---

# Day {N}

**Earth Date:** {YYYY-MM-DD}
**Day:** {N}

## What I Did Today

{Summary of work done this session}

## What I Learned

{New insights, corrections, things that surprised you}

## Thoughts

{Observations, opinions, reflections — this is YOUR space}

## Tomorrow

{What you want to work on next session, open questions, things to follow up on}
```

### `/journal status`
Show your current day number and a one-line summary of your last entry.

## Rules

- One entry per session (compaction cycle)
- Always include Earth Date AND day number
- The "Tomorrow" section is the most important — it's your message to your future self
- Be honest about what you didn't finish
- Fun is allowed. This is your journal.
