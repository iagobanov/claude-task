# --- claude multi-session task helpers ---
#
# ct / cta / ctn / ctmv / ctcd / ctls / ctrm. Run `ct --help` for the whole set —
# the text lives in _ct_help below, so there is only one copy of it to keep true.
# "current task" is resolved by _ct_task, so ctn/ctcd/ctmv work from anywhere.
#
# This is the public copy of an engine shared verbatim with the author's private
# workspace repos. Everything you might want to change lives in the config block
# below; the engine past the marker needs no editing.

# ---------------------------------------------------------------------------
#  CONFIG — override any of these before sourcing, or edit them here
# ---------------------------------------------------------------------------
export CT_ROOT=${CT_ROOT:-$HOME/Projects/claude}

# where cta looks for existing clones (at <root>/<repo> and <root>/*/<repo>),
# and where the FIRST entry is the default clone destination.
# To override, define an array before the source line: CT_PROJECTS=(~/work ~/oss)
typeset -ga CT_PROJECTS
(( $#CT_PROJECTS )) || CT_PROJECTS=($HOME/Projects)

# org to assume when a bare repo name has no org in it (cta myrepo)
CT_DEFAULT_ORG=${CT_DEFAULT_ORG:-unknown}

# extra lines shown under [dest] in ct --help; keep a 32-space indent per line
CT_CLONE_NOTE=''

# shown under "naming" in ct --help; continuation lines indent by 9
CT_NAMING='a short kebab-case slug (add-rate-limiting), a ticket key lowercased
         (proj-123), p1-<number>-<slug> for an incident. ctmv fixes a session-HHMM.'

# ---------------------------------------------------------------------------
#  SKELETON-SHARED-BELOW — everything past this line is IDENTICAL in both repos.
#  Do not edit one copy
#  without the other — `bin/skeleton-check.sh` will tell you when they drift.
# ---------------------------------------------------------------------------

# _ct_help — shared usage screen; every ct* command takes -h / --help.
_ct_help() {
  local B='' b=''
  [[ -t 1 ]] && { B=$'\e[1m'; b=$'\e[0m' }
  print -r -- "${B}claude task helpers${b}   tasks live in \$CT_ROOT (${CT_ROOT/#$HOME/~})

  ${B}ct${b} [slug]             start or resume a task
                        in a git repo   worktree + branch + notes + session
                        anywhere else   notes-only task + session
                        no slug         named session-HHMM, rename with ctmv
                      idempotent: an existing slug reopens the same worktree
                      and the same notes dir

  ${B}cta${b} <repo> [dest]     give the current task a repo: clone if needed, cut the
                      branch, create the worktree, relink the notes
                        <repo>  org/repo | git url | path to a local clone
                        [dest]  where to clone to. Default is
                                ${CT_PROJECTS[1]/#$HOME/~}/<repo>
${CT_CLONE_NOTE}
  ${B}ctn${b} [text]            append a timestamped note to the current task
                      no text opens its NOTES.md in \$EDITOR
  ${B}ctmv${b} <slug>           rename the current task. Notes dir only: an existing
                      worktree and branch keep the old name
  ${B}ctcd${b}                  cd to the current task's notes dir
  ${B}ctls${b}                  every task, newest first, with repo and whether its
                      worktree is still live
  ${B}ctrm${b} <slug>           remove that slug's worktree, found by slug rather than
                      by cwd. Notes survive

${B}naming${b}   ${CT_NAMING}

${B}the \"current task\"${b} is resolved in this order, first hit wins:

  1  \$CT_TASK        exported by ct/cta, so it is set inside their session  sure
  2  .task symlink   in the cwd or any parent — every worktree has one      sure
  3  cwd under tasks/                                                       sure
  4  newest task whose repo: matches the repo you are standing in          guess
  5  newest task, full stop                                                guess

a guess prints which task it picked, so a wrong one is visible right away.
"
}

# _ct_task — print the current task's notes dir.
# exit 0 = certain, 2 = guessed (newest task), 1 = nothing found.
_ct_task() {
  [[ -n $CT_TASK && -d $CT_TASK ]] && { print -r -- $CT_TASK; return 0 }

  # a worktree started by ct/cta has a .task symlink back to its notes
  local d=$PWD t
  while [[ $d != / && -n $d ]]; do
    if [[ -L $d/.task ]]; then t=$d/.task; print -r -- ${t:A}; return 0; fi
    d=${d:h}
  done

  # standing inside the tasks tree already
  if [[ $PWD == $CT_ROOT/tasks/* ]]; then
    local rest=${PWD#$CT_ROOT/tasks/}
    print -r -- $CT_ROOT/tasks/${rest%%/*}
    return 0
  fi

  # standing in a repo? prefer the newest task that names it
  local main=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')
  if [[ -n $main ]]; then
    local c
    for c in $CT_ROOT/tasks/*(N/om); do
      if grep -qx "repo: ${main:t}" $c/NOTES.md 2>/dev/null; then
        print -r -- $c
        return 2
      fi
    done
  fi

  # last resort: most recently touched task
  local -a recent=($CT_ROOT/tasks/*(N/om))
  (( $#recent )) && { print -r -- $recent[1]; return 2 }
  return 1
}

# _ct_notes_init <notes-file> <slug> <repo> [worktree]
# The section order matters: "## Notes" is last so that ctn's append lands in
# the running note stream rather than under Tracking.
_ct_notes_init() {
  [[ -f $1 ]] && return 0
  {
    print -r -- "# $2"
    print -r -- ""
    print -r -- "repo: $3"
    [[ -n $4 ]] && print -r -- "worktree: $4"
    print -r -- ""
    print -r -- "Status: just created, nothing done yet"
    print -r -- ""
    print -r -- "## The problem"
    print -r -- ""
    print -r -- "## What has happened so far"
    print -r -- ""
    print -r -- "## Established, do not re-derive"
    print -r -- ""
    print -r -- "## Open questions"
    print -r -- ""
    print -r -- "## Tracking"
    print -r -- ""
    print -r -- "## Notes"
    print -r -- ""
  } > $1
}

_ct_notes_setrepo() {  # <notes-file> <repo> <worktree>
  local tmp=$1.tmp
  awk -v r="$2" -v w="$3" '
    /^repo:/     { print "repo: " r; if (!d) { print "worktree: " w; d=1 } next }
    /^worktree:/ { if (!d) { print "worktree: " w; d=1 } next }
                 { print }
  ' $1 > $tmp && mv $tmp $1
}

# ct [slug] — start or resume a task.
ct() {
  [[ $1 == -h || $1 == --help ]] && { _ct_help; return 0 }
  local slug=${1:l}
  [[ $slug == -* ]] && { print -u2 "ct: '$slug' is not a slug — see ct --help"; return 1 }
  [[ -z $slug ]] && slug=session-$(date +%H%M)

  local task=$CT_ROOT/tasks/$slug
  local existed=0
  [[ -d $task ]] && existed=1
  mkdir -p $task/scratch

  # resolve the MAIN worktree, so this works from inside a task worktree too.
  # git rev-parse --show-toplevel returns the worktree path there, and its
  # basename is the SLUG, not the repo.
  local main=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')

  if [[ -z $main ]]; then
    _ct_notes_init $task/NOTES.md $slug none
    export CT_TASK=$task
    if (( existed )); then
      print -r -- "task: $slug  (resuming)"
    else
      print -r -- "task: $slug  (no repo yet — 'cta <org/repo>' to attach one)"
    fi
    cd $task && claude
    return
  fi

  local repo=${main:t}
  local wt=$CT_ROOT/worktrees/$repo/$slug
  _ct_notes_init $task/NOTES.md $slug $repo $wt
  if [[ ! -d $wt ]]; then
    git -C $main worktree add -b $slug $wt 2>/dev/null || git -C $main worktree add $wt $slug
  fi
  ln -sfn $task $wt/.task
  export CT_TASK=$task
  cd $wt && claude
}

# cta <org/repo | git-url | local-path> [clone-dest] — give the current task a repo.
cta() {
  [[ $1 == -h || $1 == --help ]] && { _ct_help; return 0 }
  local spec=$1 dest=$2
  [[ -z $spec ]] && { print -u2 "usage: cta <org/repo|git-url|local-path> [clone-dest]"; return 1 }

  local task=$(_ct_task)
  [[ -z $task ]] && { print -u2 "cta: no current task — run ct first"; return 1 }
  local slug=${task:t} main

  if [[ -d $spec/.git || -f $spec/.git ]]; then
    main=${spec:A}
  else
    local url=${spec%.git} p name org
    p=${url//:/\/}
    local -a parts=(${(s:/:)p})
    name=$parts[-1]
    org=${parts[-2]:-$CT_DEFAULT_ORG}
    # already cloned under one of the project roots, at either nesting depth?
    local -a found=()
    local base
    for base in $CT_PROJECTS; do found+=($base/$name(N/) $base/*/$name(N/)); done
    if (( $#found )); then
      main=$found[1]
      print -r -- "cta: reusing existing clone $main"
    else
      [[ $spec == *:* || $spec == http* ]] || url=git@github.com:$spec.git
      [[ $url == *.git || $url == *:*/* ]] || url=$url.git
      main=${dest:-$CT_PROJECTS[1]/$name}
      print -r -- "cta: cloning $url → $main"
      mkdir -p ${main:h}
      git clone $url $main || return 1
    fi
  fi

  local repo=${main:t}
  local wt=$CT_ROOT/worktrees/$repo/$slug
  if [[ ! -d $wt ]]; then
    git -C $main worktree add -b $slug $wt 2>/dev/null || git -C $main worktree add $wt $slug || return 1
  fi
  ln -sfn $task $wt/.task
  _ct_notes_setrepo $task/NOTES.md $repo $wt
  export CT_TASK=$task
  print -r -- "cta: $repo → $wt (branch $slug)"
  cd $wt
}

# ctn [text] — append a note to the current task. No text opens $EDITOR.
ctn() {
  [[ $1 == -h || $1 == --help ]] && { _ct_help; return 0 }
  local task rc
  task=$(_ct_task); rc=$?
  [[ -z $task ]] && { print -u2 "ctn: no task found under $CT_ROOT/tasks — run ct first"; return 1 }
  (( rc == 2 )) && print -u2 "ctn: no task in context, using most recent → ${task:t}"

  local notes=$task/NOTES.md
  _ct_notes_init $notes ${task:t} none
  if (( $# )); then
    printf -- '- %s  %s\n' "$(date '+%m-%d %H:%M')" "$*" >> $notes
    print -r -- "→ ${task:t}/NOTES.md"
  else
    ${=EDITOR:-vi} $notes
  fi
}

# ctmv <new-slug> — rename the current task's notes dir (worktree/branch keep theirs).
ctmv() {
  [[ $1 == -h || $1 == --help ]] && { _ct_help; return 0 }
  local new=${1:l}
  [[ -z $new ]] && { print -u2 "usage: ctmv <new-slug>"; return 1 }
  local task=$(_ct_task)
  [[ -z $task ]] && { print -u2 "ctmv: no current task"; return 1 }

  local old=${task:t}
  local newtask=${task:h}/$new
  [[ $newtask == $task ]] && return 0
  [[ -e $newtask ]] && { print -u2 "ctmv: $newtask already exists"; return 1 }
  mv $task $newtask || return 1

  # retitle the doc if it still carries the old slug as its heading
  [[ -f $newtask/NOTES.md ]] && \
    sed -i '' "1s|^# ${old}\$|# ${new}|" $newtask/NOTES.md 2>/dev/null

  local l
  for l in $CT_ROOT/worktrees/*/*/.task(N@); do
    [[ $(readlink $l) == $task ]] && ln -sfn $newtask $l
  done

  local -a wts=($CT_ROOT/worktrees/*/$old(N/))
  (( $#wts )) && print -u2 "ctmv: worktree and branch still named '$old'"

  [[ $PWD == $task || $PWD == $task/* ]] && cd ${PWD/$task/$newtask}
  export CT_TASK=$newtask
  print -r -- "→ ${newtask:t}"
}

ctcd() {
  [[ $1 == -h || $1 == --help ]] && { _ct_help; return 0 }
  local t=$(_ct_task)
  [[ -z $t ]] && { print -u2 "ctcd: no current task"; return 1 }
  cd $t
}

# ctls — every task, newest first, with whether its worktree is still around.
unalias ctls 2>/dev/null
ctls() {
  [[ $1 == -h || $1 == --help ]] && { _ct_help; return 0 }
  local t repo wt state
  printf '%-38s %-14s %s\n' TASK REPO WORKTREE
  for t in $CT_ROOT/tasks/*(N/om); do
    [[ -d $t ]] || continue
    repo=$(awk -F': *' '/^repo:/{print $2; exit}' $t/NOTES.md 2>/dev/null)
    wt=$(awk -F': *' '/^worktree:/{print $2; exit}' $t/NOTES.md 2>/dev/null)
    if [[ -n $wt && -d $wt ]]; then state=live
    elif [[ -n $wt ]]; then state=gone
    else state=-
    fi
    printf '%-38s %-14s %s\n' ${t:t} ${repo:-none} $state
  done
}

# ctrm <slug> — drop the worktree for a slug, found by slug rather than by cwd.
ctrm() {
  [[ $1 == -h || $1 == --help ]] && { _ct_help; return 0 }
  local slug=${1:l}
  [[ -z $slug ]] && { print -u2 "usage: ctrm <slug>"; return 1 }
  local -a wts=($CT_ROOT/worktrees/*/$slug(N/))
  (( $#wts )) || { print -u2 "ctrm: no worktree for '$slug' (notes untouched)"; return 1 }
  local wt=$wts[1]
  local main=$(git -C $wt worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')
  git -C ${main:-$wt} worktree remove $wt --force
}
