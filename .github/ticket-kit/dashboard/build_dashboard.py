#!/usr/bin/env python3
"""ticket-kit 상황판 생성기.

    tools/ticket-kit/dashboard/build_dashboard.py <대상 저장소 경로> [--repo owner/repo] [--out 파일]

GitHub API에서 이슈·마일스톤을 읽어 template.html 을 채운 완성 HTML 을 만든다. 브라우저 JS 없이 그대로 보인다.
설정은 <대상>/.github/ticket-dashboard.json (없으면 저장소 전체를 프로젝트 하나로).
인증: GITHUB_TOKEN 또는 GH_TOKEN.
"""
import argparse, datetime as dt, glob, json, os, pathlib, re, subprocess, sys, urllib.parse, urllib.request

HERE = pathlib.Path(__file__).resolve().parent
COURT = ("needs-human", "needs-claude")
KINDS = ("idea", "bug", "tuning", "feature", "decision", "playtest", "question")
# 단계 라이프사이클 (#31). 순서가 곧 칸반 열 순서.
STAGES = ("stage:idea", "stage:spec", "stage:build", "stage:test", "stage:art", "stage:verify")
STAGE_NAME = {"stage:idea": "아이디어", "stage:spec": "기획", "stage:build": "구현",
              "stage:test": "테스트", "stage:art": "아트", "stage:verify": "검수"}
STAGE_OWNER = {"stage:idea": "h", "stage:spec": "h", "stage:build": "c",
               "stage:test": "h", "stage:art": "c", "stage:verify": "h"}
STAGE_LIMIT = {"stage:idea": 5, "stage:build": 1, "stage:art": 1}
ACTIVE_STAGES = STAGES[1:]   # 기획~검수
ACTIVE_LIMIT = 3


