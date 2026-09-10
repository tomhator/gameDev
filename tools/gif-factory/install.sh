#!/usr/bin/env bash
# 맥에 launchd 작업을 등록한다. 여러 번 실행해도 안전(재등록).
#   tools/gif-factory/install.sh          # 등록
#   tools/gif-factory/install.sh --remove # 해제
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="com.gamedev.gif-factory"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_="$(id -u)"

if [[ "${1:-}" == "--remove" ]]; then
  launchctl bootout "gui/$UID_/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "해제됨: $LABEL"
  exit 0
fi

[[ "$(uname)" == "Darwin" ]] || { echo "macOS 에서만 등록할 수 있습니다" >&2; exit 1; }
[[ -f "$HERE/config.env" ]] || { echo "config.env 가 없습니다. config.env.example 을 복사해서 채우세요" >&2; exit 2; }
set -a; source "$HERE/config.env"; set +a
INBOX="${GIF_INBOX/#\~/$HOME}"; OUTBOX="${GIF_OUTBOX/#\~/$HOME}"
[[ -d "$INBOX" ]] || { echo "INBOX 폴더가 없습니다: $INBOX (구글 드라이브가 동기화됐는지, 경로가 맞는지 확인)" >&2; exit 3; }
mkdir -p "$OUTBOX/.log" "$HOME/Library/LaunchAgents"
command -v ffmpeg >/dev/null || echo "경고: ffmpeg 가 PATH 에 없습니다. brew install ffmpeg"
command -v claude >/dev/null || echo "경고: claude CLI 가 없습니다. 움직임 점수만으로 선정합니다"
command -v gh >/dev/null || echo "참고: gh 가 없어 티켓 댓글은 생략됩니다 (SUMMARY.md 는 남음)"

sed -e "s#__RUN_SH__#$HERE/run.sh#g" -e "s#__INBOX__#$INBOX#g" -e "s#__LOGDIR__#$OUTBOX/.log#g" \
    "$HERE/$LABEL.plist" > "$PLIST"
launchctl bootout "gui/$UID_/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_" "$PLIST"
echo "등록됨: $LABEL"
echo "  감시 폴더: $INBOX"
echo "  결과 폴더: $OUTBOX"
echo "  로그: $OUTBOX/.log/"
echo "지금 한 번 돌려보기: launchctl kickstart gui/$UID_/$LABEL"
