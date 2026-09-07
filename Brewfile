# Brewfile — reproduces this machine's toolchain.
#
#   brew bundle --file ~/.dotfiles/Brewfile
#
# Regenerated 2026-09-07 from what is actually installed. The previous version
# was stale: 28 of its 38 entries were not present on this machine at all.
#
# Homebrew must be the native ARM build at /opt/homebrew. The Intel build at
# /usr/local is unsupported as of September 2026 and cannot install anything.

cask_args appdir: '/Applications'

tap 'sandsower/tap'
tap 'warrensbox/tap'
tap 'oddur/gnosis'

# ── Shell and CLI ──────────────────────────────────────────────────
brew 'autojump'                   # jump to frequent directories
brew 'awscli'                     # 10 configured profiles, SSO to work accounts
brew 'gh'                         # GitHub CLI
brew 'git'                        # newer than Xcode's
brew 'htop'
brew 'nmap'
brew 'shellcheck'
brew 'tmux'                       # the worksetup depends on this
brew 'watch'
brew 'worktrunk'                  # wt / wts worktree management
brew 'sandsower/tap/memento-vault'

# ── Containers ─────────────────────────────────────────────────────
# Docker Desktop replaced by colima: same docker CLI, lightweight Linux VM,
# Apache-2.0, no licensing questions. `colima start` boots the daemon.
brew 'colima'
brew 'docker'                     # CLI only; colima provides the daemon
brew 'docker-compose'
brew 'docker-credential-helper'   # osxkeychain helper, independent of Desktop

# ── Languages and package managers ─────────────────────────────────
brew 'node@22'
brew 'pnpm'
brew 'pyenv'

# ── Apps ───────────────────────────────────────────────────────────
cask 'gcloud-cli'
cask 'gnosis'
cask 'kitty'                      # the worksetup depends on this
cask 'tfswitch'

# Deliberately not listed:
#   fonts          — avoid reinstalling powerline/nerd fonts on a new machine
#   adoptopenjdk   — deprecated cask (now Temurin), no JDK in use
#   docker-desktop — replaced by colima (see Containers above)
#   gnosis         — removed; AI code-review app, never launched
