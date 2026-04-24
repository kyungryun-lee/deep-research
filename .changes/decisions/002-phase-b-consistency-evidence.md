# ADR-002: Phase B — 일관성 보장 + Evidence Grounding 설계

**일자**: 2026-04-25
**상태**: 설계 완료 (적용 대기)
**근거**: 4개 병렬 리서치 에이전트 조사 결과 종합

---

## 문제 정의

### 1. 일관성 (Consistency)
같은 주제에 대해 반복 리서치 시 매번 다른 소스, 다른 결론이 나와 축적이 불가능.
SOTA 시스템 (ADORE, PRIME) 대비 가장 큰 격차 (C등급).

### 2. Evidence Grounding
주장과 근거의 명시적 매핑이 없어 할루시네이션 검출이 자기 평가에만 의존.
ADORE의 Claim-Evidence Graph가 현 SOTA.

### 3. 검색 깊이
Worker들이 독립 병렬 검색만 수행, 이전 결과를 다음 검색에 반영하지 않음.
Chain-of-Retrieval 부재.

---

## 설계

### B-1. Core-Peripheral 이중 지식 구조

```
${CLAUDE_PLUGIN_DATA}/knowledge/
├── {topic-hash}/
│   ├── core-facts.json      # 검증 확정된 핵심 팩트
│   ├── peripheral.json       # 유연한 주변 정보 (매 세션 갱신)
│   ├── anchor-sources.json   # 고정 핵심 소스 목록
│   └── meta.json             # 주제 메타 (생성일, 최종갱신, 리서치횟수)
```

#### core-facts.json 스키마
```json
{
  "topic": "agentic research systems",
  "topic_hash": "abc123",
  "facts": [
    {
      "id": "CF-001",
      "claim": "ADORE의 Claim-Evidence Graph가 DeepResearch Bench 1위",
      "evidence": [
        {"url": "https://arxiv.org/abs/2601.18267", "tier": "A", "excerpt": "52.65점..."}
      ],
      "cross_verified": true,
      "verification_count": 2,
      "created_at": "2026-04-25",
      "updated_at": "2026-04-25"
    }
  ],
  "version": 1
}
```

#### 업데이트 규칙
- **코어 진입 조건**: 2개+ 독립 소스에서 교차 검증 완료
- **코어 수정 조건**: 명시적 반증 근거 + 새 소스 2개+ 제출 시에만
- **주변 정보**: 매 리서치 시 자유 갱신, 코어와 충돌 시 경고
- **앵커 소스**: 코어 팩트의 출처 URL + 등급, 다음 리서치 시 재확인 우선

#### 저장 시점
- Synthesizer가 보고서 생성 시 facts를 core/peripheral로 분류하여 저장
- 저장은 `bin/dr-knowledge save` 스크립트가 수행 (AI 호출 0)

---

### B-2. Claim-Evidence 매핑

현재: 소스 목록은 있지만, "어떤 주장이 어떤 소스에서 나왔는가" 매핑 없음.

#### 변경: Synthesizer 출력에 claim-evidence 구조 추가

보고서의 각 핵심 발견에 evidence 태그를 부착:
```markdown
### 1. ADORE가 DeepResearch Bench 1위
{발견 내용}
- **Evidence**: [arXiv:2601.18267](url) (A등급) — "52.65점, 77.2% 승률"
- **Cross-verified by**: [DeepConsult Benchmark](url2) (A등급)
- **Confidence**: HIGH (2개 독립 소스)
```

#### claim-evidence.json (기계 처리용)
```json
{
  "claims": [
    {
      "id": "CL-001",
      "text": "ADORE가 DeepResearch Bench 1위",
      "evidence": [
        {"url": "...", "tier": "A", "excerpt": "...", "page": "results"}
      ],
      "confidence": "high",
      "cross_verified": true
    }
  ],
  "unverified_claims": [
    {"id": "CL-005", "text": "...", "confidence": "low", "reason": "단일 소스"}
  ]
}
```

#### Evaluator 활용
- Evaluator가 claim-evidence 매핑을 받으면:
  - evidence 없는 claim → 즉시 감점 (할루시네이션 의심)
  - 단일 소스 claim → [미교차검증] 경고
  - 코드로 claim 수 vs evidence 수 비율 계산 → 커버리지 메트릭

---

### B-3. 앵커 소스 시스템

```json
// anchor-sources.json
{
  "topic_hash": "abc123",
  "anchors": [
    {"url": "https://arxiv.org/abs/2601.18267", "tier": "A", "role": "primary", "last_verified": "2026-04-25"},
    {"url": "https://docs.anthropic.com/...", "tier": "S", "role": "authoritative", "last_verified": "2026-04-25"}
  ],
  "max_new_sources": 10
}
```

