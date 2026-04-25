# PoC 검증 평가 기준

가능성 확인, 개념 증명을 위한 리서치 평가 기준입니다.
Analysis(분석깊이)의 가중치가 가장 높습니다.

## 가중치 (Evaluator 자동 추출용)

```json
{"core":{"accuracy":0.15,"coverage":0.10,"recency":0.10,"structure_coherence":0.03},"context":{"proven":0.10,"actionability":0.15,"efficiency":0.05,"env_fit":0.05,"analysis":0.22,"citation_quality":0.05},"sea_threshold":70,"hard_floor":{"accuracy":40,"cap":50}}
```

**코드 위임**: Structure & Coherence는 dr-score structure 100% 코드 계산
**Hard Floor**: Accuracy < 40이면 총점 50 상한

## 맥락 확장 특이사항

### Analysis (분석깊이) — 25%
| 점수 | 기준 |
|------|------|
| 90-100 | 메커니즘 비교, 한계점 분석, 이론적 근거, 가능/불가능 판정 근거 |
| 70-89 | 주요 비교 분석 있으나 일부 영역 피상적 |
| 0-69 | 단순 나열 |

### Proven — 10% (낮음)
PoC는 L1(개념 검증) 수준도 허용. L0만 아니면 됨.

### Efficiency — 5% (낮음)
가능성 확인이 목적이므로 비용 효율은 부차적.

## SEA 충족률 기준
- 70% 이상: 충분 (PoC는 완전성보다 핵심 가능성 확인이 중요)

## 캘리브레이션 앵커 (Evaluator 참고용)

### 점수 90 예시 (High Quality)
- 메커니즘 비교 + 한계점 + 이론적 근거 완비
- 가능/불가능 판정이 명확한 근거와 함께 제시
- PoC 코드 포함, 재현 가능한 실험 설계
- L1+ 검증 수준, 핵심 기술적 리스크 식별

### 점수 70 예시 (Acceptable)
- 주요 비교 분석 있으나 일부 피상적
- 가능성은 판단했으나 근거가 불충분한 부분 존재
- 코드 스니펫 일부, 완전 재현은 불가

### 점수 50 예시 (Needs Improvement)
- 단순 나열, 분석 깊이 부족
- 가능/불가능 판정 근거 미제시
- 이론만, 실현 가능성 미검증

### 점수 30 예시 (Poor)
- 할루시네이션 존재, 가짜 벤치마크 인용
- 검증 대상 기술의 기본 개념 오류
- 인용 소스가 주장을 지지하지 않음
