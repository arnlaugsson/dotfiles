#!/bin/sh
#
# vim
#
# vimrc.symlink declares plugins via Vundle, but Vundle itself lives in
# ~/.vim/bundle and is not tracked here. Without this, vim throws errors on
# every startup on a fresh machine.

set -e

BUNDLE="$HOME/.vim/bundle/Vundle.vim"

if [ -d "$BUNDLE" ]; then
  echo "  Vundle already installed"
else
  git clone --depth 1 https://github.com/VundleVim/Vundle.vim.git "$BUNDLE"
  echo "  Vundle cloned"
fi

# Non-interactive plugin install; harmless if they are already present.
if vim +PluginInstall +qall </dev/null >/dev/null 2>&1; then
  echo "  vim plugins installed"
else
  echo "  run :PluginInstall inside vim to finish"
fi
