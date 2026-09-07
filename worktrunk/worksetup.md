# Parallel worksetup — kitty + tmux + worktrunk

One kitty pane per workstream. Each pane holds one tmux session. Each tmux
session lives in its own git worktree on its own branch. `Cmd+Shift+Enter`
blows the focused pane up to full screen and back.

---

## The mental model

Three layers, each with exactly one job. When something breaks, work out which
layer it is first — that alone solves most confusion.

| Layer | Job | You lose it when |
|---|---|---|
| **kitty** | What's on screen — splits, zoom, tabs | Never; it's just a view |
| **tmux** | Persistence — sessions outlive the terminal | Only on reboot |
| **worktrunk** | One checkout per branch, isolated | Only when you `wt remove` |

The important consequence: **closing kitty does not stop your work.** The tmux
sessions keep running. Reopen kitty, `tmux attach`, and everything is where you
left it — agents mid-run included.

### Vocabulary (this trips everyone up)

kitty does not use iTerm2's words:

| iTerm2 | kitty | What it is |
|---|---|---|
| pane | **window** | A split region |
| tab | tab | A set of splits |
| window | **OS window** | The actual macOS window |

So "kitty window" = "iTerm2 pane". This doc says **pane** throughout and means
the kitty thing.

---

## Daily flow

**1. Open kitty and split into as many panes as you want workstreams.**

```
fn+F5   split below      (or Cmd+Shift+D)
fn+F6   split right      (or Cmd+D)
```

**2. In each pane, start a workstream:**

```bash
wts arnlaugsson/fut-590-fix-the-thing
```

That single command:
- creates the branch and its worktree (or switches to it if it already exists)
- `cd`s you into the worktree
- creates a tmux session named after the branch, rooted there
- greets you with a cow and a quote
- attaches you to it

**3. Start working.** You're in a plain shell in the worktree. Type `claude`,
then `/kickoff FUT-590` to pull the ticket per this repo's beislid workflow.

**4. Zoom when you need to concentrate.**

```
Cmd+Shift+Enter    focused pane fills the screen — press again to restore
```

Do this constantly. It's the whole point of the layout: four agents visible for
triage, one agent full-screen when you actually engage with it.

---

## Keyboard reference

### kitty — matches iTerm2

