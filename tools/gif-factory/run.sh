#!/usr/bin/env bash
# launchd 가 부르는 진입점. 로그는 OUTBOX/.log/ 에 날짜별로.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"
[[ -f "$HERE/config.env" ]] || { echo "config.env 가 없습니다. config.env.example 을 복사해서 채우세요" >&2; exit 2; }
# shellcheck disable=SC1091
set -a; source "$HERE/config.env"; set +a
OUTBOX="${GIF_OUTBOX/#\~/$HOME}"
mkdir -p "$OUTBOX/.log"
LOG="$OUTBOX/.log/$(date +%Y-%m-%d).log"
{
  echo "== $(date '+%F %T') gif-factory 시작"
  python3 "$HERE/gif_factory.py" "$@"
  echo "== $(date '+%F %T') 끝 (exit $?)"
} >> "$LOG" 2>&1
