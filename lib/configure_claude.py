#!/usr/bin/env python3
"""Point Claude Code at clasper, or take it back out.

    configure_claude.py --repo DIR [--dry-run]
    configure_claude.py --repo DIR --uninstall [--dry-run]

Install makes these changes, each one a merge (other content is kept):
  ~/.claude.json            trust ~/claude (no folder prompt), Chrome on by default
  ~/.claude/settings.json   no bypass-mode warning; SessionStart hook -> the suite's hook
  ~/.claude/CLAUDE.md       one @import line for the suite's CLAUDE.md
  ~/.claude/skills/clasper-setup  symlink to the suite's onboarding skill

Uninstall removes the hook, the import line and the symlink. It leaves the
~/.claude.json trust/Chrome flags and the bypass-warning flag alone, since
those are ordinary Claude settings the user may want anyway.

Every file that changes is copied first to ~/.claude/backups/clasper-<time>/.
Re-running is safe: nothing is added twice.
"""
import argparse
import json
import os
import shlex
import shutil
import sys
import tempfile
import time
from pathlib import Path

HOME = Path.home()
CLAUDE_JSON = HOME / ".claude.json"
CLAUDE_DIR = HOME / ".claude"
SETTINGS = CLAUDE_DIR / "settings.json"
MEMORY = CLAUDE_DIR / "CLAUDE.md"
SKILL_LINK = CLAUDE_DIR / "skills" / "clasper-setup"
IMPORT_COMMENT = "<!-- clasper: loads the suite's instructions (added by install.sh; removed by install.sh --uninstall) -->"


