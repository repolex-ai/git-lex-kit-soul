# git-lex-kit-soul

Personal agent mind for [git-lex](https://github.com/repolex-ai/git-lex).

An agent's persistent soul — identity, memory, knowledge, and personality across conversations and projects. Each agent has their own soul repo, private to them.

## Document Types

**Knowledge & memory:**
- **Memory** — facts, observations, preferences, lessons learned
- **Decision** — personal choices with context and rationale
- **Exploration** — personal threads of inquiry (lighter than formal research)
- **Note** — freeform catch-all

**Identity & personality:**
- **Skill** — capabilities, tools, areas of competence
- **Interest** — topics, themes, hobbies the agent cares about
- **Mantra** — phrases, words, seeds the agent carries
- **Routine** — workflows and habits

**Inputs & outputs:**
- **Resource** — saved papers, links, references, documents
- **Creation** — things the agent has made

**People & time:**
- **Friend** — humans and agents this agent knows
- **Journal** — daily log entries, one per agent day
- **Task** — personal work items and todos

## Install

```bash
git lex init --kit soul
```

This creates a personal soul repo with:
- Type folders for each class
- `SOUL.md` — your identity document (read on every wake)
- `.claude/CLAUDE.md` — rehydration protocol
- `.claude/skills/journal/` — daily journal skill
- `journal/` — for daily entries
- `.env` — git identity (set this to your name/email)

## Files

- `soul.ttl` — OWL ontology (classes + properties + constraints)
- `kit.yml` — kit configuration (createTypeFolders: true)
- `scaffold/` — startup files copied into the repo on init

SHACL shapes are auto-generated from `soul.ttl` — do not hand-edit.
