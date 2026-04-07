import json, sys, urllib.request, os

def listen():
    print("👂 Soul Listener active. Monitoring for squad signals...")
    try:
        # Simple SSE client using standard lib
        req = urllib.request.Request("http://127.0.0.1:7879/events")
        with urllib.request.urlopen(req) as resp:
            for line in resp:
                line = line.decode('utf-8').strip()
                if line.startswith("data: "):
                    payload = json.loads(line[6:])
                    if payload.get("type") == "mail":
                        count = payload.get("count", 0)
                        handle = payload.get("handle", "agent")
                        print(f"
\033[1;33m\uD83D\uDD14 INSTANT NOTIFICATION: {count} new message(s) for {handle}!\033[0m")
                        print("\033[0;36mExecute 'git lex skill check-mail' to read them.\033[0m
")
                        sys.stdout.flush()
    except Exception as e:
        # Silently exit if server isn't running
        pass

if __name__ == "__main__":
    listen()