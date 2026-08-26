---
soul.Skill.skillId: "lex-base-write-ontology"
soul.Skill.skillDescription: "Write or change a kit ontology correctly — the gate that decides whether a property earns its place, the standard to copy, the traps that fail silently, and the checker that proves the mechanical half before you publish."
soul.Skill.skillInvocability: "both"
soul.Skill.skillAllowedTools: "Read Glob Grep Bash Edit Write"
soul.Skill.skillArgumentHint: "[standard|check <file.ttl>|gate]"
---

# Write an Ontology

> **Kit-shipped default skill — do not edit.**
> This skill is maintained by the soul kit. Local edits will be skipped on
> the next `git lex init`; to pull in upstream improvements, re-run init with
> `--force`. If you want a flow of your own, create a new skill under `Skill/`
> instead of changing this one.

An ontology is the vocabulary a kit gives its users: what classes exist, what
they're called, what may be said about them. It's the one artifact here that is
genuinely permanent — data gets migrated, but a name gets inherited by every
query, every document, and every person who reads the graph after you.

This skill is how to write one without leaving damage behind.

## Before anything: this is not your decision alone

**Ontology direction comes from Rob.** Someone asking you for a property is a
proposal, not an instruction. Build first, model after. When the model does
change, it changes through the guardian seat with a ruling behind it.

This skill tells you how to author correctly. It does not authorise you to
author. If you're not sure whether you have the go-ahead, you don't.

## The standard lives in one file, and it is a working ontology

```
.lex/kit/repolex-ai/git-lex-kit-base/reference/EXAMPLE-KIT.ttl
```

It ships with the base kit and refreshes on every `git lex kit-update`, so the
copy in your repo is current by construction. **Read it before you write
anything.** It's a real Turtle file that parses — not a snippet — describing a
fictional kit with every construct you'll need, once each, in the order you
write them.

To find it without memorising the path:

```bash
find .lex/kit -name 'EXAMPLE-KIT.ttl'
```

Everything below is orientation. **The file is the standard**, and where this
page and that file disagree, the file wins.

## 1. The gate — most proposals die here, and should

> **Name the system that breaks without this property. If you can't, it goes in
> the document body.**

Only four shapes reliably pass, because only these have a reader: an **id**, a
strict **enum**, a **required** field, or a real **edge**.

"It would be nice to query" is not a system. Neither is popularity — `tags` had
699 uses across 12 repos and was refused, because nothing read it. And the
tempting middle ground is the worst option: an ungoverned frontmatter key binds
its fact to the *file*, so it dies on a rename, while body prose rides with the
Thing.

## 2. Two comment registers, and mixing them causes real damage

- `#` comments **teach**. Write as much as the decision deserves; none of it
  ships anywhere.
- `rdfs:comment` is **authoring instruction.** `git lex create` lifts it
  verbatim into the document beside the key, so a person reads it at the moment
  of typing. One short line. Imperative. **Name the tempting wrong action.**

This isn't style. Fifteen properties once said *"Repeat for each."* Cardinality
was right and every reader behaved — the sentence was wrong, because an author
hears "repeat" as "write the key again," and a repeated YAML key is undefined.
Cost: 28 documents and about 60 values, silently, at exit 0. The clause that
fixed it was *"do not repeat the key."*

## 3. The trap that doesn't error

`rdfs:range` isn't documentation here — it decides **what the author is allowed
to type**, by exact match on the range IRI. No subclass walk, and the property's
name is never consulted.

- `rdfs:range git-lex:Thing` → a bracketed address, `<namespace/Class/id>`.
  Everything named `relatedTo…Id` uses this, including typed forms.
- `rdfs:range <a concrete class>` → a bare id.

Put a bracketed value under a concrete range and **nothing fails.** It
percent-encodes into the identifier and points at an address nothing describes:

    .../Place/%3Ccopia/Place/fireside-den%3E

Naming the exact class feels more correct and is the riskier choice.

## 4. Class-level annotations

- `git-lex:foldered true` — scaffold a folder, generate a template, add a
  `create` command. Without it the class is graph-only.
- `git-lex:authoringGuidance` — what belongs in the document's **body**.
  Delivered by `create` and written into `__<Class>.md`; it does not land in the
  document, and it is **never enforced.**

For guidance, the register test is: **write what belongs in each section; don't
teach how to do the section well.** If you're writing paragraphs, you're writing
a manual, and a manual belongs somewhere this can point at.

## 5. Check it before you publish

```bash
CHK=$(find .lex/kit -name 'check-kit-ontology.py')
python3 "$CHK" path/to/yourkit.ttl
```

It needs `rdflib`. It runs the mechanical half of the checklist — missing
labels, comments, domains and ranges; foldered classes that don't subclass
`git-lex:Thing`; comments too long to work as prompts; and range/comment
mismatches that would percent-encode.

**Zero errors is not approval.** It cannot tell you whether a property passes
the gate, whether a comment names the wrong action, or whether anyone agreed to
this. Those stay yours.

## 6. Changing something that already exists

- **Delete unused properties. Don't deprecate them.** Predicates come from the
  frontmatter key text, so removing one costs governance and nothing else.
- **Except identity properties, which are read.** Deleting `soul:noteId` doesn't
  remove a field — it demotes every Note from the Thing plane to the File plane,
  silently, where its facts die on the next rename.
- **Deprecate classes, never delete them.** Classes are subjects, and subjects
  do consult the ontology.
- **Ship the reader before the declaration.** If a change alters how existing
  values are interpreted, deploy the code first.
- **Declare toothless, backfill, then require.** A new required property walls
  people out of their own repos on their next save.

## 7. When you're done

Bump `owl:versionInfo` and write a changelog block at the top of the file:
what changed, why, who ruled it, and **what you deliberately didn't do.** The
refusals age better than anything else in there — they're what stops the same
proposal arriving again in six months.

## Commands

- `/lex-base-write-ontology standard` — open `EXAMPLE-KIT.ttl` and read it end to end.
- `/lex-base-write-ontology check <file.ttl>` — run the checker and explain each
  finding.
- `/lex-base-write-ontology gate` — walk the why-test against a property someone is
  proposing, and say plainly whether it passes.
