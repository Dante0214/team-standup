#!/usr/bin/env bash
# standup collector — gathers raw git/gh facts for a daily standup.
# Two halves: what happened in the window (yesterday), and where things stand now (today).
# Prints plain text. Never guesses, never writes.

IFS=$'\n\t'

SINCE=""
AUTHOR=""
SCAN_ALL=0
ROOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --since)  SINCE="$2"; shift 2 ;;
    --author) AUTHOR="$2"; shift 2 ;;
    --all)    SCAN_ALL=1; shift ;;
    --root)   ROOT="$2"; SCAN_ALL=1; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Default window: since the last working day, 00:00.
# Monday -> last Friday. Sunday -> last Friday. Otherwise -> yesterday.
if [ -z "$SINCE" ]; then
  dow=$(date +%u)   # 1=Mon .. 7=Sun
  case "$dow" in
    1) back=3 ;;
    7) back=2 ;;
    *) back=1 ;;
  esac
  SINCE=$(date -d "$back days ago" +%Y-%m-%d)
fi

if [ -z "$AUTHOR" ]; then
  AUTHOR=$(git config user.email 2>/dev/null)
  [ -z "$AUTHOR" ] && AUTHOR=$(git config --global user.email 2>/dev/null)
fi

TMP=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/standup.$$")
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT
: > "$TMP/commits.txt"
: > "$TMP/state.txt"

echo "== WINDOW =="
echo "since:  $SINCE"
echo "author: $AUTHOR"
echo "now:    $(date '+%Y-%m-%d %H:%M %a')"
echo

