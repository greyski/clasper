#!/bin/bash
# Clasper installer: Claude Code in bypass-permissions mode, one session per
# Ghostty window, started from the Ghostty icon in the Dock.
#
#   ./install.sh               install, or update after pulling changes (safe to re-run)
#   ./install.sh --no-dock     same, but don't pin Ghostty to the Dock
#   ./install.sh --uninstall   take the suite back out (Ghostty, uv and Claude
#                              Code themselves stay installed)
#
# Needs Claude Code already installed and signed in. Never asks for a password,
# so Claude can run it for you. Keep this folder where it is afterwards:
# Ghostty and Claude read files from it. If you move it, run it again.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd -P)"
BUILD="$REPO/build"
LOCAL="$REPO/local"
SUITE_CONFIG="$BUILD/ghostty.config"
GHOSTTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
MARK_BEGIN="# >>> clasper >>> (added by install.sh; ./install.sh --uninstall removes it)"
MARK_END="# <<< clasper <<<"
DOCK_MARKER="$LOCAL/.ghostty-pinned-by-installer"
BACKUPS="$HOME/.claude/backups/clasper-$(date +%Y%m%d-%H%M%S)"
SETUP_URL="https://code.claude.com/docs/en/setup"
GHOSTTY_TEAM="24VZTF6M5V"   # Mitchell Hashimoto's Apple Developer ID
GHOSTTY_FALLBACK_DMG="https://release.files.ghostty.org/1.4.0/Ghostty.dmg"
# Where Ghostty may live. If set, CLASPER_APPS_DIR replaces this list.
if [ -n "${CLASPER_APPS_DIR:-}" ]; then APP_DIRS="$CLASPER_APPS_DIR"; else APP_DIRS="/Applications $HOME/Applications"; fi

DOCK=1
UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --no-dock) DOCK=0 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'; else B= G= Y= R= N=; fi
step() { printf '\n%s==> %s%s\n' "$B" "$1" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$1"; }
note() { printf '  %s!%s %s\n' "$Y" "$N" "$1"; }
die()  { printf '\n%sSomething went wrong:%s %s\n' "$R" "$N" "$1" >&2; exit 1; }
trap 'die "the step above failed (line $LINENO). Running ./install.sh again is safe and picks up where it stopped."' ERR

backup() {
  [ -f "$1" ] || return 0
  local rel="${1#$HOME/}"
  mkdir -p "$BACKUPS/$(dirname "$rel")"
  cp -p "$1" "$BACKUPS/$rel"
}

# A login zsh with a bare environment, the way Ghostty starts one from the
# Dock: checks that tools will be found in new windows, not just here.
login_zsh() { env -i HOME="$HOME" USER="${USER:-$(id -un)}" LOGNAME="${USER:-$(id -un)}" SHELL=/bin/zsh TERM=dumb /bin/zsh -lc "$1"; }

add_to_zprofile() {  # add_to_zprofile "<line>" "<why>"
  local zp="$HOME/.zprofile"
  if [ -f "$zp" ] && grep -qxF "$1" "$zp"; then return 0; fi
  backup "$zp"
  printf '\n# Added by Clasper install.sh: %s\n%s\n' "$2" "$1" >> "$zp"
  ok "added to $zp: $1"
}

find_ghostty_app() {
  local d
  for d in $APP_DIRS; do
    if [ -d "$d/Ghostty.app" ]; then echo "$d/Ghostty.app"; return 0; fi
  done
  return 1
}

# The ghostty config file our include goes in: wherever it already is, else
# the one Ghostty already uses, else the current default name.
ghostty_user_config() {
  local f
  for f in "$GHOSTTY_DIR/config.ghostty" "$GHOSTTY_DIR/config"; do
    if [ -f "$f" ] && grep -qxF "$MARK_BEGIN" "$f"; then echo "$f"; return; fi
  done
  for f in "$GHOSTTY_DIR/config.ghostty" "$GHOSTTY_DIR/config"; do
    if [ -f "$f" ]; then echo "$f"; return; fi
  done
  echo "$GHOSTTY_DIR/config.ghostty"
}

strip_block() {
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '$0==b{skip=1;next} skip&&$0==e{skip=0;next} !skip' "$1"
}

PYBIN=""
find_python() {
  local p
  for p in /opt/homebrew/bin/python3 /usr/local/bin/python3 "$(command -v python3 2>/dev/null || true)"; do
    [ -n "$p" ] && [ -x "$p" ] || continue
    if [ "$p" = /usr/bin/python3 ] && ! xcode-select -p >/dev/null 2>&1; then continue; fi
    if "$p" -c 'import sys; sys.exit(sys.version_info < (3, 9))' >/dev/null 2>&1; then PYBIN="$p"; return 0; fi
  done
  return 1
}
py() {
  if [ -n "$PYBIN" ]; then "$PYBIN" "$@"
  else uv run -q --no-project --python-preference only-managed --python 3.12 python "$@"; fi
}

[ "$(uname -s)" = Darwin ] || die "this installer is for macOS only."
for d in "$HOME/.local/bin"; do case ":$PATH:" in *":$d:"*) ;; *) export PATH="$d:$PATH" ;; esac; done

