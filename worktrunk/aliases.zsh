# worktrunk + tmux: one tmux session per worktree/branch.
#
# `ws` and `wsc` (see zsh/aliases.zsh) stay plain worktrunk — no tmux.
# `wts` is the parallel-agent driver: worktree + dedicated tmux session.
#
#   wts fut-590-new-thing        branch is new  -> wt switch --create
#   wts arnlaugsson/fut-506-bug  branch exists  -> wt switch
#   wts                          no arg         -> worktrunk's picker
#
# Session name is the full branch, sanitised for tmux (which rejects "." and ":").
# A short label (e.g. fut-506) is stashed on the session as @short for the
# status bar; see ~/.tmux.conf.

wts() {
  emulate -L zsh
  setopt local_options

  local branch=$1
  local is_shortcut=0
  local -a wt_args

  # Worktrunk's own shortcuts and the no-arg picker must never get --create.
  if [[ -z $branch ]] || [[ $branch == (\^|-|@) ]] || [[ $branch == (pr|mr):* ]]; then
    is_shortcut=1
  fi

  if (( is_shortcut )) \
     || git rev-parse --verify --quiet "refs/heads/$branch" >/dev/null 2>&1 \
     || git rev-parse --verify --quiet "refs/remotes/origin/$branch" >/dev/null 2>&1; then
    wt_args=(switch "$@")
  else
    wt_args=(switch --create "$@")
  fi

  # `wt` is a shell function (defined in ~/.zshrc): it sources a directive file
  # to cd us into the worktree. Must be called as a function, not `command wt`.
  local before=$PWD
  wt "${wt_args[@]}" || return $?

  local dir=$PWD
  local branch_now
  branch_now=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    print -u2 "wts: $dir is not a git worktree — no session created"
    return 1
  }

  # Guard: if worktrunk could not cd us ("shell requires restart"), we are still
  # sitting on the old branch. Without this we would open a session named after
  # main, rooted in the main repo, while you believe you are on your ticket.
  if [[ $dir == $before ]] && (( ! is_shortcut )) && [[ $branch_now != $branch ]]; then
    print -u2 "wts: still on '$branch_now' in $dir — worktrunk did not change directory."
    print -u2 "     Shell integration looks inactive. Run 'wt config shell install',"
    print -u2 "     restart your shell, and try again. No tmux session created."
    return 1
  fi

  local session
  session=$(print -r -- "$branch_now" \
    | sed -E 's/[^a-zA-Z0-9_-]+/-/g; s/-+/-/g; s/^-+//; s/-+$//')
  [[ -n $session ]] || { print -u2 "wts: could not derive a session name"; return 1 }

  # Short label for the status bar: the ticket id if the branch carries one.
  local short=$session
  [[ $branch_now =~ '([A-Za-z]+-[0-9]+)' ]] && short=${(L)match[1]}

  if ! tmux has-session -t "=$session" 2>/dev/null; then
    # New work: greet with a cow. Degrades silently if the script is missing.
    local greet=$HOME/.dotfiles/bin/wts-greet
    local cmd="exec ${(q)${SHELL:-/bin/zsh}} -l"
    [[ -x $greet ]] && cmd="${(q)greet} ${(q)short} ${(q)branch_now}; $cmd"

    tmux new-session -d -s "$session" -c "$dir" "$cmd" || return $?
    # NB: set-option rejects the "=" exact-match prefix that has-session accepts.
    # Bare name is still an exact match (tmux tries exact before prefix).
    tmux set-option -t "$session" @short "$short"
  fi

  if [[ -n $TMUX ]]; then
    tmux switch-client -t "=$session"
  else
    tmux attach-session -t "=$session"
  fi
}
