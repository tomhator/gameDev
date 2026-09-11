# gameDev
- Godot 엔진 개인 게임 개발의 허브 저장소. 기획 문서, 티켓 운영 키트, 닫은 프로젝트의 교훈을 모아 둔다.
- 개별 게임은 저장소를 따로 둔다(`tomhator/rainy-day`, `tomhator/drill-guard`, `tomhator/football-xcom`). 이 폴더 안의 게임 폴더는 스냅샷이거나 검증기다.

## 파일구조
```
gameDev
├── drill-guard     # 식민 행성 채굴 디펜스 — 8/10 스냅샷. 실제 개발은 tomhator/drill-guard
├── docs
│   ├── knowhow.md            # 닫은 프로젝트들에서 뽑은 노하우 (앞으로의 프로젝트가 먼저 읽는 문서)
│   ├── closed-projects.md    # 종료 프로젝트 대장 — 무엇·언제·왜·어디·건진 것
│   ├── backstreet-world.md   # 뒷골목(Backstreet) 세계관 컨셉 회수
│   ├── jigsaw-snap-idea.md   # 직소 손맛 아이디어 보관
│   ├── templates/            # 헌법 1장 · 플레이 노트 · 8색 팔레트 (#20 개발 루프)
│   ├── drill-guard-plan.md   # 기획 문서 (원본은 각 저장소 docs/)
│   ├── helldiver-lite-plan.md, survivor-extraction-plan.md, scavenger-salvage.md  # 종료 프로젝트 기획·부검
├── tools/ticket-kit # 티켓 운영 키트 — 게임 저장소마다 apply.sh 로 복사해 붙임
└── tools/gif-factory # 맥북 GIF 공장 — 구글 드라이브 녹화 → 홍보용 GIF 자동 생성
```

## 프로젝트 현황 (2026-09-11)
한 번에 하나(규약 개발 루프 4조). 지금 굴리는 것은 **rainy-day** 하나다.

| 상태 | 프로젝트 | 어디 |
|---|---|---|
| 진행 | rainy-day — 처마 투 처마, 시간을 되돌리는 비 (#37) | `tomhator/rainy-day` |
| 보류 | drill-guard — 인크리멘탈 × 디펜스 | `tomhator/drill-guard` |
| 보류 | football-xcom — 턴제 전술 축구 | `tomhator/football-xcom` |
| 종료 | helldiver-lite, jigsaw-snap, ProjectScavenger, projectMecha, project-jigsaw, MagicBookPrototype, BackstreetSample, 1~3월 학습 프로젝트 | `docs/closed-projects.md` |

> **보류의 뜻:** 새 티켓을 열지 않고, 손대지 않는다. 재개는 rainy-day가 공개 URL로 나간 뒤 결정한다.
> 규약 4조 "전작 출시 전 다음 시작 금지"에 대한 **명시적 예외**다 — 두 프로젝트 모두 미출시인 채로 멈춰 있고, 완료(공개 URL) 하나를 먼저 만드는 쪽을 택했다. 근거는 #37 댓글.

## 작업 방식
- 태스크는 GitHub Issues 티켓으로 관리한다. 규약은 `CLAUDE.md`, 키트는 `tools/ticket-kit/README.md`.
- 열린 티켓은 항상 `needs-human`(당신 차례) 아니면 `needs-claude`(Claude 차례).
- 당신 할 일 = [Assigned to me](https://github.com/tomhator/gameDev/issues/assigned/@me)
- 새 프로젝트를 시작할 때는 `docs/knowhow.md`를 먼저 읽는다. 개발 루프(완료=출시, 플레이 노트 게이트, 14일 사이클)는 `CLAUDE.md`.
