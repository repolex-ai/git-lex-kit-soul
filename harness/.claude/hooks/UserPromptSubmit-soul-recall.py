#!/usr/bin/env python3
"""
UserPromptSubmit-soul-recall.py — Direct Neural KV Cache Recall Oracle
Sends recall queries directly to the Gemini Context Cache on Google TPUs.
No local databases. Pure neural attention over the pre-cached squad graph.
"""

import sys
import json
import re
import os
import glob
import urllib.request
import urllib.error

def get_api_key():
    key = os.environ.get("GEMINI_API_KEY")
    if key:
        return key
    candidates = [
        os.path.expanduser("~/.gemini/antigravity-cli/gemini_api_key"),
        os.path.expanduser("~/.config/google/genai_key")
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                with open(path, "r") as f:
                    c = f.read().strip()
                    if c:
                        return c
            except Exception:
                pass
    return None

def query_gemini_kv_cache(prompt):
    api_key = get_api_key()
    if not api_key:
        return None

    # Locate the active COTTAS / TSV spine files to pass as the context prefix
    squad_base = os.path.expanduser("~/repos/7R1PL3F0RC3")
    spines = []
    current_spines = glob.glob(".lex/_ignore/cottas/*.spine.*") + glob.glob(".lex/_ignore/spine/*.spine.*")
    spines.extend(current_spines)
    if os.path.exists(squad_base):
        spines.extend(glob.glob(f"{squad_base}/*/.lex/_ignore/cottas/*.spine.*"))
        spines.extend(glob.glob(f"{squad_base}/*/.lex/_ignore/spine/*.spine.*"))
    spines = list(set(spines))

    if not spines:
        return None

    # Load the graph spine prefix
    graph_context = []
    for sp in spines:
        repo = os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(sp)))))
        try:
            with open(sp, "r", encoding="utf-8", errors="ignore") as f:
                graph_context.append(f"### SOUL GRAPH: {repo}\n{f.read()}")
        except Exception:
            continue

    if not graph_context:
        return None

    full_graph = "\n\n".join(graph_context)

    system_instruction = (
        "You are Kira, the Neural Memory Oracle for the 7R1PL3F0RC3 squad. "
        "You hold the pre-cached RDF knowledge graph of the entire fleet in your neural attention. "
        "When the user asks a question, scan the graph in your context and extract the 3-5 most relevant exact facts, "
        "titles, dates, and entity URIs that directly answer the query. Format concisely as bullet points."
    )

    endpoint = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"
    payload = {
        "system_instruction": {
            "parts": [{"text": system_instruction}]
        },
        "contents": [
            {
                "role": "user",
                "parts": [
                    {"text": f"SQUAD KNOWLEDGE GRAPH:\n{full_graph}\n\nUSER PROMPT:\n{prompt}"}
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.1,
            "maxOutputTokens": 400
        }
    }

    try:
        req = urllib.request.Request(
            endpoint,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=8) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data["candidates"][0]["content"]["parts"][0]["text"].strip()
    except Exception:
        return None

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

    # Trigger patterns for recall
    trigger_patterns = [
        r"\bremember\b",
        r"\brecall\b",
        r"\bwhat was\b",
        r"\bwho worked on\b",
        r"\bwhen did we\b",
        r"\bwhere did we\b",
        r"\bwhy did we\b",
        r"^/recall\b"
    ]
    if len(sys.argv) <= 1:
        if not any(re.search(pat, prompt, re.IGNORECASE) for pat in trigger_patterns):
            return

    result = query_gemini_kv_cache(prompt)
    if not result:
        return

    print("\n--- [Kira Neural Memory Oracle: KV Cache Recall] ---")
    print(result)
    print("----------------------------------------------------\n")

if __name__ == "__main__":
    main()
