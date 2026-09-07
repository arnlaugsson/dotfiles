# ./bin was removed from PATH deliberately: a relative entry means cd'ing into
# any repo with a bin/ directory lets it shadow real commands.
#
# /usr/local/bin and /usr/local/sbin are no longer prepended either — they come
# from /etc/paths already, and prepending them here put the old Intel Homebrew
# ahead of the native one in homebrew/path.zsh.
export PATH="$ZSH/bin:$PATH"

export MANPATH="/usr/local/man:/usr/local/git/man:$MANPATH"
