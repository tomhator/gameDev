# 스캐빈저 인양 목록 (Salvage Report)

> 2026-07-27, `tomhator/ProjectScavenger` 검토 결과.
> 원칙: **코드보다 교훈을, 시스템보다 부품을 가져온다.** 시스템을 이식하면 딸린 시스템이 줄줄이 따라온다.

## ✅ 가져올 것

| 항목 | 위치 (원본) | 무엇을 | 방법 |
|---|---|---|---|
| **Juice.gd** | `Scripts/Combat/Juice.gd` (107줄) | 히트스톱·셰이크·데미지 팝업·파편·플래시 | **그대로 복사** — 의존성 없는 autoload. 폴리싱 1~2주 절약 |
| 텔레그래프 문법 | `Scripts/Combat/Enemy.gd` `refresh_tint()` | 점화 점멸·차징 발광·약점 노출 등 "예고 신호" 패턴 | 패턴만 이식 (코드는 19병종에 결합 — 금지) |
| float HP 교훈 | `Enemy.gd` 상단 주석 | HP·피해 배수는 float 유지 (int 캐스팅 시 배수 보너스 내림 증발) | 규칙으로 채택 |
| WaveController 구조 | `Scripts/Combat/WaveController.gd` | 상태머신(IDLE→SIGNALED→OVERTIME→DONE) + `_prune` 무결성 패턴 | 구조 참고만 |
| selftest 습관 | `Scripts/Validation/selftest.gd` | 헤드리스 셀프테스트 운영 (원본 262 PASS 운영 실적) | 미니 버전으로 신규 작성 |
| STATUS.md 습관 | `Docs/STATUS.md` | "세션 시작 시 첫 파일 + 매 세션 덮어쓰기" — 하루 2~3시간 불규칙 작업에 유효 | 새 프로젝트에도 운영 |
| Tech Dungeon 팩 | `Asset/Tech Dungeon Roguelite - Asset Pack (DEMO)` | 던전 타일셋+플레이어+UI — 새 테마와 부합 | **팩 후보 1순위.** 풀버전(~$13) 라이선스 확인 후 결정 (0x72·Kenney와 비교) |

## ⛔ 가져오지 않을 것 (장르 청구서의 산물)

- `EnemySpawner.gd`(1,206줄) · `Firing.gd`(745줄) · `Combat.gd`(791줄)
- 멕 파츠+affix 시스템 전체 (`Scripts/Mech/`)
- 거점 허브·금고·작업대·퀘스트·빚 상환 (`Scripts/Base/`)
- 월드맵 (`Scripts/World/`) · 오염 시스템 (`Contamination.gd`) · 적 19병종 로스터

## 📌 메타 교훈: 가드레일은 목적지를 못 바꾼다

스캐빈저에는 이미 정교한 스코프 가드(`INVARIANTS.md` — 범위 닻·위반 신호·"의식한 변경 vs 표류")가 **있었다. 그런데도 폭발했다.**
가드가 지키던 "핵심"의 정의가 이미 거대했기 때문 — *"30분 런 + 전투 두 모드(서바+슈터) + 파츠 경제"* 는 핵심만으로 팀 규모다.

→ **결론: 지키는 장치보다 목적지의 크기가 먼저다.** 새 프로젝트의 핵심 = "런 5~8분 + 규칙 두 줄". 가드(원인원아웃·백로그 48시간·Go/No-Go)는 이 작은 목적지를 지킬 때만 작동한다.

## 이식 순서

1. 그레이박스 뼈대 세팅 시 `Juice.gd` 복사 (출처 주석 1줄)
2. 적 구현 시 텔레그래프 문법 + float HP 규칙 적용
3. 웨이브 구현 시 WaveController 구조 참고
4. 1~2주차 팩 확정 시 Tech Dungeon 풀버전 vs 0x72 vs Kenney 비교
