#!/usr/bin/env bash
#
# install.sh — install csg-pm-skills into Claude Code, Codex, Cursor, and OpenCode.
#
# Three of the four tools (Claude Code, Codex, OpenCode) read the SKILL.md format
# natively, so installing is just placing the skill directory into the right folder.
# Cursor uses a different format, so for Cursor we generate a .cursor/rules/<name>.mdc
# rule plus a .cursor/commands/<name>.md slash command (project scope only).
#
# Usage:
#   ./install.sh [SKILL ...] [options]
#   curl -fsSL https://raw.githubusercontent.com/Rida2000/csg-pm-skills/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- prototype-to-prd --project .
#
# Options:
#   --tools <list>   comma list of claude,codex,cursor,opencode (default: auto-detect)
#   --all-tools      target all four regardless of detection
#   --global         per-user install (default)
#   --project[=DIR]  install into a repo (default DIR = cwd); enables Cursor
#   --link           force symlink placement
#   --copy           force copy placement
#   --list           show discovered skills + detected tools + resolved targets, then exit
#   --uninstall      remove what this installer created (honors the same selectors)
#   --dry-run        print actions; change nothing
#   -h, --help
#
# Written for bash 3.2 (default macOS): no associative arrays, no mapfile, no ${x,,}.

# Deliberately no `set -e` / `set -u`: this script is conditional-heavy and runs on
# bash 3.2 (where `"${arr[@]}"` on an empty array trips `set -u`). We check what matters.

REPO_DEFAULT="https://github.com/Rida2000/csg-pm-skills.git"
REF_DEFAULT="main"

# ---- output helpers ---------------------------------------------------------
say()  { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '3,25p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'
}

# ---- frontmatter parsing (single-line values; errors loudly otherwise) -------
# Reads one field (name|description) from a SKILL.md YAML frontmatter block.
fm_field() {
  awk -v field="$2" '
    NR==1 && $0=="---" { infm=1; next }
    infm && $0=="---" { exit }
    infm {
      pat="^" field ":[ \t]*"
      if ($0 ~ pat) { sub(pat, "", $0); print $0; exit }
    }
  ' "$1"
}

# Prints the SKILL.md body (everything after the closing frontmatter ---).
skill_body() {
  awk '
    NR==1 && $0=="---" { fm=1; next }
    fm==1 && $0=="---" { fm=0; next }
    fm==1 { next }
    { print }
  ' "$1"
}

# ---- skill discovery --------------------------------------------------------
dir_has_skills() {
  ls "$1"/*/SKILL.md >/dev/null 2>&1 && return 0
  ls "$1"/skills/*/SKILL.md >/dev/null 2>&1 && return 0
  return 1
}

# Echoes "<name>\t<absolute-dir>" per skill found under $1.
discover_skills() {
  local root="$1" d name base
  for d in "$root"/*/ "$root"/skills/*/; do
    [ -f "${d}SKILL.md" ] || continue
    base=$(basename "$d")
    name=$(fm_field "${d}SKILL.md" name)
    [ -n "$name" ] || name="$base"
    printf '%s\t%s\n' "$name" "$(cd "$d" && pwd)"
  done
}

# ---- tool detection ---------------------------------------------------------
tool_present() {
  case "$1" in
    claude)   [ -d "$HOME/.claude" ]          || command -v claude   >/dev/null 2>&1 ;;
    codex)    [ -d "$HOME/.codex" ]           || command -v codex    >/dev/null 2>&1 ;;
    opencode) [ -d "$HOME/.config/opencode" ] || command -v opencode >/dev/null 2>&1 ;;
    cursor)   return 0 ;;   # project-only; writing .cursor/* is harmless even without the app
    *)        return 1 ;;
  esac
}

resolve_tools() {
  if [ -n "$TOOLS" ]; then
    printf '%s\n' "$TOOLS" | tr ',' ' '
    return
  fi
  if [ "$ALL_TOOLS" = 1 ]; then
    say "claude codex cursor opencode"
    return
  fi
  local out="" t
  for t in claude codex opencode; do
    tool_present "$t" && out="$out $t"
  done
  [ "$SCOPE" = project ] && out="$out cursor"
  say "$out"
}

