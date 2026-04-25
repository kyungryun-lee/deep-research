# Deep Research Plugin v2.4 — 메타 평가 보고서

**작성일**: 2026-04-25
**리서치 방법**: 5개 병렬 에이전트 × SOTA 조사 (총 70+ 웹소스)
**대상**: `/home/worker/claude/deep-research/` (5,246줄, 59건 변경이력, 88개 테스트)

---

## 1. 현재 수준 평가 (SOTA 대비)

### 종합 등급: **B+ (상위 오픈소스 수준, SOTA 대비 구조적 갭 존재)**

| 차원 | 점수 | SOTA 기준 | 판단 근거 |
|------|------|-----------|----------|
| **아키텍처** | 80/100 | ADORE 52.65, Gemini 48.88 (RACE) | Multi-agent + 하네스 분리는 ADORE와 유사. 그러나 Evidence-coverage 정지규칙이 코드 수준(plateau만)이고, ADORE의 Memory-locked 합성 미도입 |
| **검색/수집** | 65/100 | Query Fan-Out 8-12개, FAIR-RAG F1+8.3pt | Worker 3-8개 병렬은 있으나, 반성적 재검색(FAIR-RAG), HyDE, Summarize-Before-Evaluate 부재 |
| **평가/검증** | 75/100 | Autorubric 80% acc, MiniCheck 400x 비용절감 | 8차원 평가 + 코드 블렌딩은 강점. 그러나 Position debiasing, Atomic factoid 분해, 3-run 앙상블 미적용 |
| **합성/보고서** | 70/100 | CSS claim-level 신뢰도, FACTUM 인용검증 | Claim-Evidence 매핑은 있으나, Confidence calibration(CSS), Citation validation(FACTUM), Contradiction detection 미적용 |
| **Knowledge/메모리** | 75/100 | A-Mem F1 3.45, 토큰 85-93% 절감 | dr-knowledge + evolve 구현됨. 그러나 Sleep-consolidation, Session→Semantic 승격, 자동 허브 발견 부재 |
| **토큰 효율** | 80/100 | ACON 26-54% 절감, 압축 3:1-5:1 | dr-classify/dr-preprocess 병렬화(70% 속도향상)는 강점. Summarize-Before-Evaluate, 결과 압축 파이프라인 부재 |
| **플러그인 아키텍처** | 70/100 | context:fork, asyncRewake, monitors | SessionStart/PreCompact/SubagentStop hook 사용. 그러나 `context:fork`, PostToolUse 캐시, UserPromptSubmit KB 주입 미활용 |
| **테스트/신뢰성** | 85/100 | DRB II 9,430 binary rubrics | 88개 검증 테스트는 양호. 그러나 End-to-end 리서치 품질 벤치마크(RACE 스타일) 부재 |

### 강점 (유지해야 할 것)

1. **하네스 아키텍처**: AI vs 코드 분리 원칙이 SOTA와 일치 (Claude Code 98.4% 결정론적 코드 — arXiv 2604.14228)
2. **12개 CLI 도구**: dr-score/dr-verify/dr-dedup/dr-preprocess 등 코드 기반 검증이 AI 부담 80% 감소
3. **적응적 종료**: Plateau 감지 + 전략 전환은 ADORE의 Evidence-coverage 정지와 유사한 접근
4. **일관성 시스템**: dr-normalize + dr-cache + dr-consistency + dr-knowledge 체인은 크로스세션 일관성 보장
5. **Rubric 프로필**: default/poc/exploration 3종 + 캘리브레이션 앵커는 Autorubric 컨셉과 일치

### 핵심 갭 (SOTA 대비 부족)

| # | 갭 | SOTA 참조 | 영향도 |
|---|---|----------|--------|
| G1 | Worker 결과 압축 없이 Evaluator에 전달 → 토큰 낭비 | ACON: 26-54% 절감, 압축 3:1-5:1 | **Critical** |
| G2 | Evaluator 단일 실행 (standard depth) → 일관성 부족 | 3-run 앙상블: 최고 ROI 일관성 개선 | **High** |
| G3 | Claim-level 인용 검증 부재 → 할루시네이션 전파 | FACTUM: 30%+ 인용이 할루시네이션 | **High** |
| G4 | Worker 반성적 재검색 부재 → 커버리지 갭 | FAIR-RAG: F1 +8.3pt | **High** |
| G5 | Claude Code `context:fork` 미활용 → 메인 컨텍스트 오염 | 공식 추천: 리서치는 fork 격리 | **Medium** |
| G6 | Position/순서 debiasing 미적용 | Autorubric: 포지션 편향이 점수 ±15 영향 | **Medium** |
| G7 | HyDE 미활용 → 키워드 검색 한계 | HyDE: precision +42pp | **Medium** |
| G8 | Knowledge sleep-consolidation 부재 | A-Mem: 주기적 병합+허브 승격 | **Low** |

---

## 2. 개선 제안 (우선순위순)

### P0: Critical (즉시 적용, 비용 대비 효과 최대)