scan_repo() {
  repo="$1"
  name=$(basename "$repo")
  cd "$repo" 2>/dev/null || return

  commits=$(git log --all --no-merges --since="$SINCE" --author="$AUTHOR" \
              --date=format:'%m/%d %H:%M' \
              --format='%h|%ad|%s' 2>/dev/null | sort -u -t'|' -k2,3)

  if [ -n "$commits" ]; then
    {
      echo "### $name"
      echo "$commits" | while IFS='|' read -r sha when subj; do
        stat=$(git show --shortstat --format='' "$sha" 2>/dev/null | tr -d '\n' | sed 's/^ *//')
        echo "  $sha  $when  $subj"
        [ -n "$stat" ] && echo "        [$stat]"
      done
      echo
    } >> "$TMP/commits.txt"
  fi

  # quotepath=false keeps non-ASCII filenames readable instead of octal-escaped.
  dirty=$(git -c core.quotepath=false status --porcelain 2>/dev/null)
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  stash=$(git stash list 2>/dev/null | wc -l | tr -d ' ')

  # A repo with no commits in the window and a clean tree has nothing to report.
  if [ -z "$commits" ] && [ -z "$dirty" ] && [ "$stash" = "0" ]; then
    return
  fi

  {
    echo "### $name"
    echo "  branch: $branch"

    track=$(git rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
    if [ -n "$track" ]; then
      behind=$(echo "$track" | cut -f1)
      ahead=$(echo "$track" | cut -f2)
      echo "  vs upstream: ahead $ahead, behind $behind"
    else
      echo "  vs upstream: none (unpushed branch)"
    fi

    # Distance from the integration branch — the conflict-risk signal.
    for base in origin/main origin/master origin/develop; do
      if git rev-parse --verify "$base" >/dev/null 2>&1; then
        bt=$(git rev-list --left-right --count "$base...HEAD" 2>/dev/null)
        if [ -n "$bt" ]; then
          bb=$(echo "$bt" | cut -f1)
          ba=$(echo "$bt" | cut -f2)
          echo "  vs $base: ahead $ba, behind $bb"
        fi
        break
      fi
    done

    if [ -n "$dirty" ]; then
      n=$(echo "$dirty" | wc -l | tr -d ' ')
      echo "  uncommitted: $n file(s)"
      echo "$dirty" | head -15 | sed 's/^/    /'
      [ "$n" -gt 15 ] && echo "    ... $((n - 15)) more"
    else
      echo "  uncommitted: clean"
    fi

    [ "$stash" != "0" ] && echo "  stashes: $stash"
    echo
  } >> "$TMP/state.txt"
}

if [ "$SCAN_ALL" = "1" ]; then
  if [ -z "$ROOT" ]; then
    top=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$top" ]; then ROOT=$(dirname "$top"); else ROOT=$(pwd); fi
  fi
  echo "(scanning repos under $ROOT)"
  echo
  for d in "$ROOT"/*/; do
    [ -e "${d}.git" ] && scan_repo "${d%/}"
  done
else
  top=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$top" ]; then
    echo "!! not a git repo — rerun with --all or --root <dir>"
  else
    scan_repo "$top"
  fi
fi

echo "== YESTERDAY: COMMITS =="
if [ -s "$TMP/commits.txt" ]; then cat "$TMP/commits.txt"; else echo "(none in window)"; echo; fi

echo "== YESTERDAY: PULL REQUESTS =="
gh_ok=0
if ! command -v gh >/dev/null 2>&1; then
  echo "gh not installed — skipped"
elif ! gh auth status >/dev/null 2>&1; then
  echo "gh not authenticated — skipped"
else
  gh_ok=1
  echo "-- merged --"
  gh pr list --state merged --limit 30 \
     --search "author:@me merged:>=$SINCE" \
     --json number,title,mergedAt,headRefName \
     --template '{{range .}}  #{{.number}} {{.title}} ({{.headRefName}}){{"\n"}}{{else}}  (none){{"\n"}}{{end}}' \
     2>/dev/null || echo "  (no GitHub remote here)"
  echo "-- opened --"
  gh pr list --state all --limit 30 \
     --search "author:@me created:>=$SINCE" \
     --json number,title,state,isDraft \
     --template '{{range .}}  #{{.number}} {{.title}} [{{.state}}{{if .isDraft}}/draft{{end}}]{{"\n"}}{{else}}  (none){{"\n"}}{{end}}' \
     2>/dev/null || echo "  (no GitHub remote here)"
  echo "-- reviewed by me --"
  gh pr list --state all --limit 30 \
     --search "reviewed-by:@me updated:>=$SINCE" \
     --json number,title,author \
     --template '{{range .}}  #{{.number}} {{.title}} — by {{.author.login}}{{"\n"}}{{else}}  (none){{"\n"}}{{end}}' \
     2>/dev/null || echo "  (no GitHub remote here)"
fi
echo

echo "== TODAY: BRANCH STATE =="
if [ -s "$TMP/state.txt" ]; then cat "$TMP/state.txt"; else echo "(all clean, nothing in flight)"; echo; fi

echo "== TODAY: OPEN PULL REQUESTS =="
if [ "$gh_ok" = "1" ]; then
  echo "-- mine, still open --"
  gh pr list --author '@me' --state open --limit 30 \
     --json number,title,isDraft,headRefName,reviewDecision,updatedAt \
     --template '{{range .}}  #{{.number}} {{.title}}{{if .isDraft}} [DRAFT]{{end}} ({{.headRefName}}) review={{if .reviewDecision}}{{.reviewDecision}}{{else}}PENDING{{end}} updated={{timeago .updatedAt}}{{"\n"}}{{else}}  (none){{"\n"}}{{end}}' \
     2>/dev/null || echo "  (no GitHub remote here)"
  echo "-- waiting on my review --"
  gh pr list --search 'review-requested:@me' --state open --limit 30 \
     --json number,title,author,updatedAt \
     --template '{{range .}}  #{{.number}} {{.title}} — by {{.author.login}}, updated={{timeago .updatedAt}}{{"\n"}}{{else}}  (none){{"\n"}}{{end}}' \
     2>/dev/null || echo "  (no GitHub remote here)"
else
  echo "gh unavailable — skipped"
fi
