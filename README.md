# Clasper

A small macOS setup that gives a non-technical person Claude Code with one
click. Click Ghostty in the Dock and a window opens with Claude already running
in bypass permissions mode, so it just does things: files, installs, web
errands in your own Chrome, and native Mac apps. Claude walks you through a
short setup the first time, and the rules it follows are written for people
who don't want to see a command line.

What you get:

- **One click from the Dock.** Ghostty is pinned to the Dock with a white ghost
  icon (a nod to Claude's mascot and to Ghostty). Every window is a Claude
  session.
- **Bypass permissions mode.** Claude runs commands and installs what it needs
  without stopping to ask (read the warning below).
- **A colour per window.** Each window gets its own tint, and Claude's mascot,
  the bypass line and the spinner are recoloured to match, using Claude Code's
  `*-ansi` themes and the terminal palette. Follows Mac light/dark, or pin one.
- **Chrome and computer use, set up.** Claude in Chrome for websites (Gmail,
  shopping, forms) and computer use for native apps, with the Mac permissions
  walked through step by step.
- **Guided first run.** Claude asks your name, what you'll use it for, and how
  you like your answers, then sets everything up. Say "change my settings" any
  time to redo it.
- **Plain-language rules.** Claude asks before deleting, sending or sharing
  anything, never buys anything, computes (never guesses) dates, sums and random
  picks, and keeps your work in `~/claude/` with notes for each project.
- **`clasper-migrate`.** Moves Claude sessions already running in Terminal.app
  into Ghostty windows, reopening the same conversations.

## Read this first: what bypass permissions mode means

Claude Code normally asks before it runs a command, edits a file or uses the
web. **This setup turns all of those prompts off.** Claude can read, change and
delete anything your Mac account can, install software, and act in your signed-in
Chrome (your email, your accounts) without asking first.

The included rules tell Claude to confirm before anything destructive or
outward-facing, and never to move money or place orders. Those are instructions,
not locks: Claude usually follows them, but nothing enforces them. A web page or
an email can also contain text written to trick it. Only use this on a Mac and
accounts where you're comfortable with that, keep backups (Time Machine), and
watch what it's doing when it matters.

## Get started (no programming needed)

You need a Mac and a paid Claude plan. The free plan doesn't include Claude
Code, and controlling Mac apps (computer use) needs Pro or Max.

1. **Install Claude Code** from Anthropic's official instructions:
   <https://code.claude.com/docs/en/setup>. In short: open Terminal (press
   **Cmd-Space**, type **Terminal**, press Return), paste this line and press
   Return:

   ```sh
   curl -fsSL https://claude.ai/install.sh | bash
   ```

2. **Start Claude.** Quit Terminal and open it again, type `claude` and press
   Return. Follow the steps to sign in with your Claude account in the browser.
3. **Paste this sentence** into Claude and press Return:

   ```text
   Please set up Clasper for me by following INSTALL.md in https://github.com/greyski/clasper
   ```

4. **That's it.** Claude downloads everything, sets it up, and moves your
   conversation into a new Ghostty window. It then asks you a few questions
   (your name, colours, Chrome) and walks you through the Mac permissions.
   If your Mac asks whether to open Ghostty, click **Open**. From then on,
   click **Ghostty in your Dock** to start, and type `/resume` to reopen an
   earlier conversation.

Later, say **"update Clasper"** or **"uninstall Clasper"** and Claude
handles it. Say **"change my settings"** to redo the setup questions.

## Heads-up if you already use Ghostty

The installer makes this suite Ghostty's default config (it adds an include line
to `~/.config/ghostty/config`). After that, **every Ghostty window opens
Claude**, not a shell. If Ghostty is your everyday terminal, use another one for
shell work, or don't install this. Ghostty itself keeps updating normally.

## For programmers

Prerequisites: macOS and Claude Code (signed in). No sudo or Homebrew needed:
the installer fetches Ghostty from its official DMG and Python via uv.

```sh
mkdir -p ~/claude
git clone https://github.com/greyski/clasper.git ~/claude/clasper
~/claude/clasper/install.sh
```

`~/claude/clasper` is the default location, but the scripts work from
anywhere. The installer links the rules (`claude/CLAUDE.md`), the setup skill
and a session-start hook into `~/.claude/`, and makes the suite Ghostty's
default config. Run it from a Claude session and it moves that session into
Ghostty once it goes idle. [INSTALL.md](INSTALL.md) is the step-by-step Claude
follows, including update and uninstall.

Update: `git -C ~/claude/clasper pull && ~/claude/clasper/install.sh`.

## Your files stay yours

Everything personal lives in `local/` inside this folder (your profile and
settings), which is ignored by git, so updating with `git pull` never touches
it and it never ends up in a commit. Work Claude makes for you goes in
`~/claude/`.

## Uninstall

```sh
~/claude/clasper/install.sh --uninstall
```

(or tell Claude "uninstall Clasper").

This removes the Dock icon, the Ghostty include line and the links in
`~/.claude/`. Your `local/` folder and `~/claude/` are left alone; delete them
yourself if you want them gone.

---

Not affiliated with or endorsed by Anthropic. Claude and Claude Code are
trademarks of Anthropic.