#### P0-1: Summarize-Before-Evaluate (Worker 결과 압축)
- **현재**: Worker 결과 원본 전체 → Evaluator (수천~수만 토큰)
- **개선**: Phase 3.5에 `dr-compress` 추가 — Worker 결과를 소스당 150단어로 압축 후 전달
- **효과**: Evaluator 입력 토큰 60-80% 절감, Opus 비용 직접 절감
- **구현**: bin/dr-compress (LLM 1회 호출로 배치 압축) 또는 SKILL.md Phase 3.5.8 추가
- **근거**: ACON (arXiv), Zylos AI Context Compression (2026)
- **복잡도**: Low | **예상 토큰 절감**: 40-60%

#### P0-2: Citation Validation Pipeline (인용 할루시네이션 방지)
- **현재**: Synthesizer가 보고서 생성 시 인용 정확성 미검증
- **개선**: Phase 5 후에 `dr-cite-check` — 각 (claim, source) 쌍의 키워드 오버랩 + URL 존재 확인
- **효과**: 할루시네이션 인용 탐지 → 보고서 신뢰도 대폭 향상
- **근거**: FACTUM (arXiv 2601.05866) — 30%+ 인용이 할루시네이션, SourceCheckup — 50-90% 미지원
- **복잡도**: Low-Medium | **예상 품질 향상**: Accuracy +10-15pt

### P1: High (다음 버전에 포함)

#### P1-1: Evaluator 3-Run 앙상블 (standard depth 포함)
- **현재**: depth=deep에서만 2회 실행, standard는 1회
- **개선**: 모든 depth에서 최소 2회 실행, 점수 평균 + 차이>15 시 플래그
- **효과**: 평가 일관성 대폭 향상 (단일 최고 ROI)
- **근거**: SSRN 연구 — 3-run 앙상블이 ceiling 근접, 비용 대비 최고 효과
- **복잡도**: Low (SKILL.md Phase 4 수정) | **추가 비용**: Opus 2x (그러나 P0-1 압축으로 상쇄)

#### P1-2: 반성적 재검색 (FAIR-RAG 패턴)
- **현재**: Phase 3B Gap 분석은 SEA 충족률 기반 (수동적)
- **개선**: Phase 3B에서 LLM이 현재 evidence를 평가 → "무엇이 부족한가" 판단 → 타겟 재검색
- **효과**: 커버리지 +8pt (HotpotQA 기준), 검색 정밀도 향상
- **근거**: FAIR-RAG (arXiv 2510.22344) — F1 +8.3pt
- **복잡도**: Low (SKILL.md Phase 3B 프롬프트 수정)

#### P1-3: Position Debiasing (평가 편향 제거)
- **현재**: Evaluator에 findings를 고정 순서로 전달
- **개선**: Worker 결과 순서를 랜덤 셔플 후 Evaluator 전달 (2회 실행 시 순서 반전)
- **효과**: 포지션 편향 제거 (점수 ±15 변동 방지)
- **근거**: Autorubric (arXiv 2603.00077), Scoring Bias (arXiv 2506.22316)
- **복잡도**: Low (dr-preprocess에 셔플 옵션 추가)

### P2: Medium (품질 고도화)

#### P2-1: HyDE 검색 강화
- **현재**: Worker가 키워드 기반 WebSearch만 실행
- **개선**: Planner가 "가상 이상적 답변" 1문단 생성 → 첫 번째 검색 쿼리로 활용
- **효과**: 검색 precision +42pp, recall +45pp (특정 데이터셋)
- **근거**: HyDE (arXiv 2212.10496), HyPE 2025 변형
- **복잡도**: Low (Planner 프롬프트에 HyDE 섹션 추가)

#### P2-2: Contradiction Detection Pipeline
- **현재**: Worker의 [Core 충돌] 태그는 수동 탐지에 의존
- **개선**: `dr-contradict` — claims.jsonl 내 주장 쌍의 TF-IDF 유사도 + 극성 비교
- **효과**: 소스 간 모순을 자동 탐지, 보고서에 "소스가 X에 대해 불일치" 명시
- **근거**: Dual-Perspective Verification (arXiv 2602.18693)
- **복잡도**: Medium (Python 스크립트, NLTK 부정 탐지 + TF-IDF)

#### P2-3: `context:fork` 적용 + PostToolUse 캐시 훅
- **현재**: SKILL.md는 메인 컨텍스트에서 실행, WebFetch 결과 미캐시
- **개선**: SKILL.md에 `context: fork` 추가, PostToolUse hook으로 WebFetch/WebSearch 결과 로컬 캐시
- **효과**: 메인 대화 컨텍스트 보호, 반복 fetch 제거
- **근거**: Claude Code 공식 문서 — 리서치는 fork 격리 권장
- **복잡도**: Low-Medium

### P3: Low Priority (장기 로드맵)

#### P3-1: Knowledge Sleep-Consolidation
- **현재**: dr-knowledge evolve는 크로스링크만 생성
- **개선**: N건 이상 note 축적 시 백그라운드 병합+허브 승격 루프
- **근거**: A-Mem Zettelkasten self-organizing (MarkTechPost, Dec 2025)

