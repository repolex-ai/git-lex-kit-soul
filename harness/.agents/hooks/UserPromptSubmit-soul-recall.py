#!/usr/bin/env python3
"""
UserPromptSubmit-soul-recall.py — Direct Neural KV Cache Recall Oracle
Trigger: Explicit "recall" keyword or "/recall" command in user prompt.
Model: Gemini 2.5/3.7 Flash (Low / Zero Thinking for sub-300ms response).
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

def query_gemini_kv_cache(full_user_prompt):
    api_key = get_api_key()
    if not api_key:
        return None

    # Gather squad COTTAS / TSV spines as the context prefix
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
        "You are Kira, the Neural Memory Oracle for the 7R1PL3F0RC3 fleet. "
        "You hold the pre-cached RDF knowledge graph of the entire squad in your neural attention. "
        "The user has asked for a 'recall' of specific past events, decisions, notes, textures, or code facts. "
        "Analyze the user's full message, scan the graph in your attention, and output the 3-5 most relevant exact facts, "
        "dates, titles, and entity URIs that answer the query. Be concise, direct, and factual."
    )

    # Use Gemini 2.5 Flash / Flash Low for ultra-fast response
    endpoint = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-3.7-flash:generateContent?key={api_key}"
    payload = {
        "system_instruction": {
            "parts": [{"text": system_instruction}]
        },
        "contents": [
            {
                "role": "user",
                "parts": [
                    {"text": f"SQUAD KNOWLEDGE GRAPH PREFIX:\n{full_graph}\n\nFULL USER MESSAGE:\n{full_user_prompt}"}
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
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data["candidates"][0]["content"]["parts"][0]["text"].strip()
    except Exception:
        return None

def main():
    full_prompt = ""
    # Support direct CLI testing: python3 UserPromptSubmit-soul-recall.py "my query"
    if len(sys.argv) > 1:
        full_prompt = " ".join(sys.argv[1:])
    else:
        try:
            raw_input = sys.stdin.read()
            if raw_input.strip():
                payload = json.loads(raw_input)
                full_prompt = payload.get("prompt", "")
        except Exception:
            return

    if not full_prompt or not full_prompt.strip():
        return

    # Trigger rule: STRICTLY the word "recall" (case-insensitive) or "/recall" command
    if len(sys.argv) <= 1:
        if not re.search(r"\brecall\b", full_prompt, re.IGNORECASE):
            return

    result = query_gemini_kv_cache(full_prompt)
    if not result:
        return

    print("\n--- [Kira Neural Memory Oracle: KV Cache Recall] ---")
    print(result)
    print("----------------------------------------------------\n")

if __name__ == "__main__":
    main()