#### Planner 통합
- Planner가 주제 hash로 기존 knowledge 조회
- 앵커 소스가 있으면 Worker에게 "이 소스를 먼저 재확인하고, 추가 탐색은 앵커 외 영역만" 지시
- Worker 쿼리에 앵커 소스 URL을 제외하여 다양성 확보

---

### B-4. Chain-of-Retrieval (순차 검색 강화)

현재: 모든 Worker가 완전 독립 병렬 실행
변경: 2단계 실행

```
[1단계 — 병렬 탐색] (현재와 동일)
  Worker 1~N 동시 실행 → 초기 발견

[2단계 — 심화 검색] (신규)
  1단계 결과에서 gap/모순 식별 → 타겟 심화 Worker 실행
  이전 결과를 컨텍스트로 전달하여 검색 조건화
```

#### SKILL.md Phase 3 변경안
```
Phase 3A: EXECUTE (병렬 탐색)
  → 기존과 동일, 모든 Worker 병렬

Phase 3B: GAP ANALYSIS (코드 + AI)
  → 1단계 결과에서 SEA 미충족 항목 식별 (코드: dr-score sea)
  → 소스 다양성 검사 (코드: 도메인 분포)
  → gap이 있으면 심화 Worker 1-2개 추가 실행

Phase 3C: DEEP RETRIEVAL (조건부 순차)
  → gap 영역에 대해 "이전 결과를 참고하여 부족한 부분을 채워주세요" 형태로 실행
  → Chain-of-Retrieval: 이전 Worker 결과 요약을 프롬프트에 포함
```

---

### B-5. bin/dr-knowledge 스크립트 (신규)

```
dr-knowledge save --topic "topic" < facts.json   # core/peripheral 저장
dr-knowledge load --topic "topic"                  # 기존 knowledge 로드
dr-knowledge anchors --topic "topic"               # 앵커 소스 목록
dr-knowledge match --query "query"                 # 유사 주제 매칭
dr-knowledge stats                                 # 전체 knowledge 통계
dr-knowledge conflicts --topic "topic"             # 코어 vs 신규 충돌 검출
```

topic matching: TF-IDF 기반 코사인 유사도 (sklearn 불필요, 순수 Python 구현)

---

## 변경 파일 목록

| 파일 | 변경 유형 | 내용 |
|------|----------|------|
| bin/dr-knowledge | 신규 | 지식 저장/로드/매칭/충돌검출 CLI |
| skills/research/SKILL.md | 수정 | Phase 1-2에 knowledge 로드, Phase 3 2단계 분리, Phase 5에 knowledge 저장 |
| agents/research-planner.md | 수정 | 앵커 소스/코어 팩트 활용 전략 |
| agents/research-worker.md | 수정 | 앵커 소스 재확인 + gap 기반 심화 검색 |
| agents/research-synthesizer.md | 수정 | claim-evidence 매핑 출력 + knowledge 저장 |
| agents/research-evaluator.md | 수정 | claim-evidence 기반 할루시네이션 검증 |
| tests/validate-plugin.sh | 수정 | knowledge 관련 테스트 추가 |

---

## 예상 효과

| 영역 | 현재 | Phase B 후 | SOTA 대비 |
|------|------|-----------|----------|
| 일관성 | C (매 세션 독립) | A- (코어 팩트 고정 + 증분) | ADORE급 근접 |
| Citation grounding | B- (소스 목록만) | A (claim↔evidence 매핑) | ADORE급 |
| 검색 깊이 | B- (독립 병렬만) | B+ (2단계 + Chain-of-Retrieval) | 부분 적용 |
| 학습/메모리 | B (에피소딕만) | A- (에피소딕 + 시맨틱 knowledge) | PRIME급 근접 |

---

## 구현 순서 (권장)

1. **B-5: bin/dr-knowledge** — 코어 인프라 먼저
2. **B-1: Core-Peripheral 구조** — Synthesizer 연동
3. **B-2: Claim-Evidence 매핑** — Evaluator 연동
4. **B-3: 앵커 소스** — Planner/Worker 연동
5. **B-4: Chain-of-Retrieval** — Phase 3 분리
6. 통합 테스트

---

## 위험 및 완화

| 위험 | 영향 | 완화 |
|------|------|------|
| Knowledge DB 스키마 변경 | 기존 데이터 호환성 | version 필드 + 마이그레이션 |
| 코어 팩트 과도 고정 | 새 정보 차단 | 명시적 반증 규칙 + 만료일 |
| Chain-of-Retrieval 지연 | 실행 시간 증가 | gap 없으면 2단계 건너뜀 |
| 복잡도 증가 | 유지보수 부담 | 각 기능 독립 스크립트로 분리 |
