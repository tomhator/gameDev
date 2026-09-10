#!/usr/bin/env bash
# 새 게임 저장소를 명령 하나로: 생성 → 클론 → ticket-kit 적용(라벨·시크릿) → 첫 커밋·푸시
#
#   tools/ticket-kit/new-game.sh <이름> [--private] [--dir <부모 폴더>]
#
# 필요: gh CLI 로그인 상태. 시크릿은 환경변수 CLAUDE_CODE_OAUTH_TOKEN 이 있으면 자동, 없으면 gh 가 값을 물어본다.
set -euo pipefail
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="${1:?저장소 이름을 주세요}"; shift || true
VIS="--public"; PARENT=".."
while [[ $# -gt 0 ]]; do case "$1" in --private) VIS="--private";; --dir) PARENT="$2"; shift;; *) echo "모르는 옵션: $1" >&2; exit 1;; esac; shift; done
command -v gh >/dev/null || { echo "gh CLI 가 필요합니다: https://cli.github.com" >&2; exit 1; }
OWNER="$(gh api user -q .login)"
SLUG="$OWNER/$NAME"
DEST="$(cd "$PARENT" && pwd)/$NAME"
[[ -e "$DEST" ]] && { echo "이미 있음: $DEST" >&2; exit 1; }

echo "== 1/4 저장소 생성 $SLUG ($VIS)"
gh repo create "$SLUG" $VIS --clone --description "Godot 게임 프로젝트 — ticket-kit 운영" >/dev/null
mv "$NAME" "$DEST" 2>/dev/null || true
cd "$DEST"
git symbolic-ref HEAD >/dev/null 2>&1 || git checkout -q -b main

echo "== 2/4 ticket-kit 적용"
if [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
  echo "   (@claude 시크릿) 토큰을 붙여넣으세요. 비워두면 나중에 'gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo $SLUG'"
  read -r -s -p "   CLAUDE_CODE_OAUTH_TOKEN: " CLAUDE_CODE_OAUTH_TOKEN; echo
  export CLAUDE_CODE_OAUTH_TOKEN
fi
"$KIT_DIR/apply.sh" . "$SLUG"

cat > README.md <<MD
# $NAME

Godot 게임 프로젝트. 작업은 GitHub Issues 티켓으로 관리한다(\`CLAUDE.md\` 티켓 규약).

- 할 일: [Assigned to me](https://github.com/$SLUG/issues/assigned/@me)
- 티켓 던지기: [New issue](https://github.com/$SLUG/issues/new/choose)
- Claude 부르기: 티켓 댓글에 \`@claude 진행해줘\`
MD

echo "== 3/4 첫 커밋·푸시"
git add -A && git commit -q -m "ticket-kit 적용" && git push -q -u origin HEAD

echo "== 4/4 완료: https://github.com/$SLUG"
echo "   - Claude GitHub App 이 'All repositories' 가 아니면: https://github.com/settings/installations 에서 $NAME 추가"
echo "   - 첫 티켓: https://github.com/$SLUG/issues/new/choose"
