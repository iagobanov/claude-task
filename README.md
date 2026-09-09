# claude-task

A way of working with Claude Code where a git repo is the memory and you steer
in plain language. Seven zsh functions, two slash commands, one skill, and a
notes file per task. No daemon, no config file, nothing beyond git and zsh.

```bash
cd ~/Projects/my-api
ct add-rate-limiting     # worktree + branch + notes, opens Claude in it
```

Open a second terminal, do it again with a different slug, and the two sessions
never touch each other's working tree.

## The idea

- Claude Code reads `~/.claude` for preferences, skills and commands. Keep those
  in a repo and symlink them in. The setup becomes portable, reviewable, and one
  `git clone` away on a new machine.
- Every piece of work is a task: a directory with a `NOTES.md` written for a
  future session that has no memory of this one. Code lands in git history. The
  reasoning, the dead ends and the "we already tried that" land in the notes.
- Parallel sessions get their own git worktree and branch, so they are
  genuinely parallel rather than fighting over one checkout.
- You talk. "Wrap this up", "ship it", "where did we leave the retry bug".
  Commands and skills are how the repo tells Claude what those sentences mean.
- Where this is heading: the repo as the control plane. Natural language in,
  code and tasks out, and the repo holds what was decided and why. Not there
  yet. This is the working version, and it is used daily.

## A day with it

```bash
ct fix-flaky-retry              # worktree + branch + notes, session opens
# ... work with Claude ...
ctn "fails only under --parallel, not a timing bug"
/ship                           # focused commits, push, draft PR
/wrap                           # NOTES.md updated, committed, pushed
```

Next morning, `ct fix-flaky-retry` reopens the same worktree, and the first
line of the notes says where things stand.

Work that has no repo, a debug session on someone else's cluster, reading docs,
poking an API, starts with a bare `ct` and gets a notes directory with no
branch. If code turns up later, `cta org/repo` attaches it.

## Install

The helpers:

```bash
git clone https://github.com/iagobanov/claude-task ~/.claude-task
echo '[[ -r ~/.claude-task/ct.zsh ]] && source ~/.claude-task/ct.zsh' >> ~/.zshrc
```

Reload your shell and run `ct --help`. Tasks land in `$CT_ROOT`, default
`~/Projects/claude`. Clones are looked for under every path in `$CT_PROJECTS`,
default `~/Projects`, and the first entry is where `cta` clones to. Override
before the source line. `CT_PROJECTS` is an array:

```zsh
CT_PROJECTS=(~/work ~/oss)
[[ -r ~/.claude-task/ct.zsh ]] && source ~/.claude-task/ct.zsh
```

The workspace, optional but where the value is:

```bash
mkdir -p ~/Projects/claude && cd ~/Projects/claude && git init
cp -R ~/.claude-task/templates/. .
ln -sfn ~/Projects/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sfn ~/Projects/claude/skills   ~/.claude/skills
ln -sfn ~/Projects/claude/commands ~/.claude/commands
```

Push that repo somewhere private. The notes are only durable once they are.

## Layout

```
$CT_ROOT/                      # the workspace repo, versioned
├── CLAUDE.md                  # preferences, symlinked into ~/.claude
├── skills/                    # procedures Claude reaches for on its own
│   └── task-workspace/SKILL.md
├── commands/                  # things you invoke: /wrap, /ship
├── tasks/                     # one dir per task, notes only
│   └── add-rate-limiting/
│       ├── NOTES.md           # survives everything
│       └── scratch/           # throwaway, ignored
└── worktrees/                 # checkouts, ignored, reproducible
    └── my-api/
        └── add-rate-limiting/ # .task symlinks back to the notes
```

`templates/` in this repo holds a starting `CLAUDE.md`, the two commands and
the skill. They are short on purpose. Edit them to taste and keep them short.

## Quick reference

Shell:

| Command | Does |
|---|---|
| `ct [slug]` | Start or resume a task. In a repo: worktree + branch + notes. Outside one: notes only. No slug: `session-HHMM`. |
| `cta <repo> [dest]` | Attach a repo to a task that started without one. Reuses an existing clone if it finds one. |
| `ctn [text]` | Append a timestamped note to the current task, from anywhere. |
| `ctmv <slug>` | Rename the current task. |
| `ctcd` | `cd` to the current task's notes. |
| `ctls` | Every task, newest first, with its repo and whether the worktree is live. |
| `ctrm <slug>` | Remove that slug's worktree. Notes survive. |

Every one takes `-h`.

In a session:

| Command | Does |
|---|---|
| `/wrap` | Rewrite the task's `NOTES.md` for the next session, then commit and push the notes. |
| `/ship` | Never on main. Focused commits, push, open a draft PR. |

Where things go:

| Kind of thing | Lives in |
|---|---|
| How you like to work, one line each | `CLAUDE.md` |
| A procedure Claude should know exists | `skills/<name>/SKILL.md` |
| A prompt you run deliberately | `commands/<name>.md` |
| What happened and what was learned | `tasks/<slug>/NOTES.md` |
| Anything secret | nowhere in this repo |

The notes file, in the order it is read:

| Section | Holds |
|---|---|
| `Status:` | One line of current reality. The line that gets read. |
| The problem | Why the task exists |
| What has happened so far | `✅` only for what was verified |
| Established, do not re-derive | Facts that took real investigation. The section that earns its keep. |
| Open questions | Unresolved, with who can answer |
| Tracking | PRs, issues, dashboards |
| Notes | Running stream, `ctn` appends here |

## How the current task is resolved

`ctn`, `ctcd` and `ctmv` never need you to navigate first. First hit wins:

| | Signal | Certain? |
|---|---|---|
| 1 | `$CT_TASK`, exported into every session `ct` opens | yes |
| 2 | a `.task` symlink in the cwd or any parent | yes |
| 3 | cwd is already under `tasks/` | yes |
| 4 | newest task whose `repo:` matches the repo you are standing in | guess |
| 5 | newest task, full stop | guess |

A guess says which task it picked, so a wrong one is obvious immediately.

`ct <slug>` is idempotent: re-running it reopens the same worktree and notes.
Slugs are lowercased. No date prefix on task directories, `ctls` sorts by mtime.

## Boundaries worth setting once

- The workspace repo is private. Private is not a reason to relax: no tokens,
  kubeconfigs, `.env` files or cluster endpoints in it. A key in git outlives
  the repo it was pushed to.
- Names that identify a customer stay out of branch names, commit messages and
  PR text, because those leave the repo. A task slug becomes a branch name.
- PRs open as drafts. Nothing outward, a PR marked ready, a comment, a message,
  goes out without an explicit go.
- Keep the instruction set small. A one line judgement beats a rule written to
  correct one past mistake.

## Notes

- `ct.zsh` is two halves: a config block at the top that is yours, and the
  engine below the `SKELETON-SHARED-BELOW` marker, shared verbatim with the
  author's workspace repos and republished from there. Engine changes by issue
  or PR here.
- zsh only. It leans on zsh globbing throughout. A bash port would be a
  rewrite.
- `ct` runs `claude` at the end. Swap that line for your editor if you want the
  worktree workflow without Claude Code.

MIT.
