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

Reload your shell and run `ct --help`. Everything tunable sits in the config
block at the top of `ct.zsh` — tasks land in `$CT_ROOT` (default
`~/Projects/claude`); clones are looked for under every path in `$CT_PROJECTS`
(default `~/Projects`, checked at `<root>/<repo>` and `<root>/*/<repo>`), and the
first entry is where `cta` clones to. Override before the source line; note
`CT_PROJECTS` is an array:

```zsh
CT_PROJECTS=(~/work ~/oss)
[[ -r ~/.claude-task/ct.zsh ]] && source ~/.claude-task/ct.zsh
```

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
│   └── add-rate-limiting/
│       ├── NOTES.md      # survives everything
│       └── scratch/      # throwaway
└── worktrees/
    └── my-api/
        └── add-rate-limiting/   # the checkout, .task symlinks back to notes
```

No date prefix on task directories — `ctls` sorts by mtime, so chronology is
computed rather than baked into a name that goes stale the moment a task runs
longer than a day.

The seeded `NOTES.md` is a status doc written for a future session with no memory
of this one: a one-line `Status`, the problem, what has happened so far, a section
for facts that took real investigation (**Established, do not re-derive** — the one
that earns its keep), open questions, tracking links, and a running note stream at
the bottom that `ctn` appends to.

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
notes directory. Slugs are lowercased, so `ct PROJ-123` and `ct proj-123` are the
same task.

## Notes

- The file is two halves: a config block at the top that is yours to edit, and
  the engine below the `SKELETON-SHARED-BELOW` marker, which is shared verbatim
  with the author's workspace repos and republished from there. Suggest engine
  changes by issue or PR here; config is per-machine by design.
- **zsh only.** It leans on zsh globbing (`(N/om)`) throughout. A bash port would
  be a rewrite, not a patch.
- It runs `claude` at the end of `ct`. Swap that line for your editor if you want
  the worktree workflow without Claude Code.
- Versioning `$CT_ROOT` as a git repo is a good idea — that's what makes the notes
  durable rather than just local. Keep secrets, kubeconfigs and customer names out
  of them if you do.

MIT.
