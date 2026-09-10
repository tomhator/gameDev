# 종료 프로젝트 대장

> 2026-09-10 정리(#19). 닫은 프로젝트는 여기에 한 줄씩 남는다. 코드는 각 저장소에 그대로 있고(아카이브), 교훈은 [`knowhow.md`](knowhow.md)에 모았다.
> 원칙: **닫는 것은 실패가 아니라 기록이다.** 닫을 때 "왜 멈췄나"와 "무엇을 건졌나"를 한 줄씩 적는다. 그게 없으면 닫은 게 아니라 방치한 것이다.

## 2026년 1월 ~ 9월 요약

| | 개수 |
|---|---|
| 시작한 게임 프로젝트 | 14 |
| 출시(공개 URL + 타인 플레이) | 0 |
| 이번에 종료 | 12 (아래 표) |
| 진행 중 | 2 (drill-guard, football-xcom) |
| 보류 | 1 (jigsaw-snap) |

닫는 시점에 세 프로젝트가 같은 문장을 갖고 있었다: *"미검증 = 실제 플레이 손맛. 아직 아무도 플레이 안 함."* 만드는 능력이 아니라 **만든 뒤의 한 칸**(플레이 → 보여주기 → 올리기)이 비어 있었다는 뜻이다. 다음 사이클의 완료 조건은 그래서 "공개 URL + 타인 플레이 1회"다.

## 종료 목록

| 프로젝트 | 저장소 | 기간 | 규모 | 무엇이었나 | 왜 멈췄나 | 건진 것 |
|---|---|---|---|---|---|---|
| **helldiver-lite** | [tomhator/helldiver-lite](https://github.com/tomhator/helldiver-lite) | 2026-07-27 → 08-12 | 115커밋, gd 12 | 솔로 헬다이버즈-라이트. 강하→목표→탈출 60초 버티기. 7/29 Go 판정, 무기 3종·적 4종, 출시일 9/28 | Go 이후 콘텐츠 블록 진입, 8/12 마지막 커밋 후 한 달 무소식. 방향 전환으로 종료 | 스코프 헌법·SCHEDULE 루틴·설계 하한(처치율) → knowhow §2, §3, §5-1·5-2, §7 기획서 사본: [`helldiver-lite-plan.md`](helldiver-lite-plan.md) |
| **ProjectScavenger** | [tomhator/ProjectScavenger](https://github.com/tomhator/ProjectScavenger) | 2026-06-11 → 07-26 | 336커밋, gd 56 | 익스트랙션 슈터. 적 19병종, 거점·퀘스트·빚 상환, 오염 시스템, 월드맵 | 스코프 폭발. 가드레일(INVARIANTS)이 있었지만 지키던 "핵심"의 정의가 이미 팀 규모였다 | Juice.gd, selftest 습관, STATUS 습관, 텔레그래프 문법, 아트 바이블 → [`scavenger-salvage.md`](scavenger-salvage.md), knowhow §1-7, §5-3, §6-2, §7-4 |
| **projectMecha** | [tomhator/projectMecha](https://github.com/tomhator/projectMecha) | 2026-04-28 → 06-11 | 160커밋, gd 38 | 메카 파츠 조립 게임. 스캐빈저의 전신 | 기획이 코어 시스템에서 수렴하지 못하고 반복 재설계, 문서 드리프트. README에 DEPRECATED 자체 선언 | GDD.md(재빌드용 기획 정본), 문서 드리프트 사례 → knowhow §1-2·1-4, §4-2·4-3, §5-3 |
| **project-jigsaw** | [tomhator/project-jigsaw](https://github.com/tomhator/project-jigsaw) | 2026-04-02 → 04-23 | 15커밋 | 조각(피스) 조합 전투 퍼즐. 이음새 규칙, 제조사 시너지 | 조합 폭발. "조각에 효과 하나만…"은 유령 | 조각 맞물림 수식, 조합 폭발 조기 신호 → knowhow §1-1, §5-4 |
| **MagicBookPrototype** | [tomhator/ProjectMagicBookPrototype](https://github.com/tomhator/ProjectMagicBookPrototype) | 2026-06-16 → 06-19 | 8커밋, 웹 | 마법서 크래프팅 웹 프로토. "만드는 행위 자체가 재미있는가?" | 검증 질문에 대한 답이 기록되지 않은 채 종료 | 빌드 도구 없는 웹 프로토 방식 → knowhow §1-2·1-4, §4-2·4-3, §5-3 |
| **BackstreetSample** | [tomhator/BackstreetSample](https://github.com/tomhator/BackstreetSample) | 2026-07-07 → 07-08 | 2커밋, gd 1 | 탐정 × 늑대개 전환 어드벤처 프로토(사건 #001) | 코드에 throwaway 명시. 프로토 종료 | 세계관·사건·존·단서 → [`backstreet-world.md`](backstreet-world.md) |
| dice-cacher | [tomhator/tomhator-dice-cacher](https://github.com/tomhator/tomhator-dice-cacher) | 2026-02-23 → 02-25 | 6커밋 | 모바일 소형(주사위 받기) | 학습용 | — |
| tappy | [tomhator/tomhator-tappy](https://github.com/tomhator/tomhator-tappy) | 2026-03-03 | 2커밋 | 모바일 소형(탭) | 학습용 | — |
| click-pop | [tomhator/click-pop](https://github.com/tomhator/click-pop) | 2026-03-11 → 03-13 | 3커밋 | 모바일 소형(클릭) | 학습용 | — |
| bounce-keeper | [tomhator/bounce-keeper](https://github.com/tomhator/bounce-keeper) | 2026-03-18 | 1커밋 | 모바일 소형(공 튀기기) | 학습용 | — |
| firstgame | 이 저장소 (커밋 `ccbd1de` 이전) | 2026-01-16 | 1커밋 | Godot 2D 플랫포머 튜토리얼 | 학습용 | — |
| dodge-the-creeps | 이 저장소 (커밋 `ccbd1de` 이전) | 2026-01-16 | 1커밋 | Godot 공식 튜토리얼 | 학습용 | — |

폴더 복구: `git checkout ccbd1de -- firstgame dodge-the-creeps helldiver-lite`

## 아카이브 절차 (사람)

각 저장소 → Settings → General → 맨 아래 "Archive this repository". 읽기 전용이 되고 이슈·푸시가 막힌다. 되돌릴 수 있다.
아카이브 전에 README 상단에 아래 한 줄을 붙이면 나중에 열어봐도 헷갈리지 않는다.

```
> 종료(2026-09-10). 이유와 건진 것은 tomhator/gameDev/docs/closed-projects.md 참조.
```
