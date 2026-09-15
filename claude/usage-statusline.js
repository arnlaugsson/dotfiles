#!/usr/bin/env node
// Claude Code statusline: model | ticket + branch slug | context-remaining bar
// Context percentage is the real value Claude Code reports (context_window.remaining_percentage),
// not rescaled — 0% here means the actual limit, not GSD's 80%-scaled "100%".
// Branch names are worktree-style "<user>/fut-123-some-long-description"; the directory is the
// worktree path (also long and redundant with the branch), so both get collapsed to "FUT-123 some-long-description".

const { execSync } = require('child_process');

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const model = data.model?.display_name || 'Claude';
    const dir = data.workspace?.current_dir || data.cwd || process.cwd();
    const remaining = data.context_window?.remaining_percentage;

    const dim = s => `\x1b[2m${s}\x1b[0m`;
    const green = s => `\x1b[1;32m${s}\x1b[0m`;
    const red = s => `\x1b[1;31m${s}\x1b[0m`;
    const magenta = s => `\x1b[1;35m${s}\x1b[0m`;
    const cyan = s => `\x1b[1;36m${s}\x1b[0m`;

    // --- git branch → "FUT-123 short-slug", dirty/unpushed ---
    let gitPart = '';
    try {
      const branch = execSync('git symbolic-ref --short HEAD', { cwd: dir, stdio: ['ignore', 'pipe', 'ignore'] })
        .toString().trim();
      if (branch) {
        const withoutUser = branch.includes('/') ? branch.slice(branch.indexOf('/') + 1) : branch;
        const ticketMatch = withoutUser.match(/^([a-z]+-\d+)-(.+)$/i);

        const dirty = execSync('git status --porcelain', { cwd: dir, stdio: ['ignore', 'pipe', 'ignore'] })
          .toString().trim().length > 0;
        const slugColor = dirty ? red : green;

        if (ticketMatch) {
          const ticket = ticketMatch[1].toUpperCase();
          const slug = ticketMatch[2];
          gitPart = `${cyan(ticket)} ${slugColor(slug)}`;
        } else {
          gitPart = slugColor(withoutUser);
        }

        try {
          const unpushed = parseInt(
            execSync(`git cherry -v origin/${branch}`, { cwd: dir, stdio: ['ignore', 'pipe', 'ignore'] })
              .toString().trim().split('\n').filter(Boolean).length,
            10
          );
          if (unpushed > 0) gitPart += ` ${magenta(unpushed + ' unpushed')}`;
        } catch (e) { /* no upstream — skip */ }
      }
    } catch (e) { /* not a git repo — skip */ }

    // --- context-remaining bar (real percentage) ---
    let ctxPart = '';
    if (remaining != null) {
      const rem = Math.max(0, Math.min(100, Math.round(remaining)));
      const filled = Math.round((10 - rem / 10));
      const bar = '█'.repeat(Math.max(0, 10 - filled)) + '░'.repeat(Math.max(0, filled));
      let colorFn;
      if (rem > 50) colorFn = green;
      else if (rem > 25) colorFn = s => `\x1b[1;33m${s}\x1b[0m`;
      else if (rem > 10) colorFn = s => `\x1b[1;38;5;208m${s}\x1b[0m`;
      else colorFn = red;
      ctxPart = colorFn(`${bar} ${rem}% ctx left`);
    }

    const parts = [dim(model), gitPart, ctxPart].filter(Boolean);
    process.stdout.write(parts.join(' \x1b[2m│\x1b[0m '));
  } catch (e) {
    // Silent fail — never break the statusline on a parse/exec error.
  }
});
