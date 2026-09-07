# Native ARM Homebrew at /opt/homebrew.
#
# `brew shellenv` sets PATH, MANPATH, INFOPATH and the HOMEBREW_* vars, which is
# more complete than prepending bin by hand. This lives in a path.zsh so it runs
# in zshrc's first (path) pass, before the rest of the config.
#
# /usr/local/bin still reaches PATH via /etc/paths, so an Intel Homebrew there
# keeps working as a fallback — just at lower precedence than the native one.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
fi