#### P3-2: DEER 7차원 평가 체계 도입
- **현재**: 8차원 (코어4 + 맥락4)
- **개선**: DEER 벤치마크의 7차원 25하위차원 130항목 체계 참조하여 세분화
- **근거**: DEER (arXiv 2512.17776) — 가장 세밀한 리서치 평가 분류

#### P3-3: Agentic Plan Caching
- **현재**: dr-cache는 쿼리 결과만 캐시
- **개선**: 검색 전략(workers 배치, 쿼리 세트) 자체를 캐시 → 유사 주제 시 전략 재활용
- **근거**: Agentic Plan Caching (arXiv 2506.14852)

---

## 3. SOTA 시스템 대비 포지셔닝

```
                    품질 (RACE 점수 추정)
                    ^
              60 ── │ ·Xiaoyi(57) ·Cellcog(56)
                    │        ·ADORE(52.65)
              50 ── │   ·Gemini DR(48.88)
                    │   ·OpenAI DR(46.98)
                    │
              40 ── │         ·GPT-Researcher(43.44)
                    │
              30 ── │   ★ 현재 v2.4 (추정 35-40)
                    │   ☆ P0+P1 적용 후 (추정 45-50)
              20 ── │
                    └──────────────────────────> 비용/복잡도
                   낮음                        높음
```

**현재 v2.4 추정 위치**: GPT-Researcher(#6, 43.44) 바로 아래
- 강점: 하네스 아키텍처, 일관성 시스템, 12개 CLI 도구
- 약점: 압축 미적용으로 토큰 낭비, 인용 검증 부재, 단일 판사

**P0+P1 적용 후 추정**: Gemini DR(48.88) ~ OpenAI DR(46.98) 수준
- 압축으로 토큰 40-60% 절감 → 동일 비용에 더 깊은 탐색 가능
- 인용 검증 + 앙상블로 Accuracy/Consistency 대폭 향상
- 반성적 재검색으로 Coverage 갭 해소

---

## 4. 구현 로드맵

| Phase | 변경 | 파일 | 테스트 | 예상 효과 |
|-------|------|------|--------|----------|
| **v2.5** | P0-1 압축 + P0-2 인용검증 | bin/dr-compress, bin/dr-cite-check, SKILL.md | +6개 | 토큰-40%, Accuracy+10 |
| **v2.6** | P1-1 앙상블 + P1-2 반성적재검색 + P1-3 디바이어싱 | SKILL.md, dr-preprocess | +4개 | Consistency+15, Coverage+8 |
| **v2.7** | P2-1 HyDE + P2-2 모순탐지 + P2-3 context:fork | Planner, bin/dr-contradict, hooks.json | +6개 | Precision+20, 컨텍스트 보호 |
| **v3.0** | P3 전체 (Sleep-consolidation, DEER, Plan cache) | 전체 | +10개 | 장기 품질+안정성 |

---

## 5. 소스 목록 (주요)

### SOTA 시스템
- [DeepResearch Bench (arXiv 2506.11763)](https://arxiv.org/abs/2506.11763) — RACE 평가 프레임워크
- [ADORE (arXiv 2601.18267)](https://arxiv.org/html/2601.18267v1) — Evidence-coverage 정지규칙
- [Gemini Deep Research Max](https://blog.google/innovation-and-ai/models-and-research/gemini-models/next-generation-gemini-deep-research/)
- [DeepHalluBench (arXiv 2601.22984)](https://arxiv.org/abs/2601.22984) — 할루시네이션 전파 문제

### 평가/검증
- [Autorubric (arXiv 2603.00077)](https://arxiv.org/abs/2603.00077) — 멀티 판사 앙상블
- [FACTUM (arXiv 2601.05866)](https://arxiv.org/abs/2601.05866) — 인용 할루시네이션 탐지
- [MiniCheck (arXiv 2404.10774)](https://arxiv.org/abs/2404.10774) — 770M 팩트체킹
- [DEER (arXiv 2512.17776)](https://arxiv.org/html/2512.17776v1) — 7차원 130항목 평가

### 검색/수집
- [FAIR-RAG (arXiv 2510.22344)](https://arxiv.org/abs/2510.22344) — 반성적 재검색 F1+8.3
- [HyDE (arXiv 2212.10496)](https://arxiv.org/abs/2212.10496) — 가상 문서 임베딩
- [ACON Context Compression](https://zylos.ai/research/2026-02-28-ai-agent-context-compression-strategies) — 26-54% 토큰 절감

### 합성/Knowledge
- [CSS Claim Calibration (arXiv 2604.17487)](https://arxiv.org/html/2604.17487) — 증거 부족 시 약화
- [A-Mem (arXiv 2502.12110)](https://arxiv.org/abs/2502.12110) — Zettelkasten 자동 링크
- [Dual-Perspective Contradiction (arXiv 2602.18693)](https://arxiv.org/abs/2602.18693)

### Claude Code
- [Claude Code Hooks 공식 문서](https://code.claude.com/docs/en/hooks) — 29개 이벤트
- [Claude Code Skills 공식 문서](https://code.claude.com/docs/en/skills) — context:fork
- [Claude Code Context Window](https://code.claude.com/docs/en/context-window) — 압축/토큰 관리
