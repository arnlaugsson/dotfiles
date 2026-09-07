#!/bin/sh
#
# worktrunk
#
# The worksetup runbook is tracked here but read from ~/.config.

set -e

SRC="$HOME/.dotfiles/worktrunk/worksetup.md"
DST="$HOME/.config/worksetup.md"

mkdir -p "$(dirname "$DST")"

if [ -L "$DST" ]; then
  echo "  worksetup.md already linked"
else
  [ -e "$DST" ] && mv "$DST" "$DST.backup"
  ln -s "$SRC" "$DST"
  echo "  worksetup.md linked"
fi
