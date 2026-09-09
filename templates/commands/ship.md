---
description: Branch, commit, push and open a draft PR for the current work
argument-hint: Optional PR title
allowed-tools: Bash(git *), Bash(gh pr *), Bash(gh repo *), Read
---

## Context

- Branch: !`git branch --show-current`
- Status: !`git status --short --branch`
- Diff against the default branch: !`git diff $(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/@@' || echo origin/main)...HEAD --stat 2>/dev/null`
- Uncommitted diff: !`git diff HEAD`
- Repo: !`git remote get-url origin`
- Commit identity: !`git config user.email`

## Task

Get this work up as a draft PR.

Before anything else, one check:

1. **Branch.** If the current branch is the default branch, create a new one.
   Never commit or push to `main`, `master` or `develop`. A `ct` worktree is
   already on its own branch named after the task slug, so this usually passes.

Then:

2. Commit the work in focused commits. One logical change per commit. Do not
   bundle an unrelated formatting sweep in with a fix.

3. Push the branch.

4. Open the PR **as a draft**. `gh pr create --draft`. Draft is the default
   assumption, not a fallback for uncertainty. Only open it ready if I said
   ready for review in this request.

PR body: a couple of sentences on what changed and why, then a short bullet list
only if it adds real information. Not an essay, not a list of every file.

Never put a customer name, a cluster endpoint, a token or an internal hostname
in the branch name, the commit messages or the PR body. If the work needed one
to make sense, describe it generically and keep the specific in the task notes,
which are the private side of this.

Report back with the PR URL and nothing else.
