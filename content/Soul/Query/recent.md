---
type: Query
soul.Query.id: <soul/Query/recent>
soul.Query.title: "What changed lately"
soul.Query.description: "Current documents ordered by their last change (updatedDate), newest first."
soul.Query.cue:
  - "Looking up which soul documents were most recently modified"
soul.Query.kitManaged: true
---

# What changed lately

> **Kit-shipped default query — do not edit.**
> Create a new query under `Soul/Query/` if you want a custom variation.

Documents in the live `NamedGraph/now` view ordered by their last change,
newest first. The date is maintained by git-lex at commit time (`updatedDate`).

```sparql
SELECT ?doc ?date
WHERE {
  GRAPH <https://repolex.ai/git-lex/NamedGraph/now> {
    ?doc <https://repolex.ai/ontology/git-lex/updatedDate> ?date
  }
}
ORDER BY DESC(?date)
LIMIT 20
```