# ---- target path for a (tool, scope) ---------------------------------------
target_dir() {
  # $1 tool  $2 name
  case "$1:$SCOPE" in
    claude:global)    say "$HOME/.claude/skills/$2" ;;
    claude:project)   say "$PROJDIR/.claude/skills/$2" ;;
    codex:global)     say "$HOME/.agents/skills/$2" ;;
    codex:project)    say "$PROJDIR/.agents/skills/$2" ;;
    opencode:global)  say "$HOME/.config/opencode/skills/$2" ;;
    opencode:project) say "$PROJDIR/.opencode/skills/$2" ;;
    cursor:project)   say "$PROJDIR/.cursor/skills/$2" ;;
    *)                return 1 ;;
  esac
}

# ---- dry-run-aware filesystem actions --------------------------------------
act_mkdir() { [ -d "$1" ] && return 0; if [ "$DRY_RUN" = 1 ]; then say "MKDIR  $1"; else mkdir -p "$1"; fi; }
act_ln()    { if [ "$DRY_RUN" = 1 ]; then say "LINK   $2 -> $1"; else ln -s "$1" "$2"; fi; }
act_cp()    { if [ "$DRY_RUN" = 1 ]; then say "COPY   $1 -> $2"; else cp -R "$1" "$2"; fi; }
act_rm()    { if [ "$DRY_RUN" = 1 ]; then say "RM     $1"; else rm -rf "$1"; fi; }

