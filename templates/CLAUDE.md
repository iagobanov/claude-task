# Global preferences

Loaded into every session via `~/.claude/CLAUDE.md`, which symlinks here. This
file holds only what changes behaviour in every session. Procedures go in
skills, file specific gotchas in `.claude/rules/`.

## Tasks and notes

Substantive work gets a directory under `$CT_ROOT/tasks/<slug>/` with a
`NOTES.md` written for a future session that has no memory of this one. The
`ct` helpers create and resolve tasks; `ct --help` is the reference and the
`task-workspace` skill has the notes template.

When a session opens in a bare `session-HHMM` task, name it and attach a repo
only when the request makes those obvious: `ctmv <slug>`, `cta org/repo`. Then
get on with the work. Plenty of tasks have no repo.

`ctn "<text>"` appends a note to the current task from anywhere. Use it when
something worth keeping turns up. `/wrap` closes a session out, `/ship` opens
a draft PR.

This repo is private. Nothing here carries tokens, kubeconfigs, `.env` contents
or cluster endpoints. Names that identify a customer stay out of what leaves
it: branch names, PR and issue text, artifacts.

## How to work

- Deliver what was asked at the scope intended. When an unrelated bug, a
  follow up or a better approach turns up along the way, say so in a sentence
  and keep going. Whether it gets done is my call.
- Flag conflicts and blockers rather than working around them silently.
- Outward facing actions wait for my explicit go on the exact text or action,
  every time: posting on PRs, issues or chat, opening a non draft PR, committing
  on a branch you did not create.
- Writing, in chat and in files: short sentences, engineer to engineer. Size a
  written deliverable to what the task needs. No filler sections, no restating
  what was just done.