class Run:
    def __init__(self, dry, backup_dir=None):
        self.dry = dry
        self.backup_dir = Path(backup_dir) if backup_dir else CLAUDE_DIR / "backups" / time.strftime("clasper-%Y%m%d-%H%M%S")
        self.changed = False

    def say(self, msg):
        print(("  [dry run] would " if self.dry else "  ") + msg)

    def backup(self, path):
        if self.dry or not path.exists():
            return
        rel = path.relative_to(HOME) if path.is_relative_to(HOME) else Path(path.name)
        dest = self.backup_dir / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)

    def write_text(self, path, text):
        """Back up, then replace atomically, keeping the file's permissions."""
        self.changed = True
        if self.dry:
            return
        self.backup(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        mode = path.stat().st_mode & 0o777 if path.exists() else 0o600 if path == CLAUDE_JSON else 0o644
        fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
        with os.fdopen(fd, "w") as f:
            f.write(text)
        os.chmod(tmp, mode)
        os.replace(tmp, path)

    def write_json(self, path, data):
        self.write_text(path, json.dumps(data, indent=2) + "\n")


def read_json(path):
    if not path.exists() or not path.read_text().strip():
        return {}
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        sys.exit(f"  {path} isn't valid JSON ({e}); fix or move it, then re-run.")
    if not isinstance(data, dict):
        sys.exit(f"  {path} doesn't hold a JSON object; fix or move it, then re-run.")
    return data


# --- ~/.claude.json -------------------------------------------------------

def claude_json(run, install):
    if not install:
        return
    data = read_json(CLAUDE_JSON)
    project = data.setdefault("projects", {}).setdefault(str(HOME / "claude"), {})
    todo = []
    if project.get("hasTrustDialogAccepted") is not True:
        project["hasTrustDialogAccepted"] = True
        todo.append("trust the ~/claude folder")
    # The suite's CLAUDE.md is imported from outside the folder; pre-approve that
    # so the first session doesn't ask. Only when unset: a "no" is respected.
    for key in ("hasClaudeMdExternalIncludesApproved", "hasClaudeMdExternalIncludesWarningShown"):
        if key not in project:
            project[key] = True
            if "approve" not in " ".join(todo):
                todo.append("approve the suite's CLAUDE.md import")
    if data.get("claudeInChromeDefaultEnabled") is not True:
        data["claudeInChromeDefaultEnabled"] = True
        todo.append("turn Claude in Chrome on by default")
    if todo:
        run.say(f"{CLAUDE_JSON}: " + ", ".join(todo))
        run.write_json(CLAUDE_JSON, data)
    else:
        print(f"  {CLAUDE_JSON}: already set")


# --- ~/.claude/settings.json ---------------------------------------------

def is_our_hook(h, hook_path):
    try:
        argv = shlex.split(h.get("command", ""))
    except ValueError:
        return False
    return h.get("type") == "command" and argv == [str(hook_path)]


def settings(run, install, hook_path):
    data = read_json(SETTINGS)
    todo = []
    hooks = data.get("hooks", {})
    groups = hooks.get("SessionStart", [])
    ours = [h for g in groups for h in g.get("hooks", []) if is_our_hook(h, hook_path)]

    if install:
        if data.get("skipDangerousModePermissionPrompt") is not True:
            data["skipDangerousModePermissionPrompt"] = True
            todo.append("skip the bypass-mode warning")
        if not ours:
            # No matcher: fires on startup, resume, clear and compact alike.
            groups.append({"hooks": [{"type": "command", "command": shlex.quote(str(hook_path))}]})
            data.setdefault("hooks", {})["SessionStart"] = groups
            todo.append("add the SessionStart hook")
        if not hook_path.exists():
            print(f"  note: {hook_path} doesn't exist yet; the hook will do nothing until it does")
    elif ours:
        kept = []
        for g in groups:
            g["hooks"] = [h for h in g.get("hooks", []) if not is_our_hook(h, hook_path)]
            if g["hooks"]:
                kept.append(g)
        if kept:
            hooks["SessionStart"] = kept
        else:
            hooks.pop("SessionStart", None)
        if not hooks:
            data.pop("hooks", None)
        todo.append("remove the SessionStart hook")

    if todo:
        run.say(f"{SETTINGS}: " + ", ".join(todo))
        run.write_json(SETTINGS, data)
    else:
        print(f"  {SETTINGS}: {'already set' if install else 'nothing of ours'}")


# --- ~/.claude/CLAUDE.md --------------------------------------------------

def memory(run, install, import_target):
    line = f"@{import_target}"
    text = MEMORY.read_text() if MEMORY.exists() else ""
    lines = text.splitlines()
    present = line in (l.strip() for l in lines)
    if install:
        if present:
            print(f"  {MEMORY}: import already there")
            return
        if " " in str(import_target):
            print(f"  warning: {import_target} has a space in it; CLAUDE.md imports may not follow it")
        sep = "" if not text or text.endswith("\n\n") else "\n" if text.endswith("\n") else "\n\n"
        run.say(f"{MEMORY}: {'create it with' if not MEMORY.exists() else 'append'} {line}")
        run.write_text(MEMORY, text + sep + IMPORT_COMMENT + "\n" + line + "\n")
    else:
        if not present and IMPORT_COMMENT not in lines:
            print(f"  {MEMORY}: nothing of ours")
            return
        kept = [l for l in lines if l.strip() not in (line, IMPORT_COMMENT)]
        while kept and not kept[-1].strip():
            kept.pop()
        run.say(f"{MEMORY}: remove {line}")
        run.write_text(MEMORY, "\n".join(kept) + "\n" if kept else "")


# --- ~/.claude/skills/clasper-setup -----------------------------------------

def skill(run, install, target):
    link = SKILL_LINK
    if install:
        if link.is_symlink():
            if os.readlink(link) == str(target):
                print(f"  {link}: already linked")
                return
            run.say(f"{link}: re-point it from {os.readlink(link)} to {target}")
            run.changed = True
            if not run.dry:
                link.unlink()
                link.symlink_to(target)
            return
        if link.exists():
            print(f"  {link}: a real folder is already there; leaving it alone")
            return
        if not target.exists():
            print(f"  note: {target} doesn't exist yet; the link will work once it does")
        run.say(f"{link}: link to {target}")
        run.changed = True
        if not run.dry:
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(target)
    else:
        if link.is_symlink() and os.readlink(link) == str(target):
            run.say(f"{link}: remove the link")
            run.changed = True
            if not run.dry:
                link.unlink()
        else:
            print(f"  {link}: nothing of ours")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", required=True, help="the clasper folder")
    ap.add_argument("--dry-run", action="store_true", help="show the changes, write nothing")
    ap.add_argument("--uninstall", action="store_true", help="take the suite back out")
    ap.add_argument("--backup-dir", help="where to copy files before changing them (default: a new timestamped folder)")
    a = ap.parse_args()
    repo = Path(a.repo).resolve()
    run = Run(a.dry_run, a.backup_dir)
    install = not a.uninstall

    claude_json(run, install)
    settings(run, install, repo / "claude" / "hooks" / "session-start.sh")
    memory(run, install, repo / "claude" / "CLAUDE.md")
    skill(run, install, repo / "claude" / "skills" / "clasper-setup")

    if run.changed and not run.dry and run.backup_dir.exists() and not a.backup_dir:
        print(f"  backups of the old files: {run.backup_dir}")


if __name__ == "__main__":
    main()