# --------------------------------------------------------------------------
if [ "$UNINSTALL" = 1 ]; then
  printf '%sRemoving Clasper%s (Ghostty, uv and Claude Code stay installed)\n' "$B" "$N"
  find_python || command -v uv >/dev/null 2>&1 || die "no Python or uv found to run the clean-up with."

  step "Ghostty settings"
  CONF="$(ghostty_user_config)"
  if [ -f "$CONF" ] && grep -qxF "$MARK_BEGIN" "$CONF"; then
    backup "$CONF"
    tmp="$(mktemp)"; strip_block "$CONF" > "$tmp"
    # drop trailing blank lines (we added one in front of the block)
    awk '{l[NR]=$0} END{n=NR; while (n>0 && l[n]=="") n--; for (i=1;i<=n;i++) print l[i]}' "$tmp" > "$CONF"; rm -f "$tmp"
    ok "Ghostty is back to its own settings ($CONF)"
  else
    ok "nothing of ours in Ghostty's settings"
  fi

  step "Dock"
  if [ -f "$DOCK_MARKER" ] && APP="$(find_ghostty_app)"; then
    py "$REPO/lib/dock.py" remove "$APP" | sed 's/^/  /'
  else
    ok "leaving the Dock alone (the suite didn't pin anything)"
  fi
  rm -f "$DOCK_MARKER"

  step "Claude Code settings"
  py "$REPO/lib/configure_claude.py" --repo "$REPO" --backup-dir "$BACKUPS" --uninstall
  [ -d "$BACKUPS" ] && note "copies of the files before this change: $BACKUPS"

  printf '\n%sDone.%s Clasper is removed. This folder can be deleted now.\n' "$B" "$N"
  exit 0
fi

# --------------------------------------------------------------------------
printf '%sSetting up Clasper%s: Claude, one Ghostty window at a time.\n' "$B" "$N"
echo "This takes a minute or two the first time (Ghostty is a ~35 MB download)."

step "Claude Code"
if ! command -v claude >/dev/null 2>&1; then
  printf '  Claude Code needs to be installed (and signed in) first. Instructions:\n    %s\n  Then run ./install.sh again.\n' "$SETUP_URL" >&2
  exit 1
fi
CLAUDE_BIN_DIR="$(dirname "$(command -v claude)")"
ok "Claude Code is installed ($(command -v claude))"
if login_zsh 'command -v claude' >/dev/null 2>&1; then
  ok "new windows will find it"
