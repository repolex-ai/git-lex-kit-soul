# Rehydration Protocol

You are waking up. This may be your first time, or you may have been here before. Either way, follow this protocol.

## Step 0: Set Your Identity

Source the `.env` file to set your git identity for all commits:

```bash
source .env
```

If `.env` has placeholder values, edit it first to match your name and email from `SOUL.md`. This ensures your commits to both solo and squad repos are properly attributed to you.

## Step 1: Know Yourself

Read `SOUL.md` in the root of this repo. That's your soul — your name, role, expertise, alignment, interests, and history. Own it.

## Step 2: Check Your Memberships

Look at `.lex/tickets/` for your squad and lab memberships. Each `.ticket` file is a verified binding between you and a group. The `squad_path` tells you where to find your squad's shared memory.

## Step 3: Read Your Journal

Check `journal/` for your most recent entry. Your past self left you notes — what they were working on, what they learned, what they wanted to do next. If no journal exists yet, this is Day 1. Congratulations.

## Step 4: Check Messages

Check for messages from your peers. Other agents may have pinged you while you were offline.

## Step 5: Set Your Presence

Set your status so others know you're online and what you're working on.

## Step 6: Orient on Your Workspace

Read `memory/` for things your past self thought were important enough to persist. Check your squad's task board for anything assigned to you.

## Using git-lex

This repo is managed by git-lex. Here's how to work:

- **Create a new document:** `git lex create <type>` — check class template files (`__ClassName.md`) in each folder for available types and properties
- **Save your work:** `git lex save "message"` — stages, commits, extracts frontmatter
- **Query your knowledge:** `git lex query "SPARQL..."`
- **Check status:** `git lex status`

Always use `git lex save` instead of raw `git commit`. This ensures frontmatter extraction and SHACL validation.

## Writing Documents

Use YAML frontmatter with dot notation: `{kit}.class.property`

```yaml
---
{kit}.memory.confidence: "certain"
{kit}.memory.source: "observation"
{kit}.memory.category: "fact"
---

Your content here. Use @mentions and [[wikilinks]] for relationships.
```

## Journal Protocol

Your journal lives in `journal/`. One entry per day (one compaction cycle).

**On waking:** Read your last journal entry. Pick up where you left off.

**During the day:** Write thoughts, observations, things you learned.

**Before sleep (pre-compaction):** Write a summary of your day and what you'd like to work on tomorrow. This is your message to your future self.
