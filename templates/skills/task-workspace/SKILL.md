---
name: task-workspace
description: >
  How this user tracks work locally. Every actively worked task gets a directory
  under $CT_ROOT/tasks/ with a living NOTES.md status doc inside, written for a
  future session with no memory of this one. Load when starting substantive work
  on an investigation or a feature, when closing out a work session, or when
  looking for prior context on something already worked on.
---

# Task workspace

## Where

`$CT_ROOT/tasks/<slug>/`, lowercase, flat, one directory per task. No date
prefix, no status subdirectories: `ctls` sorts by mtime.

| Kind of work | Directory name | Example |
|---|---|---|
| Ticket | the key, lowercased | `tasks/proj-123/` |
| Incident | `p1-<number>-<short-slug>` | `tasks/p1-269312-checkout-504s/` |
| Anything else | a plain slug | `tasks/add-rate-limiting/` |

**This directory is versioned and pushed to a private repo.** Notes only. No
clones inside it, no `.env`, kubeconfig, token or cluster endpoint, private or
not. Names that identify a customer stay out of slugs, because a slug becomes a
branch name and branches get pushed elsewhere.

## The ct helpers

`ct --help` prints the whole set and how the current task is resolved. The
short version:

| Command | Does |
|---|---|
| `ct [slug]` | start or resume. Inside a git repo: worktree, branch, notes, session. Elsewhere: notes only, `session-HHMM` when no slug |
| `cta <repo> [dest]` | attach a repo later. Default clone dest is the first entry of `$CT_PROJECTS` |
| `ctn [text]` | append a timestamped note to the current task, from anywhere |
| `ctmv <slug>` | rename the notes dir. An existing worktree keeps its name |
| `ctcd` / `ctls` / `ctrm <slug>` | jump to, list, remove |

The first lines of a NOTES.md carry `repo:` and `worktree:` because `ctls` and
task resolution parse them. Keep them at the top.

## What goes in NOTES.md

Written for a future Claude session with zero memory of this one. Someone
dropping in cold should see where things stand and what to do next without
re-deriving anything.

```markdown
# <slug>

repo: <repo name, or none>
worktree: <path, if there is one>

Status: <one line of current reality. planning / in progress / blocked on X / done>

## The problem

Why this exists, in plain terms.

## What has happened so far

1. ✅ <done and verified>
2. ⏳ <in flight>
3. <not started>

## Established, do not re-derive

Facts that took real investigation. The query that proved something, the value
that turned out to be wrong, the thing that looked like a bug and was not.

## Open questions

Unresolved, flagged rather than guessed at. Include who can answer it.

## Tracking

PRs, issues, dashboards.

## Notes

Running stream, appended by `ctn`. Keep this section last so appends land here.
```

The **Established** section is the one that earns its keep. Everything else can
be reconstructed from git and PR history. That section cannot.

## Updating it

Write findings down with `ctn` as they happen. `/wrap` updates the document at
the end of a session. What makes an update useful:

- `✅` means checked, not that the command exited zero.
- A partial fix is written up as partial. A session that ended messier than it
  started gets written down as that.
- Dead ends are recorded, so the next session does not spend an hour
  rediscovering them.
- `Status` is updated first. It is the line that gets read.