| Action | Keys |
|---|---|
| **Maximize / restore focused pane** | **Cmd+Shift+Enter** |
| Split right | Cmd+D *or* fn+F6 |
| Split below | Cmd+Shift+D *or* fn+F5 |
| Move focus by direction | Cmd+Opt+← ↑ ↓ → |
| Cycle panes | Cmd+[ / Cmd+] |
| Move the pane itself | Cmd+Shift+← ↑ ↓ → |
| Close the focused pane | Cmd+W *or* Ctrl+Shift+W |
| New tab / tab N | Cmd+T / Cmd+1..9 |
| Next / previous tab | Cmd+Shift+] / Cmd+Shift+[ |
| Reload kitty config | Ctrl+Cmd+, |

The focused pane is full-brightness with a blue border; unfocused panes dim to
75%. That's how you find the agent that just asked you a question.

### tmux — prefix is Ctrl-b

You mostly don't need these. They matter when you split *inside* one workstream
(agent in one pane, test watcher in another).

| Action | Keys |
|---|---|
| Zoom a tmux pane | Ctrl-b `z` |
| Split inside the session | Ctrl-b `%` (right) / Ctrl-b `"` (below) |
| Move between tmux panes | Ctrl-b `h` `j` `k` `l` |
| Resize tmux pane | Ctrl-b `H` `J` `K` `L` (repeatable) |
| New window / next | Ctrl-b `c` / Ctrl-b `n` |
| **Session picker** | Ctrl-b `s` |
| Detach (leave it running) | Ctrl-b `d` |
| Reload tmux config | Ctrl-b `r` |
| Save session state now | Ctrl-b `Ctrl-s` |
| Restore saved state | Ctrl-b `Ctrl-r` |

### The two zoom levels

This is the one genuinely confusing bit:

- **Cmd+Shift+Enter** maximizes a **kitty pane** — one entire workstream.
- **Ctrl-b z** maximizes a **tmux pane** *inside* that workstream.

They nest and don't interfere. If you never split inside a session, you only
ever need Cmd+Shift+Enter.

---

## `wts` reference

```bash
wts arnlaugsson/fut-590-new-thing   # new branch  -> creates it
wts arnlaugsson/fut-506-bug-msg     # exists      -> switches, reattaches
wts                                 # no arg      -> worktrunk's picker
wts ^                               # default branch
wts -                               # previous
wts pr:412                          # a GitHub PR
```

It auto-detects: `--create` is only passed when the branch doesn't already
exist locally or on `origin`. Running it twice on the same branch just
reattaches — safe to spam.

`ws` and `wsc` are untouched and still plain worktrunk, no tmux.

### Session names

The session is the **full branch name**, sanitised (tmux rejects `.` and `:`):

```
arnlaugsson/fut-506-bug-message  ->  arnlaugsson-fut-506-bug-message
```

Because that's unreadable in a status bar, `wts` also stores a short label
(`fut-506`, extracted from the ticket id) as the session option `@short`, and
the status bar shows that instead. The full name is on the right-hand side.

---

## Recovery

**"I closed kitty / my laptop slept / the terminal crashed."**
Nothing was lost.
```bash
tmux ls              # what's still running
tmux attach -t <name>
```
Or just `wts <branch>` again — it reattaches.

**"I rebooted."**
Just start tmux — it restores itself. State is auto-saved every 15 minutes and
restored the next time a tmux server starts.
```bash
tmux                 # sessions come back on their own
```
What comes back: sessions, names, window layouts, working directories and
scrollback. What does **not**: running processes. Your agents are not mid-run —
`cd` is already right, so `claude --continue` picks the conversation back up.

**"I want to see all my sessions."** Ctrl-b `s` — arrow keys, Enter.

**"`wts` says worktrunk did not change directory."**
Shell integration is inactive. This guard exists so you don't get a session
named `main` while thinking you're on your ticket.
```bash
wt config shell install
exec zsh
```

**"`wts: command not found`."** New shell needed: `exec zsh`.

**"Wrong branch in this session."** Sessions are pinned to the worktree they
were created in. Don't `git checkout` inside one — kill it and `wts` the right
branch.

**Finishing a workstream:**
```bash
wt remove                                    # worktree + branch if merged
tmux kill-session -t <full-session-name>     # tmux won't clean up by itself
```

---

## Gotchas

- **`Cmd+Shift+D` normally closes a pane in kitty.** We override it to "split
  below" for iTerm2 parity. The override works because it's the last definition
  in `kitty.conf` — if you ever reorder that file, you'll start closing panes
  instead of splitting them. Closing a pane is `Cmd+W`.
- **Nothing on the keyboard closes more than one pane.** Stock kitty puts
  `close_tab` on `Cmd+W` and `close_os_window` on `Cmd+Shift+W`. Both are
  tab-wide or wider, and every workstream here is a pane in a *single* tab — so
  either one ends every workstream at once, behind a "close this tab?" prompt
  that sounds far smaller than what it does. So `Cmd+W` closes the focused pane
  and `Cmd+Shift+W` does nothing; a tab still closes on its own once its last
  pane goes. `Cmd+W` asks first when a command is running in the pane and
  closes silently at a bare shell prompt; `Ctrl+Shift+W` is the same close
  without the prompt. `Cmd+Q` still quits kitty — harmless, since that ends the
  view, not the tmux sessions.
- **Killing a chord takes `discard_event`, not a bare `map`.** A bare
  `map cmd+shift+w` *unbinds* it, which hands the keypress to the program
  instead of eating it — and the shell then echoes `9;10u`, the tail of kitty's
  keyboard-protocol escape for that chord (`ESC [ 119 ; 10 u`: 119 is `w`, 10 is
  cmd+shift). `discard_event` swallows it properly.
- **`fn+F5`/`F6` inherit the current directory only outside tmux.** Inside a
  tmux session kitty can only see tmux's own directory. Doesn't matter in
  practice — you run `wts` next, which `cd`s you anyway.
- **A reboot restores the shape of your work, not the work itself.** resurrect
  brings back sessions, layouts, directories and scrollback. It does not restart
  processes — no agent resumes on its own. Treat a reboot as "my desk is laid out
  again", not "nothing happened".
- **Session labels are rebuilt by a hook, not by resurrect.** resurrect doesn't
  save custom session options, so `@short` is re-derived on `session-created` by
  `tmux-session-label`. If labels ever go long after a restore, that script is
  what to check.

---

## Where the config lives

Everything is tracked in `~/.dotfiles` and restores on a fresh machine with
`script/bootstrap` alone: it symlinks the `*.symlink` files, then hands off to
`dot`, which sets the macOS defaults, installs the `Brewfile` (kitty and tmux
included) and runs every topic's `install.sh`. `kitty/install.sh` is the one
that appends the `include` line to `~/.config/kitty/kitty.conf`.

| Tracked file | Lands at | What |
|---|---|---|
| `tmux/tmux.conf.symlink` | `~/.tmux.conf` | tmux settings, status bar, plugins |
| `kitty/worksetup.conf` | included by `~/.config/kitty/kitty.conf` | All bindings + `enabled_layouts` |
| `worktrunk/aliases.zsh` | sourced by `~/.zshrc` | The `wts` function |
| `worktrunk/worksetup.md` | `~/.config/worksetup.md` | This file |
| `bin/wts-greet` | on `$PATH` | The cow |
| `bin/tmux-session-label` | on `$PATH` | Rebuilds `@short` after a restore |

Not tracked, and fine that way: `~/.tmux/plugins/` (tpm clones these itself) and
`~/.config/kitty/kitty.conf` (kitty's own defaults; only the one `include` line
at the end is ours, added by `kitty/install.sh`).

Backups of the originals: `~/.config/kitty/kitty.conf.bak-*`, `~/.tmux.conf.bak-*`

## Optional upgrades

Not installed; add if you want them.

```bash
brew install cowsay        # wts-greet uses the real cowsay if present
brew install fortune       # not wired in; wts-greet has its own quotes
```

**Reboot survival is installed and on.** `tpm` + `tmux-resurrect` +
`tmux-continuum`, auto-saving every 15 minutes and auto-restoring when tmux next
starts. To add another plugin: put a `set -g @plugin '...'` line above the final
`run` line in `~/.tmux.conf`, then press Ctrl-b `I`.

Run the cow whenever you like: `wts-greet fut-506`
