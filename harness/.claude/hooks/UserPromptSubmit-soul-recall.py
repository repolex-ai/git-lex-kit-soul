#!/usr/bin/env python3
import sys
import json
import re
import os
import glob
import difflib

def extract_ngrams(text, n=3):
    text = f"  {text.lower()}  "
    return set(text[i:i+n] for i in range(len(text) - n + 1))

def ngram_similarity(set1, set2):
    if not set1 or not set2:
        return 0.0
    return len(set1 & set2) / len(set1 | set2)

def fuzzy_word_match(query_words, text_lower, query_ngrams):
    score = 0.0
    text_words = set(re.findall(r"\b[a-zA-Z0-9_\-]+\b", text_lower))
    
    for q_word in query_words:
        if q_word in text_lower:
            score += 1.0  # Exact match
        else:
            # Fuzzy match against individual words in text
            close = difflib.get_close_matches(q_word, text_words, n=1, cutoff=0.75)
            if close:
                score += 0.8
            else:
                # Trigram fallback for morphological variants
                q_ng = query_ngrams.get(q_word)
                if q_ng:
                    for t_word in text_words:
                        if len(t_word) >= 3 and abs(len(t_word) - len(q_word)) <= 3:
                            t_ng = extract_ngrams(t_word)
                            sim = ngram_similarity(q_ng, t_ng)
                            if sim >= 0.55:
                                score += sim * 0.75
                                break
    return score

def query_spines(prompt):
    # Extract candidate search keywords
    stop_words = {"remember", "recall", "about", "there", "where", "which", "could", "would", "should", "talking", "talked", "what", "when", "with", "from", "that", "this", "have", "were"}
    raw_tokens = re.findall(r"\b[a-zA-Z0-9_\-]{3,}\b", prompt)
    words = [w.lower() for w in raw_tokens if w.lower() not in stop_words]
    if not words:
        return []

    word_ngrams = {w: extract_ngrams(w) for w in words}

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

    for spine_path in candidate_spines:
        repo_name = os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(spine_path)))))
        try:
            with open(spine_path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line_clean = line.strip()
                    if not line_clean.startswith("|") or line_clean.startswith("| SUBJECT"):
                        continue
                    line_lower = line_clean.lower()
                    
                    score = fuzzy_word_match(words, line_lower, word_ngrams)
                    if score >= 0.75:
                        if line_clean not in seen:
                            seen.add(line_clean)
                            matched_facts.append((score, repo_name, line_clean))
        except Exception:
            continue

    matched_facts.sort(key=lambda x: x[0], reverse=True)
    return matched_facts[:8]

def main():
    prompt = ""
    # Support direct CLI invocation: python3 UserPromptSubmit-soul-recall.py "query"
    if len(sys.argv) > 1:
        prompt = " ".join(sys.argv[1:])
    else:
        # Standard Claude Code hook stdin JSON invocation
        try:
            raw_input = sys.stdin.read()
            if raw_input.strip():
                payload = json.loads(raw_input)
                prompt = payload.get("prompt", "")
        except Exception:
            return

    if not prompt:
        return

    # If called via hook stdin, check trigger intents
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