def api(path, token):
    req = urllib.request.Request("https://api.github.com" + path, headers={
        "Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def paged(path, token):
    out, page = [], 1
    while True:
        sep = "&" if "?" in path else "?"
        chunk = api(f"{path}{sep}per_page=100&page={page}", token)
        out += chunk
        if len(chunk) < 100:
            return out
        page += 1


def slug_from_git(target):
    try:
        url = subprocess.check_output(["git", "-C", str(target), "remote", "get-url", "origin"], text=True).strip()
    except Exception:
        return None
    m = re.sub(r"^(https://github.com/|git@github.com:)", "", url)
    return re.sub(r"\.git$", "", m)


def yaml_scalar(text, key):
    m = re.search(rf'^{key}:\s*"?(.*?)"?\s*$', text, re.M)
    return m.group(1) if m else ""


def load_templates(target):
    """이슈 폼 파일에서 버튼 정보(파일명, 이름, 제목 접두, 라벨)를 읽는다. PyYAML 없이 동작."""
    forms = []
    for f in sorted(glob.glob(str(target / ".github/ISSUE_TEMPLATE/[0-9]*.yml"))):
        text = open(f, encoding="utf-8").read()
        labels = re.findall(r'"([^"]+)"', yaml_scalar(text, "labels"))
        forms.append({"file": os.path.basename(f), "name": yaml_scalar(text, "name"),
                      "title": yaml_scalar(text, "title"), "labels": labels})
    return forms


def slim(issue):
    labels = [l["name"] for l in issue["labels"]]
    return {
        "n": issue["number"], "title": issue["title"], "url": issue["html_url"], "state": issue["state"],
        "labels": labels,
        "court": next((c for c in COURT if c in labels), None),
        "kind": next((k for k in KINDS if k in labels), None),
        "stage": next((s for s in STAGES if s in labels), None),
        "over": "wip-over" in labels,
        "milestone": issue["milestone"]["title"] if issue.get("milestone") else None,
        "created": issue["created_at"], "updated": issue["updated_at"], "closed": issue.get("closed_at"),
        "comments": issue["comments"],
    }


KST = dt.timezone(dt.timedelta(hours=9))
KIND_ICON = {"idea": "💡", "bug": "🐛", "tuning": "🎚", "feature": "🧩", "decision": "⚖️", "playtest": "🎮", "question": "❓"}
HOT = {"decision": 0, "playtest": 1, "question": 2}


def esc(s):
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def kst(iso):
    return dt.datetime.fromisoformat(iso.replace("Z", "+00:00")).astimezone(KST)


def ago(iso, now):
    m = round((now - kst(iso)).total_seconds() / 60)
    if m < 60: return f"{max(m, 1)}분 전"
    if m < 48 * 60: return f"{round(m / 60)}시간 전"
    return f"{round(m / 1440)}일 전"


def chips(i, proj_labels):
    h = ""
    if i["kind"]: h += f'<span class="chip">{KIND_ICON.get(i["kind"], "")} {i["kind"]}</span>'
    if i.get("stage"): h += f'<span class="chip st">{esc(STAGE_NAME[i["stage"]])}</span>'
    if i.get("over"): h += '<span class="chip over">WIP 초과</span>'
    p = next((l for l in i["labels"] if l in proj_labels), None)
    if p: h += f'<span class="chip p">{esc(p)}</span>'
    if i["milestone"]: h += f'<span class="chip ms">{esc(i["milestone"])}</span>'
    if i["comments"]: h += f'<span class="chip ms">💬 {i["comments"]}</span>'
    return h


def rows(lst, proj_labels, now, empty, hot=False, closed=False):
    if not lst:
        return f'<div class="empty">{empty}</div>'
    out = []
    for i in lst:
        cls = "row hot" if hot and i["kind"] in HOT else "row"
        age = ("닫힘 " + ago(i["closed"], now)) if closed else ago(i["updated"], now)
        out.append(f'<a class="{cls}" href="{i["url"]}" target="_blank" rel="noopener"><span class="n">#{i["n"]}</span>'
                   f'<span><div class="t">{esc(i["title"])}</div><div class="meta">{chips(i, proj_labels)}</div></span>'
                   f'<span class="age">{age}</span></a>')
    return "".join(out)


def new_issue_url(repo, form, proj_label):
    labels = list(form["labels"]) + ([proj_label] if proj_label else [])
    title = form["title"] + (proj_label + ": " if proj_label else "")
    q = urllib.parse.urlencode({"template": form["file"], "labels": ",".join(labels), "title": title})
    return f"https://github.com/{repo}/issues/new?{q}"


def throw_row(repo, forms, proj_label):
    btns = []
    for f in forms:
        court = "h" if "needs-human" in f["labels"] else "c"
        short = re.sub(r"\s*\(.*\)\s*$", "", f["name"])
        btns.append(f'<a class="btn {court}" href="{esc(new_issue_url(repo, f, proj_label))}" target="_blank" rel="noopener" title="{esc(f["name"])}">{esc(short)}</a>')
    return '<div class="throw"><span>티켓 던지기</span>' + "".join(btns) + "</div>"


def gauge(n, limit):
    """WIP 게이지. 상한이 없으면 개수만."""
    if not limit:
        return f'<span class="wip"><b>{n}</b></span>'
    pct = min(round(n / limit * 100), 100)
    cls = "wip over" if n > limit else ("wip full" if n == limit else "wip")
    return (f'<span class="{cls}"><b>{n}</b>/{limit}<i class="bar"><i style="width:{pct}%"></i></i></span>')


def kanban(is_open):
    """단계별 칸반 6열 + WIP 게이지. 단계 없는 티켓(decision/question/playtest)은 빠진다."""
    cols = []
    for s in STAGES:
        mine = sorted([i for i in is_open if i["stage"] == s], key=lambda i: i["updated"], reverse=True)
        cards = "".join(
            f'<a class="k{" over" if i["over"] else ""}" href="{i["url"]}" target="_blank" rel="noopener">'
            f'<span class="n">#{i["n"]}</span><span class="t">{esc(i["title"])}</span>'
            f'<span class="ct {i["court"][6] if i["court"] else ""}"></span></a>'
            for i in mine) or '<div class="empty">비어 있음</div>'
        cols.append(f'<div class="col {STAGE_OWNER[s]}"><div class="ch"><span>{esc(STAGE_NAME[s])}</span>'
                    f'{gauge(len(mine), STAGE_LIMIT.get(s))}</div><div class="body">{cards}</div></div>')
    active = sum(1 for i in is_open if i["stage"] in ACTIVE_STAGES)
    staged = sum(1 for i in is_open if i["stage"])
    note = (f'<div class="klegend">진행 중(기획~검수 합계) {gauge(active, ACTIVE_LIMIT)}'
            f'<span class="sp">단계 있는 티켓 {staged} · 단계 없음(decision/question/playtest)은 위 목록에서</span></div>')
    return '<div class="kan">' + "".join(cols) + "</div>" + note


def render(data):
    now = kst(data["snapshot"])
    repo, issues, forms = data["repo"], data["issues"], data["forms"]
    proj_labels = [p["label"] for p in data["projects"] if p.get("label")]
    is_open = [i for i in issues if i["state"] == "open"]
    human = sorted([i for i in is_open if i["court"] == "needs-human"], key=lambda i: (HOT.get(i["kind"], 9), i["updated"]))
    claude = sorted([i for i in is_open if i["court"] == "needs-claude"], key=lambda i: i["updated"], reverse=True)
    orphan = [i for i in is_open if not i["court"]]
    done = sorted([i for i in issues if i["state"] == "closed"], key=lambda i: i["closed"] or "", reverse=True)[:10]
    week = now - dt.timedelta(days=7)
    closed_week = sum(1 for i in issues if i["closed"] and kst(i["closed"]) > week)

    links = [(f"https://github.com/{repo}/issues/assigned/@me", "Assigned to me"), (f"https://github.com/{repo}/issues", "모든 이슈"),
             (f"https://github.com/{repo}/projects", "Projects 보드"), (f"https://github.com/{repo}/milestones", "마일스톤")]
    strip = (f'<div class="stat h"><b>{len(human)}</b><small>당신 코트</small></div>'
             f'<div class="stat c"><b>{len(claude)}</b><small>Claude 코트</small></div>'
             f'<div class="stat"><b>{len(is_open)}</b><small>열린 티켓 전체{" · 코트 없음 " + str(len(orphan)) if orphan else ""}</small></div>'
             f'<div class="stat d"><b>{closed_week}</b><small>이번 주 닫힘</small></div>')

    cards = []
    for p in data["projects"]:
        lab = p.get("label")
        mine = [i for i in is_open if not lab or lab in i["labels"]]
        allp = [i for i in issues if not lab or lab in i["labels"]]
        h = sum(1 for i in mine if i["court"] == "needs-human"); c = sum(1 for i in mine if i["court"] == "needs-claude")
        ms = [m for m in data["milestones"] if not lab or m["title"].startswith(lab + ":") or m["title"].startswith(lab + " ")]
        last = max((i["updated"] for i in allp), default=None)
        parked = "보류" in (p.get("stage") or "")
        if ms:
            parts = []
            for m in ms:
                tot = m["open"] + m["closed"]; pct = round(m["closed"] / tot * 100) if tot else 0
                name = m["title"].replace(lab + ":", "").strip() if lab else m["title"]
                parts.append(f'<div class="one"><a href="{m["url"]}" target="_blank" rel="noopener">{esc(name)}</a><span>{m["closed"]}/{tot} · {pct}%</span>'
                             f'<div class="bar"><i style="width:{pct}%"></i></div></div>')
            ms_html = "".join(parts)
        else:
            ms_html = '<div class="none">마일스톤 없음</div>'
        cards.append(f'<div class="card{" parked" if parked else ""}">'
                     f'<div class="head"><div><h3>{esc(p["name"])}</h3><div class="desc">{esc(p.get("desc") or "")}</div></div><span class="stage">{esc(p.get("stage") or "")}</span></div>'
                     f'<div class="counts"><span class="h"><b>{h}</b> 당신</span><span class="c"><b>{c}</b> Claude</span><span><b>{len(mine)}</b> 열림</span><span><b>{len(allp) - len(mine)}</b> 닫힘</span></div>'
                     f'<div class="ms">{ms_html}</div><div class="last">마지막 움직임 {ago(last, now) if last else "없음"}</div>'
                     f'{throw_row(repo, forms, lab)}</div>')

    foot = (f'이 화면은 Claude가 세션을 시작하고 끝낼 때 GitHub에서 다시 읽어 갱신합니다. 그 사이의 변화는 '
            f'<a href="https://github.com/{repo}/issues" target="_blank" rel="noopener"><u>GitHub 이슈</u></a>가 정확합니다. '
            f'"티켓 던지기" 버튼은 GitHub 이슈 폼을 템플릿·라벨이 채워진 채로 엽니다. 주황 테두리는 당신 코트로, 파랑 테두리는 Claude 코트로 가는 티켓입니다. '
            f'단계 칸반의 열 왼쪽 색은 그 단계를 넘기는 사람(주황=당신, 파랑=Claude), 카드 오른쪽 점은 지금 코트입니다. '
            f'게이지가 빨강이면 동시 진행 제한을 넘긴 것으로, 자리를 비우기 전에는 진행하지 않습니다.')
    return {
        "__TITLE__": esc(data["title"]),
        "__SNAP__": now.strftime("%Y-%m-%d %H:%M KST 기준 스냅샷"),
        "__LINKS__": "".join(f'<a href="{u}" target="_blank" rel="noopener">{t}</a>' for u, t in links),
        "__STRIP__": strip,
        "__CNT_H__": str(len(human)), "__CNT_C__": str(len(claude)), "__CNT_D__": str(len(done)),
        "__KANBAN__": kanban(is_open),
        "__HUMAN__": rows(human, proj_labels, now, "비어 있음. 구경꾼 모드 — Claude가 곧 뭔가 던질 것", hot=True),
        "__CLAUDE__": rows(claude, proj_labels, now, "비어 있음. 티켓을 던져 주세요"),
        "__DONE__": rows(done, proj_labels, now, "아직 닫힌 티켓 없음", closed=True),
        "__CARDS__": "".join(cards),
        "__FOOT__": foot,
        "__DATA__": json.dumps(data, ensure_ascii=False),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("target")
    ap.add_argument("--repo")
    ap.add_argument("--out")
    a = ap.parse_args()
    target = pathlib.Path(a.target).resolve()
    slug = a.repo or slug_from_git(target)
    if not slug or "/" not in slug:
        sys.exit("owner/repo 를 알 수 없습니다. --repo 로 지정하세요.")
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN") or sys.exit("GITHUB_TOKEN 이 필요합니다.")

    cfg_path = target / ".github/ticket-dashboard.json"
    cfg = json.load(open(cfg_path, encoding="utf-8")) if cfg_path.exists() else {}
    projects = cfg.get("projects") or [{"label": None, "name": slug.split("/")[1], "desc": "", "stage": ""}]

    issues = [slim(i) for i in paged(f"/repos/{slug}/issues?state=all", token) if "pull_request" not in i]
    milestones = [{"title": m["title"], "open": m["open_issues"], "closed": m["closed_issues"],
                   "state": m["state"], "url": m["html_url"], "desc": m.get("description") or ""}
                  for m in paged(f"/repos/{slug}/milestones?state=all", token)]

    data = {
        "repo": slug,
        "title": cfg.get("title") or f"{slug.split('/')[1]} 상황판",
        "snapshot": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "projects": projects,
        "issues": issues,
        "milestones": milestones,
        "forms": load_templates(target),
    }
    html = open(HERE / "template.html", encoding="utf-8").read()
    for k, v in render(data).items():
        html = html.replace(k, v)
    out = pathlib.Path(a.out) if a.out else HERE / "out" / f"{slug.replace('/', '-')}.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")
    open_n = sum(1 for i in issues if i["state"] == "open")
    human = sum(1 for i in issues if i["state"] == "open" and i["court"] == "needs-human")
    print(f"{out}  (열린 티켓 {open_n}, 당신 코트 {human}, 마일스톤 {len(milestones)})")


if __name__ == "__main__":
    main()
