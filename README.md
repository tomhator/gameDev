# gameDev
- godot 엔진을 활용한 개인 게임 개발 프로젝트 폴더
- 모든 프로젝트를 관리하는 폴더

## 파일구조
```
gameDev
├── fisrtgame
├── Dodge the Creeps
├── helldiver-lite  # 솔로 헬다이버즈-라이트 (탑다운 슈터 로그라이트) — 진행 중
├── jigsaw-snap     # 직소 손맛 토이 (프로토타입/검증기) — 보류
├── drill-guard     # 식민 행성 채굴 디펜스 (인크리멘탈 × 디펜스) — 그레이박스
├── docs            # 프로젝트 기획 문서
├── tools/ticket-kit # 티켓 운영 키트 — 게임 저장소마다 apply.sh 로 복사해 붙임
└── tools/gif-factory # 맥북 GIF 공장 — 구글 드라이브 녹화 → 홍보용 GIF 자동 생성
```

## 작업 방식
- 태스크는 GitHub Issues 티켓으로 관리한다. 규약은 `CLAUDE.md`, 키트는 `tools/ticket-kit/README.md`.
- 열린 티켓은 항상 `needs-human`(당신 차례) 아니면 `needs-claude`(Claude 차례).
- 당신 할 일 = [Assigned to me](https://github.com/tomhator/gameDev/issues/assigned/@me)
