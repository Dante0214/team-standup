# team-standup

Claude Code용 데일리 스탠드업 준비 플러그인. git과 GitHub 상태를 읽어 스탠드업 리포트로 만들어 준다.

- **어제 진행사항** — 마지막 근무일 이후의 커밋과 PR(머지 / 생성 / 리뷰)
- **오늘 브랜치 상태** — 현재 브랜치, 통합 브랜치와의 거리, 미커밋 작업, 열린 PR과 리뷰 상태
- **블로커** — 리뷰 없이 방치된 PR, 뒤처진 브랜치, stash에 묶인 작업

읽기 전용이다. 커밋·push·파일 수정을 하지 않는다.

## 설치

```
/plugin marketplace add Dante0214/team-standup
/plugin install team-standup@team-standup
```

로컬 체크아웃으로 설치하려면:

```
/plugin marketplace add /path/to/team-standup
/plugin install team-standup@team-standup
```

설치 후 `/reload-plugins` 로 반영한다.

## GitHub CLI 설정

PR 섹션(머지·생성·리뷰·리뷰 대기)은 `gh` 로 조회한다. **설정하지 않으면 PR 관련 내용이 통째로 빠지고**, 커밋과 브랜치 상태만 나온다. 스크립트가 죽지는 않는다.

### 1. 설치

| OS | 명령 |
|---|---|
| Windows | `winget install --id GitHub.cli` |
| macOS | `brew install gh` |
| Linux | [공식 설치 문서](https://github.com/cli/cli/blob/trunk/docs/install_linux.md) 참고 |

### 2. 로그인

```
gh auth login
```

대화형 프롬프트다. Claude Code 안에서 실행하려면 입력창에 `!` 를 붙여 `!gh auth login` 으로 실행해야 프롬프트에 답할 수 있다.

선택지는 순서대로 `GitHub.com` → `HTTPS` → `Login with a web browser` 를 고르면 된다.

### 3. 확인

```
gh auth status
```

`✓ Logged in to github.com account <아이디>` 가 나오면 된다.

### 필요한 토큰 스코프

`repo` 스코프가 있어야 비공개 레포의 PR까지 조회된다. 나중에 추가하려면:

```
gh auth refresh -s repo
```

## 사용법

```
/team-standup:standup                          # 현재 레포, 마지막 근무일 이후
/team-standup:standup --all                    # 상위 폴더 아래 모든 레포
/team-standup:standup --since "1 week ago"     # 주간 롤업
/team-standup:standup --root ~/work            # 지정한 폴더 아래 모든 레포
/team-standup:standup --author me@company.com  # 커밋 작성자 직접 지정
```

이름이 겹치지 않으면 `/standup` 으로 줄여 써도 된다.

평문으로 말해도 동작한다 — "스탠드업 준비해줘", "어제 뭐 했지".

## 옵션

| 플래그 | 설명 |
|---|---|
| `--all` | 현재 레포의 상위 폴더 아래 모든 git 레포를 스캔 |
| `--root <dir>` | 지정한 폴더 바로 아래의 모든 git 레포를 스캔 |
| `--since <date>` | 기간 지정. `git log --since` 가 받는 형식이면 다 된다 (`2026-07-20`, `"1 week ago"`) |
| `--author <email>` | 커밋 작성자 필터. 기본값은 `git config user.email` |

## 기간 기준

기본값은 **마지막 근무일** 자정이다. 월요일과 일요일은 금요일까지 거슬러 올라가고, 나머지 요일은 어제부터다. `--since` 로 덮어쓸 수 있다.

## 작성자 필터

커밋은 `git config user.email` 기준으로 걸러낸다. 한 대의 장비를 여럿이 쓰거나 레포마다 회사 메일이 다르면 `--author` 로 지정한다.

## 요구사항

- `git`
- `bash` — macOS·Linux에는 기본 탑재. Windows는 Git for Windows에 포함되어 있다.
- `gh` — 선택. PR 섹션에만 필요하다. 위 [GitHub CLI 설정](#github-cli-설정) 참고.

## 출력이 비어 있다면

- **커밋이 안 잡힌다** — `git config user.email` 과 실제 커밋의 author 이메일이 다른 경우가 대부분이다. `git log -1 --format=%ae` 로 확인하고 `--author` 로 맞춰준다.
- **PR 섹션이 전부 skipped** — `gh auth status` 부터 확인한다.
- **레포가 하나도 안 나온다** — 깨끗하고 커밋도 없는 레포는 출력에서 제외된다. 의도된 동작이다. 레포 30개를 스캔해도 리포트가 짧게 유지된다.
