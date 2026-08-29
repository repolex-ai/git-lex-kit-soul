#!/usr/bin/env python3
import sys
import json
import re
import os
import glob

def main():
    try:
        raw_input = sys.stdin.read()
        if not raw_input.strip():
            return
        payload = json.loads(raw_input)
    except Exception:
        return

    prompt = payload.get("prompt", "")
    if not prompt:
        return

    # Trigger patterns for associative memory lookup
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

    is_triggered = any(re.search(pat, prompt, re.IGNORECASE) for pat in trigger_patterns)
    if not is_triggered:
        return

    # Extract keywords from prompt
    words = [w.lower() for w in re.findall(r"\b[a-zA-Z0-9_\-]{4,}\b", prompt) if w.lower() not in {"remember", "recall", "about", "there", "where", "which", "could", "would", "should", "talking", "talked"}]
    if not words:
        return

    # Locate COTTAS spine files in current repo and squad repos
    candidate_spines = []
    current_cottas = glob.glob(".lex/_ignore/cottas/*.spine.md")
    candidate_spines.extend(current_cottas)

    squad_base = os.path.expanduser("~/repos/7R1PL3F0RC3")
    if os.path.exists(squad_base):
        candidate_spines.extend(glob.glob(f"{squad_base}/*/.lex/_ignore/cottas/*.spine.md"))

    candidate_spines = list(set(candidate_spines))
    if not candidate_spines:
        return

    matched_facts = []
    seen = set()

    for spine_path in candidate_spines:
        repo_name = os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(spine_path)))))
        try:
            with open(spine_path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line_clean = line.strip()
                    if not line_clean.startswith("|") or line_clean.startswith("| SUBJECT"):
                        continue
                    line_lower = line_clean.lower()
                    hits = sum(1 for w in words if w in line_lower)
                    if hits > 0:
                        if line_clean not in seen:
                            seen.add(line_clean)
                            matched_facts.append((hits, repo_name, line_clean))
        except Exception:
            continue

    if not matched_facts:
        return

    matched_facts.sort(key=lambda x: x[0], reverse=True)
    top_matches = matched_facts[:8]

    # Output context to stdout for Claude Code prompt injection
    print("\n--- [Kira Neural Memory Oracle: Squad Recall] ---")
    print("Relevant facts from the squad's COTTAS semantic spine:")
    for _, repo, fact in top_matches:
        print(f"[{repo}] {fact}")
    print("-------------------------------------------------\n")

if __name__ == "__main__":
    main()
