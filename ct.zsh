# --- claude multi-session task helpers ---
#
# ct / cta / ctn / ctmv / ctcd / ctls / ctrm. Run `ct --help` for the whole set —
# the text lives in _ct_help below, so there is only one copy of it to keep true.
# "current task" is resolved by _ct_task, so ctn/ctcd/ctmv work from anywhere.

export CT_ROOT=${CT_ROOT:-$HOME/Projects/claude}
export CT_PROJECTS=${CT_PROJECTS:-$HOME/Projects}

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
                      and the same notes dir, whatever day it was opened on

  ${B}cta${b} <repo> [dest]     give the current task a repo: clone if needed, cut the
                      branch, create the worktree, relink the notes
                        <repo>  org/repo | git url | path to a local clone
                        [dest]  where to clone to. Default is
                                \$CT_PROJECTS/<org>/<repo>. Pass it explicitly
                                when your clones live somewhere else

  ${B}ctn${b} [text]            append a timestamped note to the current task
                      no text opens its NOTES.md in \$EDITOR
  ${B}ctmv${b} <slug>           rename the current task. Notes dir only: an existing
                      worktree and branch keep the old name
  ${B}ctcd${b}                  cd to the current task's notes dir
  ${B}ctls${b}                  every task, newest first, with repo and whether its
                      worktree is still live
  ${B}ctrm${b} <slug>           remove that slug's worktree, found by slug rather than
                      by cwd. Notes survive

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

# _ct_slug <task-dir> — strip the YYYY-MM-DD- prefix off a task dir name
_ct_slug() { local b=${1:t}; print -r -- ${b[12,-1]} }

_ct_notes_init() {  # <notes-file> <slug> <repo> [worktree]
  [[ -f $1 ]] && return 0
  if [[ -n $4 ]]; then
    printf '# %s\n\nrepo: %s\nworktree: %s\n\n## goal\n\n## notes\n' $2 $3 $4 > $1
  else
    printf '# %s\n\nrepo: %s\n\n## goal\n\n## notes\n' $2 $3 > $1
  fi
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
  local slug=$1
  [[ $slug == -* ]] && { print -u2 "ct: '$slug' is not a slug — see ct --help"; return 1 }
  [[ -z $slug ]] && slug=session-$(date +%H%M)

  # reuse an existing notes dir for this slug, whatever day it was opened on
  local task
  local -a prev=($CT_ROOT/tasks/*-$slug(N/om))
  if (( $#prev )); then task=$prev[1]; else task=$CT_ROOT/tasks/$(date +%Y-%m-%d)-$slug; fi
  mkdir -p $task/scratch

  # resolve the MAIN worktree, so this works from inside a task worktree too.
  # git rev-parse --show-toplevel returns the worktree path there, and its
  # basename is the SLUG, not the repo.
  local main=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')

  if [[ -z $main ]]; then
    _ct_notes_init $task/NOTES.md $slug none
    export CT_TASK=$task
    print -r -- "task: ${task:t}  (no repo yet — 'cta <org/repo>' to attach one)"
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
  local slug=$(_ct_slug $task) main

  if [[ -d $spec/.git || -f $spec/.git ]]; then
    main=${spec:A}
  else
    local url=${spec%.git} p name org
    p=${url//:/\/}
    local -a parts=(${(s:/:)p})
    name=$parts[-1]
    org=${parts[-2]:-unknown}
    # already cloned somewhere under ~/Projects?
    local -a found=($CT_PROJECTS/*/$name(N/) $CT_PROJECTS/$name(N/))
    if (( $#found )); then
      main=$found[1]
      print -r -- "cta: reusing existing clone $main"
    else
      [[ $spec == *:* || $spec == http* ]] || url=git@github.com:$spec.git
      [[ $url == *.git || $url == *:*/* ]] || url=$url.git
      main=${dest:-$CT_PROJECTS/$org/$name}
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
  _ct_notes_init $notes $(_ct_slug $task) none
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
  local new=$1
  [[ -z $new ]] && { print -u2 "usage: ctmv <new-slug>"; return 1 }
  local task=$(_ct_task)
  [[ -z $task ]] && { print -u2 "ctmv: no current task"; return 1 }

  local base=${task:t}
  local newtask=${task:h}/${base[1,10]}-$new
  [[ $newtask == $task ]] && return 0
  [[ -e $newtask ]] && { print -u2 "ctmv: $newtask already exists"; return 1 }
  mv $task $newtask || return 1

  local l
  for l in $CT_ROOT/worktrees/*/*/.task(N@); do
    [[ $(readlink $l) == $task ]] && ln -sfn $newtask $l
  done

  local -a wts=($CT_ROOT/worktrees/*/$(_ct_slug $task)(N/))
  (( $#wts )) && print -u2 "ctmv: worktree and branch still named '$(_ct_slug $task)'"

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
  local slug=$1
  [[ -z $slug ]] && { print -u2 "usage: ctrm <slug>"; return 1 }
  local -a wts=($CT_ROOT/worktrees/*/$slug(N/))
  (( $#wts )) || { print -u2 "ctrm: no worktree for '$slug' (notes untouched)"; return 1 }
  local wt=$wts[1]
  local main=$(git -C $wt worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')
  git -C ${main:-$wt} worktree remove $wt --force
}