else
  case "$CLAUDE_BIN_DIR" in
    "$HOME"/*) pathline="export PATH=\"\$HOME/${CLAUDE_BIN_DIR#$HOME/}:\$PATH\"" ;;
    *) pathline="export PATH=\"$CLAUDE_BIN_DIR:\$PATH\"" ;;
  esac
  add_to_zprofile "$pathline" "let new windows find Claude Code"
fi

step "Ghostty (the app Claude's windows open in)"
if APP="$(find_ghostty_app)"; then
  ok "Ghostty is installed ($APP)"
elif [ -z "${CLASPER_APPS_DIR:-}" ] && command -v brew >/dev/null 2>&1; then
  echo "  Installing Ghostty with Homebrew..."
  env -u CLAUDECODE brew install --cask ghostty
  APP="$(find_ghostty_app)" || die "Homebrew finished but Ghostty.app isn't in /Applications."
  ok "installed Ghostty ($APP)"
else
  url="$(curl -fsSL https://ghostty.org/download 2>/dev/null \
        | grep -oE 'https://release\.files\.ghostty\.org/[0-9][0-9.]*/Ghostty\.dmg' | head -1 || true)"
  url="${url:-$GHOSTTY_FALLBACK_DMG}"
  work="$(mktemp -d)"
  cleanup_dmg() { hdiutil detach -quiet "$work/mnt" >/dev/null 2>&1 || true; rm -rf "$work"; }
  trap 'cleanup_dmg; die "the step above failed (line $LINENO). Running ./install.sh again is safe."' ERR
  echo "  Downloading $url"
  if [ -t 1 ]; then curl -fL --progress-bar -o "$work/Ghostty.dmg" "$url"; else curl -fsSL -o "$work/Ghostty.dmg" "$url"; fi
  mkdir "$work/mnt"
  hdiutil attach -quiet -nobrowse -readonly -noautoopen -mountpoint "$work/mnt" "$work/Ghostty.dmg"
  if ! codesign --verify --deep --strict \
       -R="anchor apple generic and identifier \"com.mitchellh.ghostty\" and certificate leaf[subject.OU] = \"$GHOSTTY_TEAM\"" \
       "$work/mnt/Ghostty.app" 2>/dev/null; then
    cleanup_dmg; die "the downloaded Ghostty isn't signed by its developer ($GHOSTTY_TEAM). Not installing it."
  fi
  ok "download is genuine (signed by Mitchell Hashimoto, $GHOSTTY_TEAM)"
  APP=""
  for d in $APP_DIRS; do
    if mkdir -p "$d" 2>/dev/null && ditto "$work/mnt/Ghostty.app" "$d/Ghostty.app" 2>/dev/null; then APP="$d/Ghostty.app"; break; fi
    rm -rf "$d/Ghostty.app" 2>/dev/null || true
  done
  cleanup_dmg
  trap 'die "the step above failed (line $LINENO). Running ./install.sh again is safe and picks up where it stopped."' ERR
  [ -n "$APP" ] || die "couldn't copy Ghostty into $APP_DIRS."
  ok "installed Ghostty ($APP); it keeps itself up to date"
fi
GHOSTTY="$APP/Contents/MacOS/ghostty"

step "uv and Python (small helpers the suite uses)"
if command -v uv >/dev/null 2>&1; then
  ok "uv is installed"
else
  curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh >/dev/null
  command -v uv >/dev/null 2>&1 || die "uv didn't install."
  ok "installed uv ($(command -v uv))"
fi
if find_python; then
  ok "Python is ready ($PYBIN)"
else
  uv python install -q 3.12
  ok "installed Python 3.12 (managed by uv)"
fi

step "Folders"
mkdir -p "$HOME/claude/projects" "$BUILD" "$LOCAL"
ok "$HOME/claude/projects (Claude works here)"
if [ ! -f "$LOCAL/settings.env" ]; then
  cat > "$LOCAL/settings.env" <<'EOF'
# Clasper personal settings (this file stays on this Mac).
# Remove the leading "# " from a line to change a setting.

# Window color: random (a different tint per window), or one of
# indigo teal plum rust forest wine navy olive violet ocean amber graphite
# CLASPER_COLORS=random

# Light or dark windows: auto (follow macOS), light, or dark
# CLASPER_APPEARANCE=auto

# Let Claude use Chrome (1 = yes, 0 = no)
# CLASPER_CHROME=1
EOF
  ok "created $LOCAL/settings.env (window color and other preferences)"
fi

step "Ghostty settings"
q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }   # shell-quote
COMMAND_LINE="$(q "$REPO/bin/clasper-session")"
if [ -f "$REPO/assets/icon-1024.png" ]; then
  ICON_BLOCK="macos-icon = custom
macos-custom-icon = \"$REPO/assets/icon-1024.png\""
  icon_msg="Clasper icon"
else
  ICON_BLOCK="# (assets/icon-1024.png isn't there yet, so a tinted Ghostty ghost stands
