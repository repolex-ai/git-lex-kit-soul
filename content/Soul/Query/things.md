---
type: Query
soul.Query.id: <soul/Query/things>
soul.Query.title: "Everything in this repo, by class"
soul.Query.description: "Counts every distinct typed thing in the repository — documents, commits, files, facts of every class."
soul.Query.cue:
  - "Checking the overall shape and class counts of this soul repository"
soul.Query.kitManaged: true
---

# Everything in this repo, by class

> **Kit-shipped default query — do not edit.**
> Create a new query under `Soul/Query/` if you want a custom variation.

Counts every distinct typed thing across the repository — documents, commits,
files, facts of every class. A quick shape-of-the-repo check.

```sparql
SELECT ?class (COUNT(DISTINCT ?s) AS ?count)
WHERE { ?s a ?class }
GROUP BY ?class
ORDER BY DESC(?count)
```
