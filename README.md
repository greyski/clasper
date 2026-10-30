# Clasper

A simple wrapper around [Ghostty](https://ghostty.org) and
[Claude Code](https://claude.com/claude-code) for macOS. Open Ghostty and you're
in a new Claude session, running in bypass permissions mode.

- **A session per window.** Cmd-N starts another.
- **A color per window.** Each one gets its own tint, in light or dark.
- **Cmd-R restarts Claude.** Picks up updates and keeps your conversation.
- **Guided setup.** Claude sets up Chrome and your Mac permissions with you.
- **Plain-language rules.** Claude checks before deleting, sending or sharing
  anything, and never buys anything.
- **`clasper-migrate`.** Moves Claude sessions from Terminal into Ghostty.

## Get started

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
   (your name, colors, Chrome) and walks you through the Mac permissions.
   If your Mac asks whether to open Ghostty, click **Open**. From then on,
   open **Ghostty** to start, and type `/resume` to reopen an
   earlier conversation.

Later, say **"update Clasper"** or **"uninstall Clasper"** and Claude
handles it. Say **"change my settings"** to redo the setup questions.

## Heads-up if you already use Ghostty

The installer makes this suite Ghostty's default config (it adds an include line
to `~/.config/ghostty/config`). After that, **every Ghostty window opens
Claude**, not a shell. If Ghostty is your everyday terminal, use another one for
shell work, or don't install this. Ghostty itself keeps updating normally.

## Uninstall

```sh
~/claude/clasper/install.sh --uninstall
```

(or tell Claude "uninstall Clasper").

This removes the Ghostty include line and the links in
`~/.claude/`. Your `local/` folder and `~/claude/` are left alone; delete them
yourself if you want them gone.

## Related

- [lotnikov/claude-terminal-tint](https://github.com/lotnikov/claude-terminal-tint):
  a Claude Code plugin that gives each concurrent session its own background
  tint.
- [ignaciojimenez/agent-sessions](https://github.com/ignaciojimenez/agent-sessions):
  records Claude Code sessions and reopens them as Ghostty windows, tabs and
  splits.

---

Not affiliated with or endorsed by Anthropic. Claude and Claude Code are
trademarks of Anthropic.
