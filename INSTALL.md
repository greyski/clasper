# Installing Clasper (instructions for Claude)

You are Claude, running in Claude Code on someone's Mac. They asked you to set
up Clasper, probably by pasting one sentence with this repo's link. Assume
they are not technical: do every step yourself, explain in plain words, never
ask them to type a command, and don't show them commands or output unless they
ask. Tell them in one short line what's about to happen before each step.

The repo URL is the one they gave you. Below, `greyski/clasper` stands for it.
The default install folder is `~/claude/clasper`. The scripts work from
anywhere, so if it's already somewhere else, use that copy.

## 1. Get the files

1. `mkdir -p ~/claude`
2. If `~/claude/clasper` already exists, this is an update: go to
   [Update](#update) instead.
3. Check whether git really works. On a fresh Mac `/usr/bin/git` is a stub
   that pops up an "install Command Line Tools" dialog, so don't call `git`
   until this succeeds:

   ```sh
   xcode-select -p >/dev/null 2>&1 && git --version
   ```

4. If it works: `git clone https://github.com/greyski/clasper.git ~/claude/clasper`
5. If not, download the zip instead (no Command Line Tools needed):

   ```sh
   tmp=$(mktemp -d)
   curl -fsSL -o "$tmp/clasper.zip" https://github.com/greyski/clasper/archive/refs/heads/main.zip
   ditto -x -k "$tmp/clasper.zip" "$tmp"
   mv "$tmp"/clasper-* ~/claude/clasper
   rm -rf "$tmp"
   ```

   If the zip 404s, the default branch may not be `main`; check it with
   `curl -fsSL https://api.github.com/repos/greyski/clasper | grep default_branch`.

## 2. Run the installer

Before you run it, tell them what it does, in two lines: it adds the Ghostty
app to the Dock, and from then on clicking Ghostty opens Claude. Also explain
bypass permissions mode in plain words: Claude will act without asking each time, but will still check
before deleting, sending, sharing or buying anything.

Then run `~/claude/clasper/install.sh` (use `run_in_background` if it might
take more than a couple of minutes, since it downloads Ghostty).

Relay the result in plain words: what got installed, and anything that failed.
If something failed, read the output, fix the cause and run it again. It's safe
to re-run. Don't report success unless it finished cleanly.

## 3. Move into Ghostty

When the installer finishes, it hands this conversation over to a Ghostty
window as soon as you finish your turn. So end your turn with something like:

> All done. In a moment this conversation moves into a new Ghostty window with
> its own color. That's where we'll work from now on. Next time, just click
> **Ghostty in your Dock**.
>
> If no new window shows up within a minute, click **Ghostty in your Dock**
> yourself. If your Mac asks whether to open Ghostty, click **Open**.

Don't do anything after that message. A busy session can't be moved.

## 4. In Ghostty

The new window starts Claude with the suite's rules. Its session-start note says
the person hasn't been set up yet, so the `clasper-setup` skill runs first: name,
what they'll use it for, window colors, Chrome, and the Mac permissions. That
skill has its own instructions; nothing more is needed from this file.

## Update

When they say "update Clasper" (or similar):

1. Find the install: `~/claude/clasper` by default. If it isn't there, follow
   `~/.claude/skills/clasper-setup` with `readlink` to find it.
2. If it has a `.git` folder and git works (`xcode-select -p`), run
   `git -C <install> pull --ff-only`. If that refuses because of local edits,
   tell them plainly and ask (AskUserQuestion) before discarding anything.
3. Otherwise re-download the zip as in step 1 into a temporary folder, then copy
   it over the install without touching their personal files in `local/`:

   ```sh
   rsync -a --delete --exclude '/local/' --exclude '/.git/' "$tmp"/clasper-*/ <install>/
   ```

4. Run `<install>/install.sh` again and tell them in a line what changed (for a
   git install, `git log --oneline` between the old and new commit). New windows
   pick up the update; this window keeps running as it was.

## Uninstall

When they ask to remove Clasper:

1. Confirm first (AskUserQuestion): this removes the Ghostty Dock setup and
   Clasper's rules; their work in `~/claude/` stays.
2. Run `<install>/install.sh --uninstall` and relay the result.
3. Ask (AskUserQuestion) whether to also delete the Clasper folder itself,
   including their saved settings in `local/`. Default: keep it. If they say
   yes, move it to the Trash (`mv <install> ~/.Trash/`) rather than deleting.
4. Ghostty, Claude Code and their files are left alone unless they ask.
