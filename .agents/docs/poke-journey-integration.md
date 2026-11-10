# poke-journey에서 Game Studios 사용하기

이 설치는 `swift-tong/Codex-Game-Studios`의 Codex용 스킬 72개와 참조 문서·역할 정의를 사용한다. 원본은 `Donchitos/Claude-Code-Game-Studios`다. 버전은 `../game-studios-install.json`에 기록한다. 루트 템플릿과 Claude 훅은 복사하지 않았다.

## 프로젝트 기준

- 엔진: Godot 4.7, GDScript, GL Compatibility (`project.godot` 기준).
- 게임: 기존 poke-journey(이전 poke-arena). 내용과 결정은 루트 `README.md` 및 기존 `docs/`를 확인한다.
- 코드: `scripts/`, 장면: `scenes/`, 자산: `assets/`, 검증 도구: `tools/`, 테스트: `test/`.
- Godot 기준 논리 화면은 384×216. 검증 창과 저장 파일 격리는 루트 `AGENTS.md`를 따른다.
- `src/`, `design/gdd/`, `production/`는 템플릿 예시다. 실제로 없는 입력이나 설계 목표는 없다고 보고한다.
- 역할 49개는 참조용 정의다. 실제 사용 가능한 협업 도구와 상위 지시에 맞춰 필요한 역할만 사용한다.

## 작업 선택

| 작업 | 읽을 스킬 |
| --- | --- |
| 기능 기획 | `quick-design`, `design-system` |
| 전투·성장·경제 | `balance-check` |
| 인터페이스 | `ux-design`, `ux-review` |
| 자산 점검 | `asset-audit` |
| 구현 검토 | `code-review` |
| 검증 | `qa-plan`, `smoke-check`, `regression-suite`, `test-evidence-review` |

도트·움직임·이펙트는 기존 `generate2dsprite`·`video2dsprite`·`pixelfx` 절차와 샘플 비교 규칙을 함께 따른다. Agent Sprite Forge Python 도구는 `~/.local/share/agent-sprite-forge/venv/bin/python`으로 실행한다.

## 충돌 처리와 증거

사용자 지시와 루트 `AGENTS.md`가 우선한다. 템플릿의 파일명·텍스처 크기·문서 분량·테스트 커버리지 예시는 이 프로젝트의 새 필수 조건이 아니다. 실제 코드·데이터·사용자가 정한 기준으로 검토하고, 검증하지 못한 항목은 미검증으로 명시한다. 외부 자료나 기억만으로 전투 배율·원본 에셋·저장 호환성을 변경하지 않는다.

Superpowers는 설계·계획·디버깅·검증 절차에 사용한다. Claude-Mem은 설치·연결·관측·검색 상태를 구분하며, 기억은 현재 파일로 재확인한다. 추가 유료 서비스나 계정 연결은 설치와 별개로 사용자 선택이 필요하다.
