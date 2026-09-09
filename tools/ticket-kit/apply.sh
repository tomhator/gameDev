#!/usr/bin/env bash
# ticket-kit 적용 스크립트. 여러 번 실행해도 안전하다.
#
#   tools/ticket-kit/apply.sh <대상 저장소 경로> [owner/repo]
#
# 하는 일:
#   1. ISSUE_TEMPLATE/  → <대상>/.github/ISSUE_TEMPLATE/   (덮어씀)
#   2. workflows/       → <대상>/.github/workflows/        (덮어씀)
#   2b. dashboard/, update.sh, VERSION → <대상>/.github/ticket-kit/ (덮어씀) + ticket-dashboard.json 골격
#   3. CLAUDE.snippet.md → <대상>/CLAUDE.md 의 마커 블록 안에 삽입/교체
#   4. labels.json (+ <대상>/.github/ticket-labels.local.json 이 있으면 추가) → GitHub 라벨 생성/갱신
#      인증: gh CLI 가 있으면 gh, 없으면 GITHUB_TOKEN 또는 GH_TOKEN 으로 curl
#
# owner/repo 를 생략하면 대상 저장소의 origin 리모트에서 읽는다.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:?대상 저장소 경로를 주세요}"
TARGET="$(cd "$TARGET" && pwd)"
SLUG="${2:-}"

if [[ -z "$SLUG" ]]; then
  url="$(git -C "$TARGET" remote get-url origin 2>/dev/null || true)"
  SLUG="$(printf '%s' "$url" | sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##')"
fi
[[ "$SLUG" =~ ^[^/]+/[^/]+$ ]] || { echo "owner/repo 를 알 수 없습니다: '$SLUG'" >&2; exit 1; }

echo "== ticket-kit → $TARGET ($SLUG)"

# 1, 2. 파일 복사
mkdir -p "$TARGET/.github/ISSUE_TEMPLATE" "$TARGET/.github/workflows"
cp "$KIT_DIR"/ISSUE_TEMPLATE/* "$TARGET/.github/ISSUE_TEMPLATE/"
cp "$KIT_DIR"/workflows/* "$TARGET/.github/workflows/"
mkdir -p "$TARGET/.github/ticket-kit/dashboard"
cp "$KIT_DIR"/dashboard/build_dashboard.py "$KIT_DIR"/dashboard/template.html "$TARGET/.github/ticket-kit/dashboard/"
cp "$KIT_DIR"/update.sh "$TARGET/.github/ticket-kit/update.sh"; chmod +x "$TARGET/.github/ticket-kit/update.sh"
cp "$KIT_DIR"/VERSION "$TARGET/.github/ticket-kit/VERSION"
KIT_VERSION="$(cat "$KIT_DIR/VERSION")"
echo "-- v$KIT_VERSION: 이슈 템플릿 $(ls "$KIT_DIR"/ISSUE_TEMPLATE/[0-9]*.yml | wc -l)개, 워크플로우 $(ls "$KIT_DIR"/workflows/* | wc -l)개, 상황판 생성기, update.sh 복사"
if [[ ! -f "$TARGET/.github/ticket-dashboard.json" ]]; then
  repo_name="${SLUG#*/}"
  printf '{\n  "title": "%s 상황판",\n  "artifact_url": "",\n  "projects": []\n}\n' "$repo_name" > "$TARGET/.github/ticket-dashboard.json"
  echo "-- .github/ticket-dashboard.json 골격 생성 (projects 비어 있음 = 저장소 전체를 카드 하나로)"
fi
grep -qxF '.github/ticket-kit/dashboard/out/' "$TARGET/.gitignore" 2>/dev/null || echo '.github/ticket-kit/dashboard/out/' >> "$TARGET/.gitignore"

# 3. CLAUDE.md 마커 블록 (스니펫의 {{VERSION}} 치환)
SNIPPET="$(mktemp)"; trap 'rm -f "$SNIPPET"' EXIT
sed "s/{{VERSION}}/$KIT_VERSION/g" "$KIT_DIR/CLAUDE.snippet.md" > "$SNIPPET"
CLAUDE_MD="$TARGET/CLAUDE.md"
START='<!-- ticket-kit:start -->'
END='<!-- ticket-kit:end -->'
if [[ -f "$CLAUDE_MD" ]] && grep -qF "$START" "$CLAUDE_MD"; then
  python3 - "$CLAUDE_MD" "$SNIPPET" "$START" "$END" <<'PY'
import sys, re
path, snippet_path, start, end = sys.argv[1:]
text = open(path, encoding="utf-8").read()
snippet = open(snippet_path, encoding="utf-8").read().rstrip("\n")
pattern = re.compile(re.escape(start) + r".*?" + re.escape(end), re.S)
text = pattern.sub(lambda _: snippet, text, count=1)
open(path, "w", encoding="utf-8").write(text)
PY
  echo "-- CLAUDE.md 규약 블록 교체"
else
  { [[ -s "$CLAUDE_MD" ]] && printf '\n'; cat "$SNIPPET"; } >> "$CLAUDE_MD"
  echo "-- CLAUDE.md 규약 블록 추가"
fi

# 4. 라벨
label_files=("$KIT_DIR/labels.json")
[[ -f "$TARGET/.github/ticket-labels.local.json" ]] && label_files+=("$TARGET/.github/ticket-labels.local.json")

api() { # method path [json]
  local method="$1" path="$2" data="${3:-}"
  local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
  curl -sS -o /dev/null -w '%{http_code}' -X "$method" \
    -H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json" -H "Content-Type: application/json" \
    ${data:+-d "$data"} "https://api.github.com$path"
}

created=0; updated=0
for f in "${label_files[@]}"; do
  while IFS=$'\t' read -r name color desc; do
    if command -v gh >/dev/null 2>&1; then
      if gh label create "$name" --repo "$SLUG" --color "$color" --description "$desc" >/dev/null 2>&1; then
        created=$((created+1))
      else
        gh label edit "$name" --repo "$SLUG" --color "$color" --description "$desc" >/dev/null && updated=$((updated+1))
      fi
    else
      [[ -n "${GITHUB_TOKEN:-${GH_TOKEN:-}}" ]] || { echo "라벨 생성을 건너뜀: gh 도 GITHUB_TOKEN 도 없음" >&2; break 2; }
      body="$(jq -nc --arg n "$name" --arg c "$color" --arg d "$desc" '{name:$n,color:$c,description:$d}')"
      code="$(api POST "/repos/$SLUG/labels" "$body")"
      if [[ "$code" == "201" ]]; then created=$((created+1))
      elif [[ "$code" == "422" ]]; then
        enc="$(jq -rn --arg n "$name" '$n|@uri')"
        code="$(api PATCH "/repos/$SLUG/labels/$enc" "$body")"
        [[ "$code" == "200" ]] && updated=$((updated+1)) || echo "라벨 갱신 실패 $name ($code)" >&2
      else echo "라벨 생성 실패 $name ($code)" >&2; fi
    fi
  done < <(jq -r '.[] | [.name, .color, .description] | @tsv' "$f")
done
echo "-- 라벨 생성 $created, 갱신 $updated"
echo "== 완료. 다음: Projects 보드는 GitHub 웹에서 만들고, 변경 파일을 커밋하세요."
