# ticket-kit

GitHub Issues 위에서 사람과 Claude가 서로 티켓을 던지며 일하기 위한 키트.
여기가 원본이고, 게임 저장소마다 복사해서 붙인다.

## 새 게임 저장소 열기

**PC (명령 하나).** gh 로그인 상태에서:

```bash
tools/ticket-kit/new-game.sh 새게임            # --private 가능. 시크릿 토큰은 환경변수 또는 프롬프트
```

저장소 생성 → 클론(gameDev 옆 폴더) → 키트·라벨·시크릿 → 첫 커밋·푸시까지 한 번에. 끝나면 첫 티켓 링크를 찍어준다.

**폰 (템플릿).** 한 번만 준비: PC에서 `new-game.sh game-template` 을 만든 뒤 그 저장소 Settings → General → "Template repository" 체크.
이후 폰에서는 https://github.com/tomhator/game-template → "Use this template" → 이름 입력. 첫 푸시에 `ticket-kit-setup.yml`이 라벨을 자동으로 만든다.
남는 건 시크릿 하나: 저장소 Settings → Secrets → `CLAUDE_CODE_OAUTH_TOKEN` (토큰은 PC에서 뽑아둔 것 재사용).

Claude GitHub App이 "All repositories"로 설치돼 있으면 둘 다 이걸로 끝. 아니면 https://github.com/settings/installations 에서 저장소 추가.

## 적용

```bash
tools/ticket-kit/apply.sh ../my-game            # origin 리모트에서 owner/repo 자동 감지
tools/ticket-kit/apply.sh ../my-game me/my-game # 직접 지정
```

라벨 생성에는 `gh` CLI 또는 `GITHUB_TOKEN` 환경변수가 필요하다. 여러 번 실행해도 안전하다.
적용 후 GitHub 웹에서 Projects 보드를 하나 만들고(1분), 변경된 파일을 커밋한다.

## 내용물

| 파일 | 역할 |
|---|---|
| `labels.json` | 라벨 정의. 코트 2개 + 종류 7개 |
| `ISSUE_TEMPLATE/` | 이슈 폼 7개. 종류 라벨과 코트 라벨이 자동으로 붙는다 |
| `CLAUDE.snippet.md` | 작업 규약. 대상 저장소 CLAUDE.md에 마커 블록으로 들어간다 |
| `workflows/ticket-court.yml` | 코트 라벨 배타 처리 + `needs-human`이면 소유자에게 자동 할당(알림) |
| `workflows/ticket-kit-setup.yml` | 기본 브랜치 푸시 시 labels.json 대로 라벨 자동 생성/갱신 (gh·토큰 없는 저장소용) |
| `workflows/claude.yml` | 티켓·PR 댓글의 `@claude` 멘션 → Claude Code 세션 호출. 앱 설치 + `CLAUDE_CODE_OAUTH_TOKEN` 시크릿 필요(파일 머리말 참고) |
| `apply.sh` | 위 전부를 대상 저장소에 적용 |
| `new-game.sh` | 새 저장소 생성부터 첫 푸시까지 명령 하나 (PC, gh 필요) |
| `update.sh` | 대상 저장소에 복사되어, 거기서 실행하면 최신 키트를 받아 재적용 |
| `VERSION`, `CHANGELOG.md` | 키트 버전과 변경 내역 |
| `dashboard/` | 상황판 생성기. 대상 저장소의 `.github/ticket-kit/dashboard/`로 복사된다 |

## 상황판

```bash
python3 .github/ticket-kit/dashboard/build_dashboard.py .   # 대상 저장소 안에서. → .github/ticket-kit/dashboard/out/
```

대상 저장소의 `.github/ticket-dashboard.json`에 제목, 프로젝트 카드(라벨·이름·설명·단계), 발행된 아티팩트 URL을 둔다.
파일이 없으면 저장소 전체를 프로젝트 하나로 그린다. 마일스톤 제목을 `<프로젝트 라벨>: …` 형식으로 지으면 해당 카드에 진행률로 붙는다.
Claude는 규약에 따라 세션 시작·끝에 이 화면을 같은 URL로 재발행한다. 화면의 "티켓 던지기" 버튼은 GitHub 이슈 폼을 템플릿·라벨 프리필로 연다.

저장소별로 라벨을 더 두고 싶으면 대상 저장소에 `.github/ticket-labels.local.json`을 같은 형식으로 만들어 두면 함께 적용된다.

## Claude는 어떻게 알아먹나

`CLAUDE.snippet.md`가 대상 저장소의 `CLAUDE.md`에 들어가고, Claude Code는 세션마다 그 파일을 자동으로 읽는다.
스니펫에는 키트 구성, 이슈를 읽고 쓰는 수단(MCP → gh → 토큰 API 순), 세션 루틴, 코트 규칙이 전부 들어 있다.
그래서 새 저장소에서 세션을 열면 첫 마디가 "지금 티켓 상황"이어야 정상이다.

## 업데이트와 버전

키트를 받은 저장소에서는 세션에 "키트 업데이트해줘"라고 하거나 직접 실행한다.

```bash
.github/ticket-kit/update.sh        # gameDev master → 현재 저장소. '전 → 후' 버전 출력
```

설치된 버전은 `.github/ticket-kit/VERSION`과 CLAUDE.md 규약 블록 첫 줄에 있다. 변경 내역은 `CHANGELOG.md`.
규약을 바꾸고 싶으면 원본(이 저장소)에 티켓을 던진다. 프로젝트 저장소에서 블록을 직접 고치면 다음 업데이트 때 덮인다.

## 티켓은 보는 것

이슈 본문은 마크다운만 렌더링되므로(HTML 스타일·스크립트는 제거) 표, Mermaid, 알림 상자, 체크리스트로 시각화한다.
종류별 기본 형식과 "마크다운으로 부족하면 아티팩트" 규칙은 `CLAUDE.snippet.md`의 "티켓은 읽는 게 아니라 보는 것" 절. 예시: tomhator/gameDev#15.

## 핵심 규칙 한 줄

열린 티켓은 항상 `needs-human` 아니면 `needs-claude`. 당신 코트가 비어 있지 않으면 구경꾼이 아니다.
