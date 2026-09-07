# dotfiles

My macOS setup: zsh, git, kitty, tmux, and a worktree-per-branch workflow for
running several coding agents side by side.

Forked from [holman/dotfiles](https://github.com/holman/dotfiles). The topical
layout and the bootstrap scripts are his.

## Install

    git clone git@github.com:arnlaugsson/dotfiles.git ~/.dotfiles
    cd ~/.dotfiles
    script/bootstrap

That symlinks every `*.symlink` file into `$HOME`, asks for a git name and email
the first time, and then hands off to `dot`. Safe to re-run.

`dot` is also the maintenance command: it pulls this repo, applies the macOS
defaults in `macos/`, installs Homebrew if it's missing, upgrades what's there,
installs everything in the `Brewfile`, and runs each topic's `install.sh`. Worth
running every couple of months.

## Layout

One directory per topic, loaded by filename rather than by a central list:

    *.zsh            sourced at shell startup
    path.zsh         sourced first, sets up $PATH
    completion.zsh   sourced last
    *.symlink        symlinked into $HOME without the extension
    install.sh       run by script/install
    bin/             on $PATH

Adding a tool means adding a directory, not editing a loader.

The part worth reading on its own is the parallel setup in `kitty/`, `tmux/` and
`worktrunk/`: one terminal pane per workstream, each holding a tmux session in
its own git worktree. See [worktrunk/worksetup.md](worktrunk/worksetup.md).

---

Drafted with the help of Claude.
