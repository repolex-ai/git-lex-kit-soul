---
type: Query
soul.Query.id: <soul/Query/recent>
soul.Query.title: "What changed lately"
soul.Query.description: "Documents ordered by their last change (updatedDate), newest first."
soul.Query.cue:
  - "Looking up which soul documents were most recently modified"
soul.Query.kitManaged: true
---

# What changed lately

> **Kit-shipped default query — do not edit.**
> Create a new query under `Soul/Query/` if you want a custom variation.

Documents by their last change, newest first. The date is
maintained by git-lex at commit time (updatedDate) — documents
that predate the stamping appear once they are next saved.

```sparql
SELECT ?doc ?date
WHERE { ?doc <https://repolex.ai/ontology/git-lex/updatedDate> ?date }
ORDER BY DESC(?date)
LIMIT 20
```
