---
name: standup
description: Prepare a daily standup / scrum report from git and GitHub state. Summarizes yesterday's progress from commits and pull requests, then reports today's branch state — what's in flight, what's unpushed, what's waiting on review. Triggers on "standup", "스탠드업", "데일리 스크럼", "스크럼 준비", "어제 뭐 했지", "어제 한 일 정리", "daily report", "주간 보고", "what did I do yesterday", "이번 주 한 일".
---

# Standup

Two questions, two sections:

1. **어제 뭐 했나** — answered by commits and PRs in the window.
2. **오늘 어디까지 와 있나** — answered by branch state.

Report facts. Label inferences as inferences.

## Steps

### 1. Collect

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/standup/scripts/collect.sh"
```

Options:

| Flag | Meaning |
|---|---|
| `--all` | Scan every sibling repo of the current one (parent dir) |
| `--root <dir>` | Scan every git repo directly under `<dir>` |
| `--since <date>` | Override window. Anything `git log --since` accepts (`2026-07-20`, `"1 week ago"`) |
| `--author <email>` | Override author filter. Defaults to `git config user.email` |

Default window is the **last working day**: Monday and Sunday reach back to Friday, other days to yesterday.

Weekly report: `--since "1 week ago"`.

If the user keeps many repos under one parent folder, `--all` is usually what they want. If the current directory isn't a repo the script says so — rerun with `--all` or `--root`.

### 2. Read the output

Five sections come back:

- `YESTERDAY: COMMITS` — subject lines with `[N files changed, +X -Y]`, deduped across branches
- `YESTERDAY: PULL REQUESTS` — merged, opened, reviewed by the user
- `TODAY: BRANCH STATE` — branch, ahead/behind upstream **and** the integration branch, uncommitted files, stashes
- `TODAY: OPEN PULL REQUESTS` — the user's open PRs with review status and age, plus PRs awaiting their review

Commit subjects are often terse or misleading. When one is opaque (`fix`, `wip`, `수정`), read it before describing it:

```bash
git show --stat <sha>
```

Only for commits you'd otherwise have to guess about — not all of them. The `[N files changed]` line already tells you whether a commit is trivial.

### 3. Write the report

Match the user's language.

**어제 진행사항**

Group by feature or theme, not by repo or by chronology — unless the repos are unrelated projects, in which case group by repo. One line per unit of work, phrased so a teammate understands it. `refactor: extract useAuth hook` becomes "로그인 상태 로직 훅으로 분리". Fold trivial commits (`typo`, `lint`, `chore`) into the work they belong to, or drop them.

Merged PRs are the strongest signal of completion — lead with them. A merged PR and the commits it contains are one line, not two.

**오늘 브랜치 상태**

Facts, not plans. Per repo with anything in flight:

- current branch, and whether it's pushed
- ahead/behind the integration branch — `behind 40` means rebase before continuing
- uncommitted file count, and what they touch
- open PRs: review status (`APPROVED` means merge it, `PENDING` means chase it) and how stale
- PRs waiting on the user's review

Skip clean repos entirely. If everything is clean, say so in one line.

If the user wants a "오늘 할 일" line, derive it **only** from this evidence — uncommitted work continues, a draft PR gets finished, an approved PR gets merged — and mark it as inference. Never invent tasks; ask instead.

**블로커**

Only real signals:

- PR open several days with `PENDING` review
- branch far behind the integration branch (conflict risk)
- long-lived stashes, or a large uncommitted diff sitting unreviewed
- work scattered across many half-finished branches

Nothing qualifying means "없음". Don't manufacture blockers.

### 4. Offer follow-ups

Offer — don't perform unprompted:

- Slack-ready plain text (no markdown headers, `-` bullets)
- expand any line into detail
- weekly rollup via `--since "1 week ago"`

## Rules

- Every line in 어제 traces to a commit or PR. Zero invented work.
- 어제 is fact; anything about today's *plans* is inference and must say so. Branch *state* is fact.
- Keep it short — a standup is read aloud in under a minute. Roughly 3-6 lines per section.
- No commit hashes in the report body unless asked. PR numbers yes, hashes no.
- An empty window is a valid result. Say "커밋 없음" and move to branch state; don't pad.
