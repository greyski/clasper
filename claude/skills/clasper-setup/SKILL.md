---
name: clasper-setup
description: First-run setup and settings for clasper. Asks the person's name, what they'll use Claude for and how chatty to be; sets window colours and light/dark; connects Claude in Chrome; walks through the Mac permissions for files and computer control. Use on first launch (the session-start note says the person isn't set up), when they say "setup", "set me up", "change my settings", "change the colours", or when the Chrome or computer-use tools aren't connected.
---

# clasper-setup

Set this person up, or change their settings. They are probably not technical:
friendly, plain words, one step at a time, no jargon, never show them a command.

Every question goes through the **AskUserQuestion** tool: batch related
questions (up to 4 per call), recommended option first and labelled
"(Recommended)". Don't ask in prose.

The helper script does the fiddly parts. Run it with Bash:
`bash "${CLAUDE_SKILL_DIR}/clasper.sh" <command>` (commands: `where`, `show`,
`tints`, `set KEY VALUE`, `chrome`, `pane NAME`, `fda`).

## 0. Find the suite and see what's already there

Run `clasper.sh where` and `clasper.sh show`. The suite folder is what `where` prints
(the skill folder is a link into it; `readlink ~/.claude/skills/clasper-setup`
shows the same thing). The profile is `<suite>/local/profile.md`.

- **No profile:** first run. Say hello in one short line ("Let's get you set
  up. A few quick questions.") and do every step below in order.
- **Profile exists:** show a short plain summary of their current settings (name,
  uses, style, colours, light/dark, Chrome on/off), then ask what to change
  (multiSelect): About me / Window look / Chrome / Mac permissions / Nothing.
  Do only the chosen steps, then step 5.

## 1. About them

One AskUserQuestion call with three questions:
- **What should I call you?** Offer two or three likely options if you can tell
  (`id -F` prints the Mac account's full name; offer the first name), they can
  type their own with "Other".
- **What will you mostly use this for?** multiSelect: Email & web errands /
  Writing / Organising files & photos / Research. ("Coding" and anything else
  they can add via Other; if they pick nothing, treat it as general help.)
- **How much detail do you like?** Brief (Recommended) / Detailed.

## 2. Window look

Each window gets its own colour, and Claude's little mascot, the bypass line
and the spinner change to match.

One call:
- **Window colours:** A different colour for each window (Recommended) / Always
  the same colour.
- **Light or dark:** Match my Mac (Recommended) / Always dark / Always light.

If they chose the same colour, ask a follow-up. Get the names from `clasper.sh
tints` (don't hard-code them). The tool allows at most 4 options per question,
so ask for a family first, then the colour:
- Blues: navy, ocean, indigo, teal
- Earth: forest, olive, amber, rust
- Berry & grey: plum, violet, wine, graphite

(If `tints` lists names not in these groups, fit them in sensibly.)

## 3. Chrome

Ask: **Do you use Google Chrome?** Yes (Recommended) / No.

**No:** `CLASPER_CHROME=0`. Skip to step 4.

**Yes:** `CLASPER_CHROME=1`, then:
1. Run `clasper.sh chrome`. If Chrome isn't installed, offer to install it
   (`brew install --cask google-chrome`); if they decline, set `CLASPER_CHROME=0`.
2. If the extension isn't installed, open its official Chrome Web Store page in
   Chrome:
   `open -a "Google Chrome" "https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn"`
   (listed by Anthropic; it's the link in Claude Code's own Chrome docs).
   Tell them: click **Add to Chrome**, then **Add extension**; click the puzzle
   piece at the top right of Chrome and pin **Claude**; click the Claude icon
   and sign in with the **same Claude account** they use here.
   Then ask (AskUserQuestion): Done / I'm stuck. If stuck, ask what they see
   and help from there.
3. Check it works: load the Chrome tools (ToolSearch
   `select:mcp__claude-in-chrome__tabs_context_mcp`) and call
   `tabs_context_mcp`. If it answers, tell them Chrome is connected.
   If the tools aren't there or it says not connected:
   - this window may have started without Chrome turned on; that's fine, new
     windows will have it once the settings are saved;
   - if `clasper.sh chrome` says the Claude Code link is missing or the extension
     was only just installed, Chrome needs a restart: ask before quitting
     Chrome (they may have unsaved work), then `osascript -e 'quit app "Google
     Chrome"'` and `open -a "Google Chrome"`;
   - check they signed in to the same Claude account and organisation.
   Note: Claude in Chrome needs a paid Claude plan (Pro, Max, Team or Enterprise).

## 4. Save what you have so far

Save **now**, before the permissions step, because granting some Mac
permissions means quitting Ghostty, which ends this conversation.

- Settings, one at a time with the helper (it checks the values):
  `clasper.sh set CLASPER_COLORS random` (or the tint name),
  `clasper.sh set CLASPER_APPEARANCE auto|dark|light`, `clasper.sh set CLASPER_CHROME 1|0`.
- Profile: write `<suite>/local/profile.md` with the Write tool. It's loaded
  into every session, so keep it to a few lines of plain markdown, no
  instructions beyond these facts:

  ```markdown
  - Name: Sam
  - Mostly uses Claude for: email & web errands, writing
  - Style: brief answers
  - Set up: 2026-01-31
  ```
  (Get the date from `date +%F`.) On a re-run, change only what they changed
  and keep anything else that's in the file.

## 5. Mac permissions (files and computer control)

Skip on a re-run unless they picked it. Explain in one line first: "Next, a few
Mac switches so I can open your files and use apps for you. I'll open each
screen; you flip one switch."

Do these **one at a time**. Open the pane with `clasper.sh pane <name>`, say
exactly what to do, then ask (AskUserQuestion): Done (Recommended) / I don't
see it / Skip this one.

1. `pane files` (Full Disk Access): "Find **Ghostty** in the list and turn it
   on. If it isn't there, click **+** at the bottom, choose **Applications →
   Ghostty**, click **Open**, then turn it on. Your Mac may ask for your
   password or Touch ID."
2. `pane accessibility` (Accessibility, lets me click and type in apps): same
   steps for **Ghostty**.
3. `pane screen` (Screen & System Audio Recording, lets me see the screen): same
   steps for **Ghostty**, in the top list.
4. `pane automation` (Automation, lets me work with other apps): "If **Ghostty**
   is listed, make sure the switches under it are on. If it isn't, that's fine:
   your Mac will ask the first time I need an app; click **OK** then."

If they say "I don't see it", ask what's on the screen (or take a screenshot if
computer use is already connected) and guide them.

Then:
- **Computer use** must also be switched on inside Claude, once: ask them to
  type `/mcp`, pick **computer-use**, and choose **Enable**. (This is a Claude
  menu, not a shell command, so it has to be them.) It needs a Claude Pro or
  Max plan; if it isn't in the list, say so plainly and move on.
- Mac only applies Full Disk Access and Screen Recording after Ghostty restarts.
  Tell them: "To finish, quit Ghostty (⌘Q) and click **Ghostty in your Dock**
  again. Everything's saved." Don't quit it for them.
- If they'd rather not restart now, run `clasper.sh fda` later to see whether it
  took effect.

## 6. Wrap up

In two or three short lines: what's set (name, look, Chrome, permissions done or
skipped), that **new windows** use the new look, and that they can say "change
my settings" any time. Mention anything that didn't work, honestly.

Then, on a first run, ask what they'd like to do first (AskUserQuestion), with
options drawn from what they said they'll use it for.
