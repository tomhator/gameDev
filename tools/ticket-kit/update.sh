#!/usr/bin/env bash
# 프로젝트 저장소에서 ticket-kit 을 최신으로 올린다. (.github/ticket-kit/update.sh 로 복사되어 실행됨)
#
#   .github/ticket-kit/update.sh            # gameDev master 에서 받아 현재 저장소에 재적용
#   TICKET_KIT_SRC=/path/to/gameDev .github/ticket-kit/update.sh   # 로컬 원본으로 (테스트용)
#
# 원본: https://github.com/tomhator/gameDev (공개) → tools/ticket-kit
set -euo pipefail
SRC_REPO="${TICKET_KIT_REPO:-tomhator/gameDev}"
SRC_REF="${TICKET_KIT_REF:-master}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(cd "$HERE/../.." && pwd)"          # .github/ticket-kit → 저장소 루트
OLD="$(cat "$HERE/VERSION" 2>/dev/null || echo '없음')"

if [[ -n "${TICKET_KIT_SRC:-}" ]]; then
  KIT="$TICKET_KIT_SRC/tools/ticket-kit"
else
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  url="https://api.github.com/repos/$SRC_REPO/tarball/$SRC_REF"
  auth=(); [[ -n "${GITHUB_TOKEN:-${GH_TOKEN:-}}" ]] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN:-${GH_TOKEN:-}}")
  if ! curl -sSfL "${auth[@]}" "$url" | tar -xz -C "$TMP" 2>/dev/null; then
    echo "키트를 받지 못했습니다: $url (네트워크 또는 권한). 원본 저장소를 직접 clone 한 뒤 tools/ticket-kit/apply.sh <이 저장소> 를 실행하세요." >&2
    exit 1
  fi
  KIT="$(find "$TMP" -maxdepth 1 -mindepth 1 -type d | head -1)/tools/ticket-kit"
fi
[[ -x "$KIT/apply.sh" ]] || { echo "키트 원본에 apply.sh 가 없습니다: $KIT" >&2; exit 1; }

NEW="$(cat "$KIT/VERSION")"
echo "== ticket-kit $OLD → $NEW ($SRC_REPO@$SRC_REF)"
"$KIT/apply.sh" "$TARGET"
echo "== 변경 내역: https://github.com/$SRC_REPO/blob/$SRC_REF/tools/ticket-kit/CHANGELOG.md"
echo "== 다음: git diff 로 확인하고 커밋하세요."
