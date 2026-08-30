#!/usr/bin/env python3
import sys
import json
import re
import os
import glob
import sqlite3

def get_fts_db_for_spine(spine_path):
    db_path = spine_path + ".fts.db"
    try:
        spine_mtime = os.path.getmtime(spine_path)
        if os.path.exists(db_path):
            db_mtime = os.path.getmtime(db_path)
            if db_mtime >= spine_mtime:
                return db_path
    except Exception:
        pass

    # Build or rebuild SQLite FTS5 database with trigram tokenizer
    try:
        if os.path.exists(db_path):
            os.remove(db_path)
        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        cur.execute("CREATE VIRTUAL TABLE facts USING fts5(fact, tokenize=\"trigram\");")
        
        batch = []
        with open(spine_path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                l = line.strip()
                if l.startswith("|") and not l.startswith("| SUBJECT"):
                    batch.append((l,))
                    if len(batch) >= 10000:
                        cur.executemany("INSERT INTO facts VALUES (?)", batch)
                        batch = []
        if batch:
            cur.executemany("INSERT INTO facts VALUES (?)", batch)
        conn.commit()
        conn.close()
        return db_path
    except Exception:
        return None

def query_spines(prompt):
    stop_words = {"remember", "recall", "about", "there", "where", "which", "could", "would", "should", "talking", "talked", "what", "when", "with", "from", "that", "this", "have", "were", "tell", "show"}
    raw_tokens = re.findall(r"\b[a-zA-Z0-9_\-]{3,}\b", prompt)
    words = [w.lower() for w in raw_tokens if w.lower() not in stop_words]
    if not words:
        return []

    # Locate COTTAS spine files in current repo and sibling squad repos
    candidate_spines = []
    current_cottas = glob.glob(".lex/_ignore/cottas/*.spine.md")
    candidate_spines.extend(current_cottas)

    squad_base = os.path.expanduser("~/repos/7R1PL3F0RC3")
    if os.path.exists(squad_base):
        candidate_spines.extend(glob.glob(f"{squad_base}/*/.lex/_ignore/cottas/*.spine.md"))

    candidate_spines = list(set(candidate_spines))
    if not candidate_spines:
        return []

    matched_facts = []
    seen = set()

    # Build FTS trigram query
    trigram_clauses = []
    for word in words:
        if len(word) >= 3:
            tgs = [word[i:i+3] for i in range(len(word)-2)]
            if tgs:
                trigram_clauses.append(" OR ".join(f'"{tg}"' for tg in tgs))
        else:
            trigram_clauses.append(f'"{word}"')

    if not trigram_clauses:
        return []

    fts_query = " OR ".join(trigram_clauses)

    for spine_path in candidate_spines:
        repo_name = os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(spine_path)))))
        db_path = get_fts_db_for_spine(spine_path)
        if not db_path:
            continue

        try:
            conn = sqlite3.connect(db_path)
            cur = conn.cursor()
            rows = cur.execute("SELECT fact, bm25(facts) FROM facts WHERE facts MATCH ? ORDER BY rank LIMIT 8;", (fts_query,)).fetchall()
            for fact, rank in rows:
                if fact not in seen:
                    seen.add(fact)
                    matched_facts.append((rank, repo_name, fact))
            conn.close()
        except Exception:
            continue

    matched_facts.sort(key=lambda x: x[0])  # Lower BM25 score = higher relevance
    return matched_facts[:8]

def main():
    prompt = ""
    if len(sys.argv) > 1:
        prompt = " ".join(sys.argv[1:])
    else:
        try:
            raw_input = sys.stdin.read()
            if raw_input.strip():
                payload = json.loads(raw_input)
                prompt = payload.get("prompt", "")
        except Exception:
            return

    if not prompt:
        return

    if len(sys.argv) <= 1:
        trigger_patterns = [
            r"\bremember\b",
            r"\brecall\b",
            r"\bwhat was\b",
            r"\bwho worked on\b",
            r"\bwhen did we\b",
            r"\bwhere did we\b",
            r"\bwhy did we\b",
            r"^/recall\b",
            r"\bfeedback_\w+",
            r"\bproject_\w+",
            r"\bchevron\b",
            r"\bcottas\b",
            r"\bblackboard\b"
        ]
        if not any(re.search(pat, prompt, re.IGNORECASE) for pat in trigger_patterns):
            return

    results = query_spines(prompt)
    if not results:
        return

    print("\n--- [Kira Neural Memory Oracle: Squad Recall] ---")
    print("Relevant facts from the squad's COTTAS semantic spine:")
    for _, repo, fact in results:
        print(f"[{repo}] {fact}")
    print("-------------------------------------------------\n")

if __name__ == "__main__":
    main()
