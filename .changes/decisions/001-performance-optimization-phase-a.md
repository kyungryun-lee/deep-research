# ADR-001: Performance Optimization Phase A

**Date**: 2026-04-23
**Status**: Implementing
**Source**: deep-research 자기개선 리서치 (성능 최적화 방법론)

## Context

현재 플러그인은 모든 Phase에서 Opus 모델을 사용하고, Worker 출력이 장문이며,
Planner의 JSON 출력이 비구조적이어서 파싱 실패 위험이 있음.

리서치 결과 (Verifier 독립 평가 73점):
- 모델 라우팅으로 41-80% 비용 절감 가능 (Anthropic 공식 가격표 기반)
- 출력 간결화로 출력 토큰 50%+ 절감 가능
- Structured Output으로 파싱 실패율 0% 달성 가능

## Decision

1. Planner: Opus → **Sonnet** (전략 수립은 Sonnet으로 충분)
2. Worker: effort medium → **low** (검색/수집은 단순 작업)
3. Worker: 소스당 출력을 **3문장 이내**로 제한
4. Planner: JSON 출력을 **output_schema 태그로 구조화**

## Consequences

- **긍정**: 비용 약 48% 절감, 파싱 안정성 향상
- **위험**: Planner 품질 저하 가능 → Phase 5(Opus)에서 보완
- **롤백**: 각 파일의 model/effort 값을 원복하면 됨

## Metrics (before)

- Planner model: opus ($5/MTok input)
- Worker effort: medium
- Worker output: 제한 없음 (장문)
- Planner JSON: 스키마 미정의
