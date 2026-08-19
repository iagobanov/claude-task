# claude-task

Run several Claude Code sessions at once without them fighting over your repo.

Seven zsh functions (`ct` and friends). One task = one git worktree = one branch =
one session = one notes file. No daemon, no config file, no dependencies beyond
git and zsh.

```bash
cd ~/Projects/my-api
ct add-rate-limiting     # worktree + branch + notes, opens Claude in it
```

Open a second terminal, do it again with a different slug, and the two sessions
never touch each other's working tree.

## Install

```bash
git clone https://github.com/iagobanov/claude-task ~/.claude-task
echo '[[ -r ~/.claude-task/ct.zsh ]] && source ~/.claude-task/ct.zsh' >> ~/.zshrc
```

Reload your shell and run `ct --help`. Tasks land in `$CT_ROOT`
(default `~/Projects/claude`); clones are looked for under `$CT_PROJECTS`
(default `~/Projects`). Set either before sourcing if you want them elsewhere.

## The idea

Running two Claude sessions in one checkout means two agents editing the same
files on the same branch. Worktrees fix that at the git level: each task gets its
own directory and its own branch, so sessions are genuinely parallel.

The second half is the notes. Code lands in git history; the reasoning, the dead
ends, the "we already tried that" — those die with the session. So every task
also gets a `NOTES.md` that **outlives the worktree**. Delete the checkout, keep
what you learned.

```
$CT_ROOT/
├── tasks/
│   └── 2026-08-19-add-rate-limiting/
│       ├── NOTES.md      # survives everything
│       └── scratch/      # throwaway
└── worktrees/
    └── my-api/
        └── add-rate-limiting/   # the checkout, .task symlinks back to notes
```

## Commands

| Command | What it does |
|---|---|
| `ct [slug]` | Start or resume a task. In a repo: worktree + branch + notes. Outside one: notes only. No slug: `session-HHMM`. |
| `cta <repo> [dest]` | Attach a repo to a task that started without one. Clones if needed, reuses an existing clone if it finds one. |
| `ctn [text]` | Append a timestamped note to the current task. No text opens `$EDITOR`. |
| `ctmv <slug>` | Rename the current task. |
| `ctcd` | `cd` to the current task's notes. |
| `ctls` | Every task, newest first, with its repo and whether the worktree is still live. |
| `ctrm <slug>` | Remove that slug's worktree. Notes survive. |

Every one takes `-h`.

## Two things that make it usable

**You don't have to know where the work goes yet.** `ct` outside a repo gives you
a notes-only task and opens a session. Turns out there's code involved? `cta
org/repo` attaches it later. Plenty of work — debugging someone else's cluster,
reading docs, poking an API — never needs a branch at all.

**`ctn` works from anywhere.** It resolves "the current task" in this order, first
hit wins:

| | Signal | Certain? |
|---|---|---|
| 1 | `$CT_TASK`, exported into every session `ct` opens | yes |
| 2 | a `.task` symlink in the cwd or any parent | yes |
| 3 | cwd is already under `tasks/` | yes |
| 4 | newest task whose `repo:` matches the repo you're standing in | guess |
| 5 | newest task, full stop | guess |

A guess says which task it picked, so a wrong one is obvious immediately instead
of after the note lands in the wrong file.

`ct <slug>` is idempotent: re-running it reopens the same worktree and the same
notes directory, including one opened on an earlier date.

## Notes

- **zsh only.** It leans on zsh globbing (`(N/om)`) throughout. A bash port would
  be a rewrite, not a patch.
- It runs `claude` at the end of `ct`. Swap that line for your editor if you want
  the worktree workflow without Claude Code.
- Versioning `$CT_ROOT` as a git repo is a good idea — that's what makes the notes
  durable rather than just local. Keep secrets, kubeconfigs and customer names out
  of them if you do.

MIT.
