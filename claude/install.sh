#!/bin/sh
#
# claude
#
# Bootstrap only symlinks to $HOME/.<name>, but this script's file needs to
# live at ~/.claude/hooks/usage-statusline.js, and the Claude Code settings.json
# it's wired into is a live file Claude Code itself writes to — so this links
# the script in and idempotently patches just the statusLine key, leaving the
# rest of settings.json (hooks, plugins, autoMode, ...) alone.

set -e

SRC="$HOME/.dotfiles/claude/usage-statusline.js"
DST="$HOME/.claude/hooks/usage-statusline.js"

mkdir -p "$(dirname "$DST")"

if [ -L "$DST" ] && [ "$(readlink "$DST")" = "$SRC" ]; then
  echo "  usage-statusline.js already linked"
else
  [ -e "$DST" ] && mv "$DST" "$DST.backup"
  ln -s "$SRC" "$DST"
  echo "  usage-statusline.js linked"
fi

node -e "
const fs = require('fs');
const path = '$HOME/.claude/settings.json';
const command = 'node \"$DST\"';
let settings = {};
if (fs.existsSync(path)) {
  settings = JSON.parse(fs.readFileSync(path, 'utf8'));
}
if (settings.statusLine && settings.statusLine.command === command) {
  console.log('  statusLine already set');
} else {
  settings.statusLine = { type: 'command', command };
  fs.mkdirSync(require('path').dirname(path), { recursive: true });
  fs.writeFileSync(path, JSON.stringify(settings, null, 2) + '\n');
  console.log('  statusLine set in settings.json');
}
"
