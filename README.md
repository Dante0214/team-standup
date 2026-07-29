# team-standup

Daily standup prep for Claude Code. Reads git and GitHub, writes the report you'd otherwise assemble by hand at 9:58am.

- **어제 진행사항** — commits and pull requests (merged / opened / reviewed) since the last working day
- **오늘 브랜치 상태** — current branch, distance from the integration branch, uncommitted work, open PRs and their review status
- **블로커** — stale PRs, branches drifting behind, work stranded in stashes

## Install

```
/plugin marketplace add <owner>/team-standup
/plugin install team-standup@team-standup
```

Local checkout instead:

```
/plugin marketplace add /path/to/team-standup
/plugin install team-standup@team-standup
```

## Use

```
/standup                          # current repo, since last working day
/standup --all                    # every repo under the parent folder
/standup --since "1 week ago"     # weekly rollup
/standup --root ~/work            # every repo under a specific folder
```

Plain language works too — "스탠드업 준비해줘", "어제 뭐 했지".

## Requirements

- `git`
- `gh` (optional) — authenticated, for the pull request sections. Without it the report falls back to commits and branch state only.
- `bash` — present on macOS and Linux; on Windows, ships with Git for Windows.

## Window

Defaults to the last working day: Monday and Sunday reach back to Friday, other days to yesterday. Override with `--since`.

## Author filter

Commits are filtered by `git config user.email`. Teammates sharing a machine, or anyone whose work email differs per repo, can override with `--author`.
