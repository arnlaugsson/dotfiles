# worktrunk + tmux: one tmux session per worktree/branch.
#
# `ws` and `wsc` (see zsh/aliases.zsh) stay plain worktrunk — no tmux.
# `wts` is the parallel-agent driver: worktree + dedicated tmux session.
#
#   wts fut-590-new-thing        branch is new  -> wt switch --create
#   wts arnlaugsson/fut-506-bug  branch exists  -> wt switch
#   wts                          no arg         -> worktrunk's picker
#   wts FUT-672                  ticket id      -> its branch: an existing local/origin
#                                                  branch for the ticket, else Linear's
#                                                  gitBranchName (needs LINEAR_API_KEY,
#                                                  e.g. exported from ~/.localrc)
#
# Session name is the full branch, sanitised for tmux (which rejects "." and ":").
# A short label (e.g. fut-506) is stashed on the session as @short for the
# status bar; see ~/.tmux.conf.

# Print the branch for a ticket id (FUT-672). A branch that already exists wins,
# so resuming work never depends on Linear (or on its name never having changed).
# Only a branch with a slug after the id counts: a bare `FUT-999` branch is the
# leftover of a `wts FUT-999` run before this resolver existed, never real work.
_wts_ticket_branch() {
  emulate -L zsh
  local id=${(L)1}

  local -a found
  found=(${(u)${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin 2>/dev/null \
    | sed 's#^origin/##' | grep -iE "(^|/)${id}-")"}})
  if (( $#found == 1 )); then
    print -r -- $found[1]; return 0
  elif (( $#found > 1 )); then
    print -u2 "wts: several branches match ${(U)id} — pass one explicitly:"
    print -u2 -l -- "  "${^found}
    return 1
  fi

  [[ -n $LINEAR_API_KEY ]] || {
    print -u2 "wts: no branch for ${(U)id} yet and LINEAR_API_KEY is unset — export it (e.g. in ~/.localrc) or pass the branch name"
    return 1
  }
  local resp name
  resp=$(curl -fsS --max-time 10 https://api.linear.app/graphql \
    -H 'Content-Type: application/json' -H "Authorization: $LINEAR_API_KEY" \
    -d "{\"query\":\"{ issue(id: \\\"${(U)id}\\\") { branchName } }\"}") || {
    print -u2 "wts: Linear request failed for ${(U)id}"; return 1
  }
  name=$(print -r -- "$resp" | jq -r '.data.issue.branchName // empty')
  [[ -n $name ]] || {
    print -u2 "wts: Linear has no branch name for ${(U)id}: $(print -r -- "$resp" | jq -c '.errors // .' 2>/dev/null)"
    return 1
  }
  print -r -- $name
}

wts() {
  emulate -L zsh
  setopt local_options

  # A bare ticket id (FUT-672, fut-672) stands for that ticket's branch.
  if [[ $1 =~ '^[A-Za-z]+-[0-9]+$' ]]; then
    local resolved
    resolved=$(_wts_ticket_branch "$1") || return $?
    print -u2 "wts: ${(U)1} -> $resolved"
    set -- "$resolved" "${@:2}"
  fi

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

  # A tmux server inherits the cwd of whatever started it. If the first `wts` of
  # the day starts it, the server is rooted in that worktree -- and once the
  # worktree is removed the server's cwd dangles, after which tmux silently
  # ignores -c and every new session starts in a deleted directory (the shell
  # lands with PWD=. and `claude` refuses to launch). Root it in $HOME instead.
  if ! tmux has-session 2>/dev/null; then
    (builtin cd -- "$HOME" && tmux start-server)
  fi

  if ! tmux has-session -t "=$session" 2>/dev/null; then
    # New work: greet with a cow. Degrades silently if the script is missing.
    local greet=$HOME/.dotfiles/bin/wts-greet
    local cmd="exec ${(q)${SHELL:-/bin/zsh}} -l"
    [[ -x $greet ]] && cmd="${(q)greet} ${(q)short} ${(q)branch_now}; $cmd"

    # `-c` alone is not enough. If the server's own cwd is an *unlinked* inode --
    # which it is as soon as a worktree it was rooted in gets removed and a later
    # `wsc` recreates a directory at the same path -- the server cannot place the
    # new pane and the shell simply inherits that dangling cwd: PWD=".", getcwd()
    # failing, every relative path and `claude` broken until you `cd ..; cd back`.
    # cd ourselves, from inside the pane, where an absolute path always resolves.
    cmd="cd -- ${(q)dir} || exit 1; $cmd"

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

# wtd ("worktree done"): close down the worktree you are standing in, from inside it.
#
#   wtd            remove this worktree, its tmux session and its test container
#   wtd -D         ... and delete the branch even if unmerged (passed through to wt remove)
#   wtd <branch>…  remove other worktrees instead (tab-completes; see completion.zsh)
#
# `wt remove` cannot remove the worktree you are in, and its post-remove hook
# kills the `wts` session — which, with tmux's default detach-on-destroy, would
# throw you out of tmux entirely. So: hop the client to the session sitting in
# the main worktree first, then run the removal in a popup there, where its
# output (including a blocking pre-remove inventory) stays readable.
wtd() {
  emulate -L zsh

  local -a flags targets
  local a
  for a in "$@"; do
    if [[ $a == -* ]]; then flags+=$a; else targets+=$a; fi
  done

  local dir main branch
  dir=$(git rev-parse --show-toplevel 2>/dev/null) || { print -u2 "wtd: not in a git worktree"; return 1 }
  main=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
  branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null)

  # Named worktrees other than this one: nothing to hop away from, so remove
  # them right here. Naming this one too would kill the session mid-command.
  if (( $#targets )) && [[ $targets != $branch ]]; then
    if [[ $dir != $main ]] && (( ${targets[(Ie)$branch]} )); then
      print -u2 "wtd: '$branch' is the worktree you are in — remove it on its own with plain wtd"
      return 1
    fi
    wt -C "$main" remove --reap --foreground --yes "${flags[@]}" "${targets[@]}"
    return $?
  fi

  [[ $dir != $main ]] || { print -u2 "wtd: $dir is the main worktree — nothing to remove"; return 1 }
  [[ -n $branch ]] || { print -u2 "wtd: HEAD is detached in $dir — run wt remove by hand"; return 1 }

  # Fail here, visibly, rather than inside a popup after you have left the session.
  if [[ -n $(git -C "$dir" status --porcelain) ]]; then
    print -u2 "wtd: $dir has uncommitted changes — commit, stash elsewhere, or wt remove -f by hand"
    return 1
  fi

  local cmd="wt -C ${(q)main} remove --reap --foreground --yes ${(q@)flags} ${(q)branch}"

  if [[ -z $TMUX ]]; then
    builtin cd -- "$main" && eval "$cmd"
    return $?
  fi

  # Anything else still running in this session dies with it. Say so first.
  local here=${TMUX_PANE} session
  session=$(tmux display-message -p -t "$here" '#{session_name}')
  local busy
  busy=$(tmux list-panes -s -t "=$session" -F '#{pane_id} #{window_index}.#{pane_index} #{pane_current_command}' \
    | awk -v me="$here" '$1 != me && $3 !~ /^-?(zsh|bash|sh|fish)$/ { print "  " $2 "  " $3 }')
  if [[ -n $busy ]]; then
    print "wtd: these will be killed with session $session:"
    print -r -- "$busy"
    read -q "?Continue? [y/N] " || { print; return 1 }
    print
  fi

  # The session to land in: `main` if it exists. Matching on a pane's path is a
  # poor first choice — any worktree session can have a window cd'd into main.
  local target
  if [[ $session != main ]] && tmux has-session -t '=main' 2>/dev/null; then
    target=main
  else
    target=$(tmux list-panes -a -F '#{session_name}	#{pane_current_path}' \
      | awk -F '\t' -v m="$main" -v s="$session" '$2 == m && $1 != s { print $1; exit }')
  fi
  if [[ -z $target ]]; then
    target=${${main:t}//[^a-zA-Z0-9_-]/-}
    tmux new-session -d -s "$target" -c "$main" "cd -- ${(q)main} || exit 1; exec ${(q)${SHELL:-/bin/zsh}} -l" || return $?
  fi

  local client
  client=$(tmux display-message -p '#{client_name}')
  tmux switch-client -c "$client" -t "=$target" || return $?

  # On success the popup closes itself; on failure it waits so you can read why.
  tmux display-popup -c "$client" -E -w 90% -h 60% -d "$main" -T " wtd: $branch " \
    "$cmd; rc=\$?; if [ \$rc -eq 0 ]; then sleep 2; else printf '\\nwt remove failed (exit %s) — press any key' \$rc; read -r _; fi"
}