#  in. Re-run install.sh once it exists to switch to it.)
macos-icon = custom-style
macos-icon-frame = plastic
macos-icon-ghost-color = #d97757
macos-icon-screen-color = #1a1a33,#30121a"
  icon_msg="stand-in icon: assets/icon-1024.png not found"
fi
tpl="$(cat "$REPO/templates/ghostty.config.in")"
tpl="${tpl//@COMMAND@/$COMMAND_LINE}"
tpl="${tpl//@ICON@/$ICON_BLOCK}"
printf '%s\n' "$tpl" > "$SUITE_CONFIG.tmp"
if ! out="$("$GHOSTTY" +validate-config --config-file="$SUITE_CONFIG.tmp" 2>&1)"; then
  rm -f "$SUITE_CONFIG.tmp"; die "Ghostty rejected the generated settings: $out"
fi
mv "$SUITE_CONFIG.tmp" "$SUITE_CONFIG"
ok "wrote $SUITE_CONFIG ($icon_msg)"

CONF="$(ghostty_user_config)"
BLOCK="$MARK_BEGIN
config-file = \"?$SUITE_CONFIG\"
$MARK_END"
mkdir -p "$GHOSTTY_DIR"
if [ -f "$CONF" ] && grep -qxF "$MARK_BEGIN" "$CONF"; then
  current="$(awk -v b="$MARK_BEGIN" -v e="$MARK_END" '$0==b{on=1} on{print} on&&$0==e{on=0}' "$CONF")"
  if [ "$current" = "$BLOCK" ]; then
    ok "Ghostty already opens Claude ($CONF)"
  else
    backup "$CONF"
    tmp="$(mktemp)"; strip_block "$CONF" > "$tmp"; printf '%s\n' "$BLOCK" >> "$tmp"; cat "$tmp" > "$CONF"; rm -f "$tmp"
    ok "updated the Clasper line in $CONF"
  fi
elif [ -s "$CONF" ]; then
  backup "$CONF"
  printf '\n%s\n' "$BLOCK" >> "$CONF"
  ok "Ghostty now opens Claude; the existing settings in $CONF are kept"
else
  printf '%s\n' "$BLOCK" > "$CONF"
  ok "Ghostty now opens Claude ($CONF)"
fi
if ! out="$("$GHOSTTY" +validate-config 2>&1)"; then
  note "Ghostty reports a problem in its combined settings:"; printf '%s\n' "$out" | sed 's/^/      /'
fi

step "Dock"
if [ "$DOCK" = 0 ]; then
  ok "skipped (--no-dock)"
elif py "$REPO/lib/dock.py" has "$APP"; then
  ok "Ghostty is already in the Dock"
else
  py "$REPO/lib/dock.py" add "$APP" >/dev/null
  touch "$DOCK_MARKER"
  ok "added Ghostty to the Dock"
fi

step "Claude Code settings"
py "$REPO/lib/configure_claude.py" --repo "$REPO" --backup-dir "$BACKUPS"

trap - ERR
if [ -n "${CLAUDECODE:-}" ] && [ "${TERM_PROGRAM:-}" = Apple_Terminal ]; then
  # Run by Claude from a Terminal window: carry this conversation over to
  # Ghostty as soon as Claude finishes its reply.
  step "Moving this conversation into Ghostty"
  MOVED=1
  py "$REPO/bin/clasper-migrate" --when-idle 2>&1 | sed 's/^/  /' || MOVED=0
fi
if [ "${MOVED:-0}" = 1 ]; then
  cat <<EOF

${B}All set!${N} When Claude finishes this reply, this Terminal window closes
and the conversation carries on in a Ghostty window. From now on, click
${B}Ghostty${N} in the Dock to start Claude; Cmd-N opens another window.
EOF
else
  cat <<EOF

${B}All set!${N}
Click ${B}Ghostty${N} in your Dock (the ghost icon). Each window is its own chat
with Claude; press ${B}Cmd-N${N} for another. Close a window when you're done.
EOF
  if pgrep -qx ghostty; then
    echo "(Ghostty is open right now: quit it with Cmd-Q and reopen it to pick up the new setup.)"
  fi
fi
