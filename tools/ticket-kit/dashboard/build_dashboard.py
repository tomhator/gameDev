#!/usr/bin/env python3
"""ticket-kit 상황판 생성기.

    tools/ticket-kit/dashboard/build_dashboard.py <대상 저장소 경로> [--repo owner/repo] [--out 파일]

GitHub API에서 이슈·마일스톤을 읽어 template.html 에 데이터를 심은 HTML 을 만든다.
설정은 <대상>/.github/ticket-dashboard.json (없으면 저장소 전체를 프로젝트 하나로).
인증: GITHUB_TOKEN 또는 GH_TOKEN.
"""
import argparse, datetime as dt, glob, json, os, pathlib, re, subprocess, sys, urllib.parse, urllib.request

HERE = pathlib.Path(__file__).resolve().parent
COURT = ("needs-human", "needs-claude")
KINDS = ("idea", "bug", "tuning", "feature", "decision", "playtest", "question")


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
        "milestone": issue["milestone"]["title"] if issue.get("milestone") else None,
        "created": issue["created_at"], "updated": issue["updated_at"], "closed": issue.get("closed_at"),
        "comments": issue["comments"],
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
    html = open(HERE / "template.html", encoding="utf-8").read().replace("__DATA__", json.dumps(data, ensure_ascii=False))
    out = pathlib.Path(a.out) if a.out else HERE / "out" / f"{slug.replace('/', '-')}.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")
    open_n = sum(1 for i in issues if i["state"] == "open")
    human = sum(1 for i in issues if i["state"] == "open" and i["court"] == "needs-human")
    print(f"{out}  (열린 티켓 {open_n}, 당신 코트 {human}, 마일스톤 {len(milestones)})")


if __name__ == "__main__":
    main()
