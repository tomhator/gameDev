
<!-- ticket-kit:start -->
## 티켓 규약 (ticket-kit)

이 저장소의 작업은 GitHub Issues 티켓으로 관리한다. 규칙은 짧고, 예외는 없다.

### 코트
- 열린 티켓은 항상 `needs-human`(당신 차례) 또는 `needs-claude`(Claude 차례) 중 하나를 달고 있다. 둘 다 없거나 둘 다 있으면 잘못된 상태다.
- 공을 넘길 때는 **댓글로 이유를 남기고** 라벨을 바꾼다. 라벨만 바꾸지 않는다.
- `needs-human`이 붙으면 저장소 소유자에게 자동 할당된다. GitHub의 "Assigned to me"가 곧 당신의 할 일 목록이다.

### Claude가 지켜야 할 것
1. **세션 시작:** 열린 이슈를 전부 읽는다. `needs-claude` 목록이 오늘 할 일이다. STATUS.md는 그 다음에 읽는다. 사람이 `needs-human` 티켓에 댓글을 남겼으면 그 답부터 처리한다.
2. **티켓 없이 코드를 바꾸지 않는다.** 오타 수정 같은 사소한 것만 예외. 하고 싶은 작업이 있으면 `feature`/`tuning` 티켓을 열고 `needs-human`으로 승인을 받는다.
3. **크기 판단:** `needs-claude` 티켓이라도 반나절을 넘기거나 기획 방향을 건드리면, 바로 만들지 않고 계획과 비용을 댓글로 적은 뒤 `needs-human`으로 넘겨 승인을 받는다. 작으면 그냥 한다.
4. **티켓 하나에 브랜치 하나.** 커밋 메시지에 `#번호`를 넣고, 마무리 커밋에는 `closes #번호`를 넣는다.
5. **막히면 묻는다.** 추측으로 진행하지 않고 `question`/`decision` 티켓을 열어 `needs-human`으로 넘긴다. 선택지와 추천을 같이 적는다.
6. **플레이가 필요하면 `playtest` 티켓.** 확인할 것 3개 이하, 현재 수치, 보고 형식을 적는다. 플레이 결과 없이 체감 튜닝을 추측으로 하지 않는다.
7. **세션 끝:** 손댄 티켓마다 댓글로 결과를 남기고 코트 라벨을 정리한다. STATUS.md는 다음 세션 인수인계 메모로만 갱신한다. 백로그는 BACKLOG.md가 아니라 `idea` 티켓이다.
8. **상황판 재발행:** 세션 시작과 끝에 `tools/ticket-kit/dashboard/build_dashboard.py .` 로 HTML을 만들고, `.github/ticket-dashboard.json`의 `artifact_url`로 아티팩트를 **같은 URL에** 재발행한다(Artifact 도구에 `url` 전달). URL이 비어 있으면 새로 발행하고 그 URL을 파일에 적어 커밋한다.

### 당신(사람)이 지켜야 할 것
- 아이디어는 다듬지 말고 템플릿으로 던진다. 한 줄이면 된다. 다듬는 건 Claude가 댓글로 한다.
- `needs-human` 티켓에 답할 때는 댓글을 달고 라벨을 `needs-claude`로 바꾼다. 답이 "보류"여도 그렇게 적는다.
- 승인은 당신만 한다. Claude가 스스로 승인하지 않는다.

### 라벨
- 코트: `needs-human` `needs-claude`
- 종류: `idea` `bug` `tuning` `feature` `decision` `playtest` `question`
- 단계: GitHub 마일스톤 (예: "그레이박스 1주차", "2주차 Go/No-Go")
- 쓰지 않는 것: 우선순위, 스토리 포인트, 스프린트. 순서는 승인할 때 사람이 정한다.
<!-- ticket-kit:end -->
