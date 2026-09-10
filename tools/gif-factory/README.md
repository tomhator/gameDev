# gif-factory — 맥북 GIF 공장

데스크탑에서 플레이 녹화 → 구글 드라이브 폴더에 넣기 → 집의 맥북이 알아서 홍보용 GIF 후보를 만들어 둠 → 아침에 폰으로 골라서 올리기.
개발 외 업무를 맥북에 맡기는 첫 사례. 게임 코드는 건드리지 않는다. 티켓: #18

```
데스크탑 ──녹화──▶ 구글 드라이브 gameDev-gif/inbox/ ──동기화──▶ 맥북 (launchd)
                                                                 │ 움직임 분석 → 후보 8개 → 프레임 시트
                                                                 │ claude -p 가 3개 선정 + 문구 초안
                                                                 │ GIF(480/320) + mp4 렌더
                                                                 ▼
폰(드라이브 앱) ◀─────────── 구글 드라이브 gameDev-gif/outbox/<날짜>/<영상>/  + SUMMARY.md
                                                                 └ gh 있으면 티켓 #18 에 댓글
```

## 한 번만 하는 세팅

### 구글 드라이브
1. 드라이브에 `gameDev-gif` 폴더를 만들고 안에 `inbox`, `outbox` 두 개.
2. 데스크탑과 맥북 둘 다 **Google Drive 데스크톱 앱** 설치·로그인.
3. 맥에서 `gameDev-gif` 폴더 우클릭 → **오프라인 사용 가능** 켜기. (스트리밍 모드 그대로면 파일이 껍데기만 와서 ffmpeg 가 못 읽을 수 있다.)
   - 맥에서 실제 경로: `~/Library/CloudStorage/GoogleDrive-<계정>/My Drive/gameDev-gif`
   - 윈도우에서: `G:\My Drive\gameDev-gif` (드라이브 문자는 다를 수 있음)

### 데스크탑 (윈도우)
- 녹화는 `Win+G` 게임 바로 충분. 설정에서 녹화 해상도를 게임 창 그대로, 30fps.
- 픽셀아트면 게임을 **정수배**(2x, 3x) 창으로 띄우고 녹화해야 GIF 가 깨끗하다.
- 녹화 파일(`Videos\Captures\*.mp4`)을 `gameDev-gif\inbox\` 로 옮기면 끝. 잘 찍으려고 애쓸 필요 없다. 그냥 켜두고 플레이.

### 맥북
```bash
brew install ffmpeg                 # 필수
brew install gh && gh auth login    # 선택: 티켓 댓글용
# claude CLI: 이미 있으면 `claude` 한 번 실행해 로그인돼 있는지 확인. 없어도 동작함(점수 순 선정)

cd ~/gameDev/tools/gif-factory      # 저장소를 clone 해 둔 곳
cp config.env.example config.env
open -e config.env                  # GIF_INBOX / GIF_OUTBOX 경로를 실제 드라이브 경로로
./install.sh                        # launchd 등록. 이후 inbox 에 파일이 오면 자동 실행 + 30분마다 확인
```
- 잠자기 방지: 시스템 설정 → 배터리 → 전원 어댑터 → **"디스플레이가 꺼져 있을 때 자동으로 잠자기 방지"** 켜기. 전원 연결 상태로 둔다. 뚜껑을 닫으면 외장 모니터 없이는 잠들기 때문에 열어 둔다.
- 해제: `./install.sh --remove`

## 확인
```bash
# 지금 바로 한 번 돌리기
launchctl kickstart gui/$(id -u)/com.gamedev.gif-factory
# 로그
tail -f "<GIF_OUTBOX>/.log/$(date +%F).log"
# 파일 하나만 직접 (launchd 없이)
python3 gif_factory.py --file ~/Movies/녹화.mp4 --outbox /tmp/gif-test
```

## 결과물
`outbox/<날짜>/<영상이름>/`
- `clip1_480.gif`, `clip1_320.gif`, `clip1.mp4` … 선정된 클립마다 GIF 두 크기 + mp4
- `SUMMARY.md` — 각 클립의 시작 시각, 고른 이유, 문구 초안 3개, 첫 글 템플릿
- `sheets/candNN.jpg` — 후보 프레임 시트 (claude 가 본 것). 선정이 이상하면 여기서 확인
- 커뮤별 용량 제한이 다르다. 320 짜리는 대부분 통과, 480 은 디시 등에서 잘릴 수 있다.

## 동작 세부
- **후보 고르기**: ffmpeg 의 장면변화 점수를 10fps 로 뽑아 6초 창을 1초 간격으로 훑는다. 창 점수는 **중앙값**(꾸준한 움직임)에서 하드컷(메뉴↔플레이 전환) 수만큼 감점. 절반 이상 겹치는 창은 버린다.
- **선정**: `claude -p` 에 프레임 시트 경로를 주고 Read 도구로 보게 한다(`prompt.md`). 게임 화면이 아니면 빈 결과를 내고, 그때는 점수 순으로 대체한다. claude 가 없거나 실패해도 결과는 나온다.
- **렌더**: 픽셀아트 기본(`neighbor`, 디더 없음, 128색). 일반 그래픽이면 `GIF_SCALE=lanczos`.
- **중복 방지**: `outbox/.processed.json` 에 파일명+크기를 기록. 다시 돌리려면 `--force`.
- **동기화 중 파일**: 수정된 지 90초 안 된 파일은 건너뛰고 다음 번(30분 뒤)에 처리한다.

## 다음 후보 (별도 티켓)
- 픽셀아트 잡일: 팔레트 밖 픽셀 찾기, 스프라이트 시트 묶기, 정수배 확대본 내보내기
- 야간 빌드·스모크 테스트, itch.io 자동 업로드
