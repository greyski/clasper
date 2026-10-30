#!/bin/bash
# clasper-setup helper. Small, read-mostly commands the clasper-setup skill calls so
# it never has to guess paths, tint names, or System Settings links.
#
#   clasper.sh where              print the clasper folder
#   clasper.sh show               print the current profile and settings
#   clasper.sh tints              list the window tint names
#   clasper.sh set KEY VALUE      set CLASPER_COLORS / CLASPER_APPEARANCE / CLASPER_CHROME
#   clasper.sh chrome             report whether Chrome and the Claude extension are installed
#   clasper.sh pane NAME          open a Privacy & Security pane:
#                              files | accessibility | screen | automation
#   clasper.sh fda                report whether Full Disk Access is in effect
#
# bash 3.2 compatible (the macOS system bash).

set -u

# Resolve this script through symlinks (~/.claude/skills/clasper-setup -> repo).
src=$0
while [ -L "$src" ]; do
  dir=$(cd -P "$(dirname "$src")" && pwd)
  src=$(readlink "$src")
  case $src in /*) ;; *) src=$dir/$src ;; esac
done
SKILL_DIR=$(cd -P "$(dirname "$src")" && pwd)
SUITE=$(cd -P "$SKILL_DIR/../../.." && pwd)
LOCAL=$SUITE/local
SETTINGS=$LOCAL/settings.env
PROFILE=$LOCAL/profile.md
EXT_ID=fcoeoabgfenejglbffodgkkbkcdhcgfn
CHROME_DIR="$HOME/Library/Application Support/Google/Chrome"

tints() {  # names from the tints=(name:hue ...) line in bin/clasper-session
  sed -n 's/^tints=(\(.*\))/\1/p' "$SUITE/bin/clasper-session" | tr ' ' '\n' | cut -d: -f1
}

case ${1:-} in
  where) echo "$SUITE" ;;

  show)
    if [ -f "$PROFILE" ]; then echo "--- profile ($PROFILE)"; cat "$PROFILE"
    else echo "--- no profile yet ($PROFILE)"; fi
    if [ -f "$SETTINGS" ]; then echo "--- settings ($SETTINGS)"; cat "$SETTINGS"
    else echo "--- no settings yet (defaults: CLASPER_COLORS=random CLASPER_APPEARANCE=auto CLASPER_CHROME=1)"; fi
    ;;

  tints) tints ;;

  set)
    key=${2:-} val=${3:-}
    case $key in
      CLASPER_COLORS)
        [ "$val" = random ] || tints | grep -qx "$val" || { echo "unknown tint: $val (try: random $(tints | tr '\n' ' '))" >&2; exit 1; } ;;
      CLASPER_APPEARANCE)
        case $val in auto|dark|light) ;; *) echo "CLASPER_APPEARANCE must be auto, dark or light" >&2; exit 1 ;; esac ;;
      CLASPER_CHROME)
        case $val in 0|1) ;; *) echo "CLASPER_CHROME must be 1 or 0" >&2; exit 1 ;; esac ;;
      *) echo "unknown key: $key" >&2; exit 1 ;;
    esac
    mkdir -p "$LOCAL"
    if [ ! -f "$SETTINGS" ]; then
      printf '# clasper settings (written by the clasper-setup skill)\nCLASPER_COLORS=random\nCLASPER_APPEARANCE=auto\nCLASPER_CHROME=1\n' > "$SETTINGS"
    fi
    if grep -q "^$key=" "$SETTINGS"; then
      tmp=$(mktemp "$LOCAL/.settings.XXXXXX")
      sed "s/^$key=.*/$key=$val/" "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    else
      echo "$key=$val" >> "$SETTINGS"
    fi
    grep "^$key=" "$SETTINGS"
    ;;

  chrome)
    if [ -d "/Applications/Google Chrome.app" ] || [ -d "$HOME/Applications/Google Chrome.app" ]; then
      echo "chrome: installed"
    else
      echo "chrome: not installed"
    fi
    found=no
    for d in "$CHROME_DIR"/*/Extensions/"$EXT_ID"; do
      [ -d "$d" ] && { found=yes; echo "extension: installed in profile '$(basename "$(dirname "$(dirname "$d")")")'"; }
    done
    [ $found = yes ] || echo "extension: not installed"
    if [ -f "$CHROME_DIR/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json" ]; then
      echo "claude code link: present"
    else
      echo "claude code link: missing (Claude Code adds it the first time it starts with --chrome; Chrome needs a restart after)"
    fi
    ;;

  pane)
    case ${2:-} in
      files)         anchor=Privacy_AllFiles ;;
      accessibility) anchor=Privacy_Accessibility ;;
      screen)        anchor=Privacy_ScreenCapture ;;
      automation)    anchor=Privacy_Automation ;;
      *) echo "pane must be files, accessibility, screen or automation" >&2; exit 1 ;;
    esac
    open "x-apple.systempreferences:com.apple.preference.security?$anchor"
    ;;

  fda)  # these folders are only readable with Full Disk Access
    if ls "$HOME/Library/Safari" >/dev/null 2>&1 || ls "$HOME/Library/Mail" >/dev/null 2>&1; then
      echo "full disk access: on"
    else
      echo "full disk access: off (or not active until Ghostty is quit and reopened)"
    fi
    ;;

  *) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
