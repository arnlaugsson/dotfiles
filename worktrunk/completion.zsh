# Tab-complete `wtd` with the branches of linked worktrees (never the main one).
_wtd() {
  local -a branches
  branches=(${(f)"$(git worktree list --porcelain 2>/dev/null \
    | awk '/^worktree /{n++} n>1 && sub(/^branch refs\/heads\//, "")')"})
  _arguments \
    '-D[delete the branch even if unmerged]' \
    '*:worktree branch:compadd -a branches'
}
compdef _wtd wtd
