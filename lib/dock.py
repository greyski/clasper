#!/usr/bin/env python3
"""Pin or unpin an app in the macOS Dock.

    dock.py has    /Applications/Ghostty.app   exit 0 if pinned, 1 if not
    dock.py add    /Applications/Ghostty.app   pin it (no-op if already pinned)
    dock.py remove /Applications/Ghostty.app   unpin it (no-op if not pinned)

Reads and writes the Dock's preferences through `defaults export/import`, so
cfprefsd stays in sync, then restarts the Dock when something changed.

Testing: set CLASPER_DOCK_DOMAIN to a plist *path* to work on a copy instead of
the real com.apple.dock domain; the Dock is then never restarted.
"""
import os
import plistlib
import subprocess
import sys
from urllib.parse import quote, unquote, urlparse

DOMAIN = os.environ.get("CLASPER_DOCK_DOMAIN", "com.apple.dock")
REAL = "CLASPER_DOCK_DOMAIN" not in os.environ


def load():
    if not REAL and not os.path.exists(DOMAIN):
        return {}
    out = subprocess.run(["defaults", "export", DOMAIN, "-"], capture_output=True, check=True).stdout
    return plistlib.loads(out) if out.strip() else {}


def save(prefs):
    subprocess.run(["defaults", "import", DOMAIN, "-"], input=plistlib.dumps(prefs), check=True)
    if REAL:
        subprocess.run(["killall", "Dock"], check=False)


def tile_path(tile):
    url = tile.get("tile-data", {}).get("file-data", {}).get("_CFURLString", "")
    if url.startswith("file://"):
        url = unquote(urlparse(url).path)
    return os.path.realpath(url.rstrip("/")) if url else ""


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("has", "add", "remove"):
        sys.exit(__doc__)
    action, app = sys.argv[1], os.path.realpath(sys.argv[2].rstrip("/"))
    prefs = load()
    apps = prefs.get("persistent-apps", [])
    pinned = [t for t in apps if tile_path(t) == app]

    if action == "has":
        sys.exit(0 if pinned else 1)
    if action == "add":
        if pinned:
            print("already in the Dock")
            return
        apps.append({"tile-data": {"file-data": {
            "_CFURLString": "file://" + quote(app) + "/", "_CFURLStringType": 15}},
            "tile-type": "file-tile"})
        print("added to the Dock")
    else:
        if not pinned:
            print("not in the Dock")
            return
        apps = [t for t in apps if tile_path(t) != app]
        print("removed from the Dock")
    prefs["persistent-apps"] = apps
    save(prefs)


if __name__ == "__main__":
    main()
