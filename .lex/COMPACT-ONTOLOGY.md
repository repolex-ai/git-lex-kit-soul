# git-lex: agent manual

git-lex turns this git repo into a knowledge graph. You write markdown files
with a YAML header; git-lex reads the headers and links, checks them against
the installed kits' ontology, and makes everything queryable with SPARQL.
This file is generated. `git lex --skill` prints it fresh.

## The loop

```bash
git lex list                       # every document class you can create
git lex create <class> <id>        # new document; the id becomes the filename
git lex save "what changed — you"  # validate, extract, commit. Use this, not git commit
git lex query "<sparql>"           # ask your soul's graph, history included
```

Add `--json` to `list`, `create` or `query` for structured output.

## Writing a document

- Start from `git lex create`. It writes the header with the right keys.
- A header key is `<kit>.<Class>.<property>`, for example `soul.Journal.title`.
  Inherited properties use the same form: `soul.Journal.title` is `git-lex:title`.
- A reference to another document is written `<kit/Class/id>` in angle
  brackets, for example `<soul/Journal/day-7>`.
- Several values: one key, a YAML list. Never repeat a key.
- In the body, link with root-relative markdown links: `[text](/Soul/Note/x.md)`.
  Links become `md:linksTo` edges in the graph.
- Only use keys listed in the ontology section below. An undeclared key saves
  with a warning and no query will find it.
- `id`, `createdDate`, `updatedDate` and `substrate` are maintained for you.

## When save refuses

Save prints each blocking file and what is wrong (a missing required field, a
wrong value type, a duplicate id). Fix the file and save again. Nothing is
committed until the whole save passes.

## Querying

- Prefixes for every installed kit are added for you. Do not declare them.
- A document is `?d a <kit>:<Class>`. Its properties are the IRIs in the
  ontology section, for example `git-lex:title`.
- `git lex query <name>` runs a stored query from `.lex/query/<name>.md`.
- `git lex query` answers from your soul's store through gitlexd: current
  documents, files, commits, and the history of every statement ("when did
  this change?"). It is tied to the soul your session started in, and
  starts gitlexd itself if none is running.
- `git lex direct "<sparql>"` builds a view of the working tree in memory
  instead — unsaved edits included, no history, no gitlexd needed.
- What else is in the graph, what addresses look like, and queries that run:
  the "Querying" section after this manual, written for this repo.

## Where things live

- Your documents: the class folders named in the ontology section, plus any
  markdown file in the repo.
- `.lex/` belongs to git-lex. Never edit or delete anything in it by hand.
  `.lex/repo.yml` lists the installed kits; `.lex/ontology/` holds their
  vocabularies; `.lex/query/` is the one place for your own stored queries.
- `git lex kit-update` refreshes kits and repairs generated files.
  `git lex verify` health-checks the graph.

## Querying: what is in the graph

- A document carries ONLY its own class. Nothing is inferred: `?d a git-lex:Thing`
  matches nothing, and neither does a parent class. `?d git-lex:id ?id` matches
  every document of every class.
- Optional properties are often absent on real documents (many have no title).
  Put them in `OPTIONAL { }`, or the documents without them silently drop out.
- Named graphs, all under `https://repolex.ai/git-lex/NamedGraph/`: `now` holds
  your documents and one `git-lex:File` per file; `commits`, `refs`, `repo` and
  `filetree/<sha>` hold git itself (`git2:Commit`, `git2:Signature`, `git2:Blob`,
  `git2:IndexEntry`, `git2:Branch`, `git2:Repository`, `git-lex:Repo`). A query
  sees all of them at once, and the git layer is most of the graph, so an open
  pattern like `?s a ?class` is mostly git. Require `git-lex:id` to keep to
  documents.
- Body links run FILE to FILE: `?fromFile md:linksTo ?toFile`. A document
  points at its file with `git-lex:fileId`; hop through it to get documents.
- Not every file is a document. A markdown file whose header has no `id` (or
  that has no header) is a `git-lex:File` and nothing more, so a `?doc` joined
  through `git-lex:fileId` comes back blank for it.
- `__<Class>.md` in a class folder is the kit's template for that class, not a
  document: a File with no `git-lex:id`.

## The ontology of this repo

Every class and property of the installed kits, in SHACL Compact Syntax.
How to read it:

- `shapeClass soul:Journal { ... }` is one document class. `# extends X` means
  it also takes every property of X. `# files in F/` is where its documents live.
- A property line is `property type [min..max] .` No type means a plain
  string. A class name as the type means a reference to that kind of Thing.
  No brackets means optional and repeatable. `in=[...]` lists the only
  allowed values.
- Header key for `git-lex:title` on `soul:Journal`: `soul.Journal.title`. The
  key always uses the CLASS's prefix and name, then the property's local name.
- In a query, use the property exactly as written here.

Installed: git-lex.

```shaclc
PREFIX git-lex: <https://repolex.ai/ontology/git-lex/>
PREFIX git2: <https://repolex.ai/ontology/git-lex/git2/>
PREFIX md: <https://repolex.ai/ontology/git-lex/md/>
```
