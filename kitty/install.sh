#!/bin/sh
#
# kitty
#
# Bootstrap only symlinks to $HOME/.<name>, but kitty wants its config at
# ~/.config/kitty/kitty.conf. So instead of symlinking, make sure that file
# pulls in our tracked block. Must be the LAST line: the bindings in
# worksetup.conf override kitty's defaults by position.

set -e

CONF="$HOME/.config/kitty/kitty.conf"
LINE="include ~/.dotfiles/kitty/worksetup.conf"

mkdir -p "$(dirname "$CONF")"
touch "$CONF"

if grep -qF "$LINE" "$CONF"; then
  echo "  kitty worksetup already included"
else
  printf '\n# Parallel-agent worksetup, tracked in ~/.dotfiles/kitty/worksetup.conf\n# Must stay LAST: these bindings override kitty defaults by position.\n%s\n' "$LINE" >> "$CONF"
  echo "  kitty worksetup include added"
fi
