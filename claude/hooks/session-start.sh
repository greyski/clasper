#!/bin/bash
# Clasper SessionStart hook. Whatever this prints is added to Claude's
# context at the start of the session. It says whether this person has been
# set up yet and lists their project folders so "open <name>" works at once.
#
# Rules: fast, no network, bash 3.2, and never fail the session.

# The JSON Claude Code sends on stdin isn't needed; drain it without blocking.
[ -t 0 ] || cat >/dev/null 2>&1

# Resolve the suite from this script's real location (it may be a symlink).
src=$0
while [ -L "$src" ]; do
  dir=$(cd -P "$(dirname "$src")" 2>/dev/null && pwd)
  src=$(readlink "$src")
  case $src in /*) ;; *) src=$dir/$src ;; esac
done
suite=$(cd -P "$(dirname "$src")/../.." 2>/dev/null && pwd)

if [ -n "$suite" ] && [ ! -f "$suite/local/profile.md" ]; then
  echo "Clasper: this person has not been set up yet (no $suite/local/profile.md). Run the clasper-setup skill first, before anything else."
fi

projects=$HOME/claude/projects
if [ -d "$projects" ]; then
  # Most recently changed first, so the cap drops the stale ones.
  names=""
  n=0
  more=0
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    if [ $n -lt 20 ]; then
      name=${d%/}
      name=${name##*/}
      names="$names${names:+, }$name"
      n=$((n + 1))
    else
      more=$((more + 1))
    fi
  done <<EOF
$(cd "$projects" 2>/dev/null && ls -dt -- */ 2>/dev/null)
EOF
  if [ $n -gt 0 ]; then
    [ $more -gt 0 ] && names="$names (+$more more)"
    echo "Project folders in ~/claude/projects (most recent first): $names"
  else
    echo "Project folders in ~/claude/projects: none yet"
  fi
fi

exit 0
