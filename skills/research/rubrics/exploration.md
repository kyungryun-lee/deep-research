# 신규 탐색 평가 기준

최전선 연구, 새로운 영역 탐색을 위한 리서치 평가 기준입니다.
Analysis(분석깊이)와 Coverage(범위)의 가중치가 높습니다.

## 가중치 (Evaluator 자동 추출용)

```json
{"core":{"accuracy":0.15,"coverage":0.15,"recency":0.15,"structure_coherence":0.03},"context":{"proven":0.05,"actionability":0.08,"efficiency":0.04,"analysis":0.27,"citation_quality":0.05,"novelty":0.03},"sea_threshold":70,"hard_floor":{"accuracy":40,"cap":50}}
```

**코드 위임**: Structure & Coherence는 dr-score structure 100% 코드 계산
**Hard Floor**: Accuracy < 40이면 총점 50 상한
**Novelty**: 탐색 프로필 전용 — 기존 지식 대비 새로운 연결/통찰 여부

## 맥락 확장 특이사항

### Analysis (분석깊이) — 30%
| 점수 | 기준 |
|------|------|
| 90-100 | 교차 분석, 모순 식별, 패턴 도출, 미해결 문제 식별, 독자적 프레임워크 |
| 70-89 | 주요 비교 분석, 일부 교차 분석 |
| 0-69 | 단순 나열 |

### Proven — 5% (최저)
탐색 단계에서는 L0(이론만)도 가치 있음.

### Recency — 15% (높음)
최전선 연구는 최신성이 핵심.

## 소스 등급 (탐색용 — 학술 허용)
- **S**: peer-reviewed 논문 (NeurIPS/ICML/ICLR 등) + 공식 문서
- **A**: arXiv 프리프린트 + 기업 연구 블로그
- **B**: 개발자 블로그, 커뮤니티
- **C**: 마케팅, 비검증

## SEA 충족률 기준
- 70% 이상: 충분 (탐색은 완전성보다 방향 제시가 중요)

## 캘리브레이션 앵커 (Evaluator 참고용)

### 점수 90 예시 (High Quality)
- 교차 분석으로 모순 식별 + 패턴 도출
- 미해결 문제 식별 + 독자적 프레임워크 제시
- 최근 1-2년 소스 90%+, peer-reviewed 논문 다수
- 핵심 연구 흐름과 분기점을 명확히 매핑

### 점수 70 예시 (Acceptable)
- 주요 비교 분석, 일부 교차 분석 존재
- 최신 소스 70%+, arXiv 포함
- 방향은 제시하나 독자적 프레임워크 없음

### 점수 50 예시 (Needs Improvement)
- 단순 논문/기술 나열, 분석 깊이 부족
- 최신성 부족, 오래된 소스 다수
- 탐색 방향 불명확

### 점수 30 예시 (Poor)
- 할루시네이션 존재, 존재하지 않는 논문 인용
- 핵심 연구 흐름을 완전히 놓침
- 인용이 주장을 지지하지 않음, 소스 3건 미만