# Is an existing dest one of ours (safe to replace)?
is_ours() {
  local dest="$1"
  if [ -L "$dest" ]; then
    local tgt; tgt=$(readlink "$dest")
    case "$tgt" in "$REPO_ROOT"/*|"$REPO_ROOT") return 0 ;; *) return 1 ;; esac
  elif [ -d "$dest" ] && [ -f "$dest/SKILL.md" ]; then
    return 0   # dest path already encodes the skill name; a SKILL.md here is our install
  fi
  return 1
}

# place_skill <src-dir> <dest-dir>
place_skill() {
  local src="$1" dest="$2"
  act_mkdir "$(dirname "$dest")"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if is_ours "$dest"; then act_rm "$dest"; else
      warn "refusing to overwrite $dest (not installed by csg-pm-skills)"; return 0
    fi
  fi
  if [ "$MODE" = link ]; then act_ln "$src" "$dest"; else act_cp "$src" "$dest"; fi
}

# ---- Cursor adapter ---------------------------------------------------------
write_mdc() {
  local out="$1" name="$2" src="$3" desc rel
  desc=$(fm_field "$src/SKILL.md" description)
  [ -n "$desc" ] || die "cannot read a single-line 'description' from $name/SKILL.md (multi-line frontmatter not supported)"
  if [ "$DRY_RUN" = 1 ]; then say "WRITE  $out"; return 0; fi
  act_mkdir "$(dirname "$out")"
  {
    say "---"
    printf 'description: %s\n' "$desc"
    say "alwaysApply: false"
    say "---"
    say ""
    printf '<!-- Generated from %s/SKILL.md by csg-pm-skills install.sh. Edit the source skill, not this file. -->\n' "$name"
    printf 'Resources (read as needed):'
    ( cd "$src" && find . -type f ! -name 'SKILL.md' ! -name '.*' | sed 's|^\./||' | sort ) \
      | while IFS= read -r rel; do printf ' @.cursor/skills/%s/%s' "$name" "$rel"; done
    say ""
    say ""
    skill_body "$src/SKILL.md"
  } > "$out"
}

write_cmd() {
  local out="$1" name="$2"
  if [ "$DRY_RUN" = 1 ]; then say "WRITE  $out"; return 0; fi
  act_mkdir "$(dirname "$out")"
  cat > "$out" <<EOF
# /$name

Follow the skill at \`.cursor/skills/$name/SKILL.md\` for this task. Read it in full
(including any files it references under \`.cursor/skills/$name/\`) and apply it.

Task: \$ARGUMENTS
EOF
}

install_cursor() {
  local name="$1" src="$2"
  if [ "$SCOPE" != project ]; then
    warn "cursor: no per-skill global location — skipped (use --project to install Cursor rules)"
    return 0
  fi
  place_skill "$src" "$PROJDIR/.cursor/skills/$name"
  write_mdc "$PROJDIR/.cursor/rules/$name.mdc" "$name" "$src"
  write_cmd "$PROJDIR/.cursor/commands/$name.md" "$name"
}

# ---- uninstall --------------------------------------------------------------
uninstall_one() {
  local name="$1" tool="$2" dest
  if [ "$tool" = cursor ]; then
    [ "$SCOPE" = project ] || return 0
    [ -e "$PROJDIR/.cursor/skills/$name" ] && act_rm "$PROJDIR/.cursor/skills/$name"
    [ -f "$PROJDIR/.cursor/rules/$name.mdc" ] && act_rm "$PROJDIR/.cursor/rules/$name.mdc"
    [ -f "$PROJDIR/.cursor/commands/$name.md" ] && act_rm "$PROJDIR/.cursor/commands/$name.md"
    return 0
  fi
  dest=$(target_dir "$tool" "$name") || return 0
  if [ -L "$dest" ]; then
    is_ours "$dest" && act_rm "$dest"
  elif [ -d "$dest" ] && [ -f "$dest/SKILL.md" ]; then
    act_rm "$dest"
  fi
}

# ---- remote bootstrap (curl | bash) ----------------------------------------
bootstrap_remote() {
  [ "${CSG_SKILLS_BOOTSTRAPPED:-0}" = 1 ] && die "no skills found next to install.sh, and already bootstrapped"
  command -v git >/dev/null 2>&1 || die "git is required to install from a remote (curl) invocation"
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/csg-pm-skills"
  local repo="${CSG_SKILLS_REPO:-$REPO_DEFAULT}"
  local ref="${CSG_SKILLS_REF:-$REF_DEFAULT}"
  say "Fetching skills from $repo ($ref) ..."
  if [ -d "$cache/.git" ]; then
    git -C "$cache" fetch --depth 1 origin "$ref" >/dev/null 2>&1 \
      && git -C "$cache" checkout -q FETCH_HEAD >/dev/null 2>&1 || warn "could not refresh cache; using existing copy"
  else
    rm -rf "$cache"; mkdir -p "$(dirname "$cache")"
    git clone --depth 1 --branch "$ref" "$repo" "$cache" >/dev/null 2>&1 \
      || git clone --depth 1 "$repo" "$cache" >/dev/null 2>&1 \
      || die "git clone failed ($repo)"
  fi
  dir_has_skills "$cache" || die "cloned repo has no skills"
  # Re-exec the cloned installer; copy is the right default for a throwaway cache.
  CSG_SKILLS_BOOTSTRAPPED=1 exec bash "$cache/install.sh" "$@"
}

# ---- helpers for arg handling ----------------------------------------------
is_pathish() {
  case "$1" in
    /*|./*|../*|.|..) return 0 ;;
    *) [ -d "$1" ] && return 0; return 1 ;;
  esac
}

# Returns the absolute dir for a requested skill name, or empty if unknown.
skill_src_for() {
  local want="$1" line n s
  while IFS=$(printf '\t') read -r n s; do
    [ "$n" = "$want" ] && { say "$s"; return 0; }
  done <<EOF
$SKILLS_TSV
EOF
  return 1
}

# ---- main -------------------------------------------------------------------
main() {
  # Defaults
  SCOPE=global
  PROJDIR=""
  MODE=""          # auto: link locally, copy when bootstrapped
  TOOLS=""
  ALL_TOOLS=0
  DRY_RUN=0
  DO_UNINSTALL=0
  DO_LIST=0
  SELECT=""        # space-separated requested skill names ("" = all)

  # Locate the repo (the dir holding the skills) next to this script.
  local self src_dir
  self="${BASH_SOURCE[0]:-$0}"
  src_dir=$(cd "$(dirname "$self")" 2>/dev/null && pwd)
  if [ -n "$src_dir" ] && dir_has_skills "$src_dir"; then
    REPO_ROOT="$src_dir"
  else
    # No skills beside us → we were piped via curl. Clone + re-exec.
    bootstrap_remote "$@"
  fi

  REMOTE=0
  [ "${CSG_SKILLS_BOOTSTRAPPED:-0}" = 1 ] && REMOTE=1

  # Parse args
  while [ $# -gt 0 ]; do
    case "$1" in
      --tools)      TOOLS="$2"; shift 2 ;;
      --tools=*)    TOOLS="${1#--tools=}"; shift ;;
      --all-tools)  ALL_TOOLS=1; shift ;;
      --global)     SCOPE=global; shift ;;
      --project)
        SCOPE=project
        if [ $# -ge 2 ] && is_pathish "$2"; then PROJDIR="$2"; shift 2; else PROJDIR="$PWD"; shift; fi
        ;;
      --project=*)  SCOPE=project; PROJDIR="${1#--project=}"; shift ;;
      --link)       MODE=link; shift ;;
      --copy)       MODE=copy; shift ;;
      --list)       DO_LIST=1; shift ;;
      --uninstall)  DO_UNINSTALL=1; shift ;;
      --dry-run)    DRY_RUN=1; shift ;;
      -h|--help)    usage; exit 0 ;;
      -*)           die "unknown option: $1 (try --help)" ;;
      *)            SELECT="$SELECT $1"; shift ;;
    esac
  done
  [ "$SCOPE" = project ] && [ -z "$PROJDIR" ] && PROJDIR="$PWD"
  if [ "$SCOPE" = project ]; then
    PROJDIR=$(cd "$PROJDIR" 2>/dev/null && pwd) || die "project dir not found: $PROJDIR"
  fi
  if [ -z "$MODE" ]; then [ "$REMOTE" = 1 ] && MODE=copy || MODE=link; fi

  SKILLS_TSV=$(discover_skills "$REPO_ROOT")
  [ -n "$SKILLS_TSV" ] || die "no skills (*/SKILL.md) found in $REPO_ROOT"

  local TOOL_LIST; TOOL_LIST=$(resolve_tools)
  [ -n "$(printf '%s' "$TOOL_LIST" | tr -d ' ')" ] || die "no tools selected/detected (use --tools or --all-tools)"

  # --list: report and exit
  if [ "$DO_LIST" = 1 ]; then
    say "Skills in $REPO_ROOT:"
    printf '%s\n' "$SKILLS_TSV" | while IFS=$(printf '\t') read -r n s; do
      [ -n "$n" ] || continue
      info "$n  ($s)"
    done
    say ""
    say "Scope: $SCOPE${PROJDIR:+ ($PROJDIR)}   Placement: ${MODE}"
    say "Tools: $TOOL_LIST"
    exit 0
  fi

  # Which skills?
  local names="" n s
  if [ -n "$(printf '%s' "$SELECT" | tr -d ' ')" ]; then
    for n in $SELECT; do
      skill_src_for "$n" >/dev/null || die "unknown skill: $n (see --list)"
      names="$names $n"
    done
  else
    names=$(printf '%s\n' "$SKILLS_TSV" | awk -F'\t' '{print $1}' | tr '\n' ' ')
  fi

  local verb="Installing"; [ "$DO_UNINSTALL" = 1 ] && verb="Uninstalling"
  say "$verb [$(printf '%s' "$names" | sed 's/^ *//')] for [$(printf '%s' "$TOOL_LIST" | sed 's/^ *//')] · scope=$SCOPE · mode=$MODE${DRY_RUN:+ (dry-run)}"

  local tool src
  for n in $names; do
    src=$(skill_src_for "$n") || { warn "skill not found: $n"; continue; }
    for tool in $TOOL_LIST; do
      if [ "$DO_UNINSTALL" = 1 ]; then
        uninstall_one "$n" "$tool"
        continue
      fi
      case "$tool" in
        claude|codex|opencode)
          local dest; dest=$(target_dir "$tool" "$n") || { warn "no target for $tool/$SCOPE"; continue; }
          place_skill "$src" "$dest"
          ;;
        cursor)
          install_cursor "$n" "$src"
          ;;
        *) warn "unknown tool: $tool" ;;
      esac
    done
  done

  [ "$DRY_RUN" = 1 ] && say "(dry-run: nothing changed)"
  say "Done."
}

main "$@"
