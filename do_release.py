#!/usr/bin/env python3
import json, urllib.request, sys, os

TOKEN_FILE = "/tmp/gh_token.txt"
REPO = "777cola/PowerPulse"

def main():
    if not os.path.exists(TOKEN_FILE):
        print(f"Error: Token file not found at {TOKEN_FILE}")
        sys.exit(1)
    
    TOKEN = open(TOKEN_FILE).read().strip()
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Step 1: Create release
    print("Creating release...")
    with open(os.path.join(script_dir, "release_body.json")) as f:
        body = f.read()

    req = urllib.request.Request(
        f"https://api.github.com/repos/{REPO}/releases",
        data=body.encode(),
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json"
        },
        method="POST"
    )
    try:
        resp = urllib.request.urlopen(req)
        data = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        print(f"Error {e.code}: {e.read().decode()}")
        sys.exit(1)

    upload_url = data["upload_url"].split("{")[0]
    html_url = data["html_url"]
    print(f"Release created: {html_url}")

    # Step 2: Upload DMG
    print("Uploading DMG...")
    dmg_path = os.path.join(script_dir, "PowerPulse-Installer.dmg")
    with open(dmg_path, "rb") as f:
        dmg_data = f.read()
    print(f"DMG size: {len(dmg_data)} bytes")

    req2 = urllib.request.Request(
        f"{upload_url}?name=PowerPulse-Installer.dmg",
        data=dmg_data,
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Content-Type": "application/octet-stream"
        },
        method="POST"
    )
    try:
        resp2 = urllib.request.urlopen(req2)
        upload_data = json.loads(resp2.read())
        print(f"Uploaded: {upload_data['name']} ({upload_data['state']})")
        print(f"Download: {upload_data['browser_download_url']}")
    except urllib.error.HTTPError as e:
        print(f"Upload error {e.code}: {e.read().decode()}")
        sys.exit(1)

    print("\nRelease published!")

if __name__ == "__main__":
    main()
