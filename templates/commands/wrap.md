---
description: Write this session into the current task's NOTES.md, then commit and push so the notes survive the machine
argument-hint: Optional task slug, otherwise inferred
allowed-tools: Bash(ls *), Bash(echo *), Bash(git *), Bash(gh pr *), Read, Write, Edit
---

## Context

- Argument: `$ARGUMENTS`
- Current task env: !`echo ${CT_TASK:-unset}`
- Tasks, newest first: !`ls -1t ${CT_ROOT:-$HOME/Projects/claude}/tasks/ 2>/dev/null | head -10`
- Uncommitted notes: !`git -C ${CT_ROOT:-$HOME/Projects/claude} status --short -- tasks/ | head -20`
- Repo state here: !`git status --short --branch 2>/dev/null`
- Recent commits: !`git log --oneline -8 2>/dev/null`

## Task

Update the task's `NOTES.md` so a fresh session with zero memory of this one can
pick up cleanly, then make it durable. Follow the `task-workspace` skill.

1. Work out which task this session was about. `$ARGUMENTS` if given, else
   `$CT_TASK`, else the newest task. If it is a guess, say which one you picked
   in one line.

2. Read `NOTES.md` before writing. This is an update, not a rewrite. Keep what is
   still true, keep the existing structure, and keep the running note stream at
   the bottom.

3. Update, in this order:
   - **Status.** One line of current reality. This is the line that gets read.
   - **What has happened so far.** Mark only what was verified with `✅`.
     Something attempted, or run without checking the result, is not done. If a
     step turned out partial, say partial.
   - **Established, do not re-derive.** What this session proved: queries that
     worked, values that turned out wrong, things that looked like a bug and were
     not, dead ends and why. This section is the point of the whole document.
   - **Open questions.** Add what surfaced, remove what got answered, and name
     who or what can resolve each one.
   - **Tracking.** Add any PR opened this session.

4. If the task is still named `session-HHMM`, suggest a real slug for `ctmv`
   in your reply. Do not rename it yourself.

5. **Commit and push.** The notes are only durable once pushed.

   ```bash
   git -C $CT_ROOT add tasks/<slug>
   git -C $CT_ROOT commit -m "tasks: wrap <slug>"
   git -C $CT_ROOT push
   ```

   Check what `git add` picked up before committing. Never commit secrets,
   kubeconfigs or cluster endpoints, private repo or not.

Be accurate over flattering. If the session ended messier than it started, write
that down. Do not summarize the conversation, only what changes what the next
session should do.

Report back in three lines at most: what the status now says, and anything I
still owe someone.
