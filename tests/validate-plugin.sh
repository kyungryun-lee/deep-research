#!/usr/bin/env bash
# Deep Research Plugin Validation Test
# Verifies plugin structure, configuration, and consistency
# Exit 0 = all pass, Exit 1 = failure

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
WARN=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠️  $1"; WARN=$((WARN+1)); }

echo "=== Deep Research Plugin Validation ==="
echo "Plugin dir: $PLUGIN_DIR"
echo ""

# --- 1. Structure Tests ---
echo "[1] Structure"
[ -f "$PLUGIN_DIR/.claude-plugin/plugin.json" ] && pass "plugin.json exists" || fail "plugin.json missing"
[ -f "$PLUGIN_DIR/skills/research/SKILL.md" ] && pass "SKILL.md exists" || fail "SKILL.md missing"
[ -f "$PLUGIN_DIR/skills/setup/SKILL.md" ] && pass "setup SKILL.md exists" || fail "setup SKILL.md missing"
for agent in research-planner research-worker research-evaluator research-synthesizer; do
    [ -f "$PLUGIN_DIR/agents/$agent.md" ] && pass "agents/$agent.md exists" || fail "agents/$agent.md missing"
done
for rubric in default poc exploration compliance comparative; do
    [ -f "$PLUGIN_DIR/skills/research/rubrics/$rubric.md" ] && pass "rubrics/$rubric.md exists" || fail "rubrics/$rubric.md missing"
done
[ -f "$PLUGIN_DIR/hooks/hooks.json" ] && pass "hooks.json exists" || fail "hooks.json missing"
[ -f "$PLUGIN_DIR/bin/lib/dr_text.py" ] && pass "bin/lib/dr_text.py exists (shared text utils)" || fail "bin/lib/dr_text.py missing"

# All bin/dr-* scripts must be executable (single source of truth for binary checks)
ALL_BINS="dr-memory dr-cache dr-verify dr-score dr-dedup dr-knowledge dr-normalize dr-consistency dr-tokens dr-preprocess dr-classify dr-compress dr-cite-check dr-contradict dr-dry-run dr-bench"
for b in $ALL_BINS; do
    [ -x "$PLUGIN_DIR/bin/$b" ] && pass "$b is executable" || fail "$b not executable"
done

# --- 2. Configuration Tests ---
echo ""
echo "[2] Configuration"
python3 -c "import json; json.load(open('$PLUGIN_DIR/.claude-plugin/plugin.json'))" 2>/dev/null && pass "plugin.json is valid JSON" || fail "plugin.json invalid JSON"
python3 -c "import json; json.load(open('$PLUGIN_DIR/marketplace.json'))" 2>/dev/null && pass "marketplace.json is valid JSON" || fail "marketplace.json invalid JSON"
python3 -c "import json; json.load(open('$PLUGIN_DIR/hooks/hooks.json'))" 2>/dev/null && pass "hooks.json is valid JSON" || fail "hooks.json invalid JSON"

# --- 3. No Sensitive Data ---
echo ""
echo "[3] Security"
if grep -rq "ghp_\|Bearer \|api_key=" "$PLUGIN_DIR" --include="*.md" --include="*.json" --exclude-dir="tests" --exclude-dir=".git" --exclude-dir=".changes" 2>/dev/null; then
    fail "Sensitive data found in tracked files"
else
    pass "No sensitive data in tracked files"
fi
if grep -rq "/home/worker\|/tmp/" "$PLUGIN_DIR" --include="*.md" --include="*.json" 2>/dev/null | grep -v "CLAUDE_PLUGIN"; then
    fail "Absolute paths found"
else
    pass "No hardcoded absolute paths"
fi

# --- 4. Model Routing ---
echo ""
echo "[4] Model Routing"
PLANNER_MODEL=$(grep "^model:" "$PLUGIN_DIR/agents/research-planner.md" | awk '{print $2}')
WORKER_MODEL=$(grep "^model:" "$PLUGIN_DIR/agents/research-worker.md" | awk '{print $2}')
EVALUATOR_MODEL=$(grep "^model:" "$PLUGIN_DIR/agents/research-evaluator.md" | awk '{print $2}')
SYNTHESIZER_MODEL=$(grep "^model:" "$PLUGIN_DIR/agents/research-synthesizer.md" | awk '{print $2}')
[ "$PLANNER_MODEL" = "sonnet" ] && pass "Planner: sonnet (cost-optimized)" || warn "Planner: $PLANNER_MODEL (expected sonnet)"
[ "$WORKER_MODEL" = "sonnet" ] && pass "Worker: sonnet" || warn "Worker: $WORKER_MODEL"
[ "$EVALUATOR_MODEL" = "opus" ] && pass "Evaluator: opus (quality-critical)" || warn "Evaluator: $EVALUATOR_MODEL (expected opus)"
[ "$SYNTHESIZER_MODEL" = "opus" ] && pass "Synthesizer: opus (quality-critical)" || warn "Synthesizer: $SYNTHESIZER_MODEL (expected opus)"

# --- 5. Rubric JSON Blocks ---
echo ""
echo "[5] Rubric Weights"
for rubric in default poc exploration; do
    if grep -q '"core"' "$PLUGIN_DIR/skills/research/rubrics/$rubric.md"; then
        pass "$rubric.md has JSON weight block"
    else
        fail "$rubric.md missing JSON weight block"
    fi
done

# --- 6. Independence Rules ---
echo ""
echo "[6] Independence Rules"
if grep -q "원본 전달" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has raw delivery rule"
else
    fail "SKILL.md missing raw delivery rule"
fi
if grep -q "앵커링 차단" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has anchoring prevention rule"
else
    fail "SKILL.md missing anchoring prevention rule"
fi
if grep -q "확증편향 차단" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has confirmation bias prevention rule"
else
    fail "SKILL.md missing confirmation bias prevention rule"
fi

# --- 7. Change Tracking ---
echo ""
echo "[7] Change Tracking"
[ -d "$PLUGIN_DIR/.changes" ] && pass ".changes directory exists" || fail ".changes directory missing"
[ -f "$PLUGIN_DIR/.changes/README.md" ] && pass "Change tracking documented" || warn "Change tracking README missing"

# --- 8. Harness Scripts (AI/Code Separation) ---
echo ""
echo "[8] Harness Scripts"
# dr-score functional test
SCORE_OUT=$(echo '{"scores":{"accuracy":90,"coverage":80,"recency":80,"structure":85,"proven":80,"actionability":80,"efficiency":75,"env_fit":70},"target_score":80}' | "$PLUGIN_DIR/bin/dr-score" calc --rubric "$PLUGIN_DIR/skills/research/rubrics/default.md" 2>/dev/null)
echo "$SCORE_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'total' in d and 'verdict' in d" 2>/dev/null && pass "dr-score calc returns valid output" || fail "dr-score calc invalid"

# dr-score plateau test
PLATEAU_OUT=$(echo '{"history":[70,72,72],"threshold":3,"consecutive":2}' | "$PLUGIN_DIR/bin/dr-score" plateau 2>/dev/null)
echo "$PLATEAU_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('plateau') == True" 2>/dev/null && pass "dr-score plateau detection works" || fail "dr-score plateau detection failed"

# dr-dedup functional test
DEDUP_OUT=$(echo '["https://example.com/a","https://www.example.com/a"]' | "$PLUGIN_DIR/bin/dr-dedup" urls 2>/dev/null)
echo "$DEDUP_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['stats']['removed'] >= 1" 2>/dev/null && pass "dr-dedup removes duplicates" || fail "dr-dedup dedup failed"

# dr-verify classify test
VERIFY_OUT=$(echo '["https://docs.python.org/3/","https://arxiv.org/abs/2401.00001","https://unknown-site.xyz"]' | "$PLUGIN_DIR/bin/dr-verify" classify 2>/dev/null)
echo "$VERIFY_OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
tiers = {r['url']:r['tier'] for r in d['classifications']}
assert tiers.get('https://docs.python.org/3/') == 'S'
assert tiers.get('https://arxiv.org/abs/2401.00001') == 'A'
assert 'https://unknown-site.xyz' in d.get('ai_review_needed',[])
" 2>/dev/null && pass "dr-verify classifies tiers correctly" || fail "dr-verify classification failed"

# SKILL.md has adaptive termination
if grep -q "조기종료 조건" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has adaptive termination"
else
    fail "SKILL.md missing adaptive termination"
fi

# SKILL.md has Phase 3.5 (external verification)
if grep -q "Phase 3.5" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has Phase 3.5 (external verification)"
else
    fail "SKILL.md missing Phase 3.5"
fi

# --- 9. Knowledge & Consistency (Phase B) ---
echo ""
echo "[9] Knowledge & Consistency"

# dr-knowledge save/load functional test
TEST_TOPIC="__test_validate_$(date +%s)"
SAVE_OUT=$(echo '{"core_facts":[{"id":"CF-T1","claim":"test fact","evidence":[{"url":"https://test.com","tier":"S"}]}],"peripheral":[{"id":"PF-T1","claim":"test peripheral"}],"anchors":[{"url":"https://test.com","tier":"S","role":"primary"}],"claims":[{"id":"CL-T1","text":"test claim","evidence":[{"url":"https://test.com"}],"confidence":"high"}]}' | "$PLUGIN_DIR/bin/dr-knowledge" save --topic "$TEST_TOPIC" 2>/dev/null)
echo "$SAVE_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('status')=='saved'" 2>/dev/null && pass "dr-knowledge save works" || fail "dr-knowledge save failed"

LOAD_OUT=$("$PLUGIN_DIR/bin/dr-knowledge" load --topic "$TEST_TOPIC" 2>/dev/null)
echo "$LOAD_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('found')==True and d['summary']['core_facts_count']>=1" 2>/dev/null && pass "dr-knowledge load works" || fail "dr-knowledge load failed"

# Cleanup test data
TEST_HASH=$(echo "$SAVE_OUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('hash',''))" 2>/dev/null)
[ -n "$TEST_HASH" ] && rm -rf "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/deep-research}/knowledge/$TEST_HASH" 2>/dev/null

# SKILL.md has knowledge load
if grep -q "Knowledge 로드" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has Knowledge load phase"
else
    fail "SKILL.md missing Knowledge load"
fi

# SKILL.md has Chain-of-Retrieval (Phase 3B/3C)
if grep -q "Phase 3B" "$PLUGIN_DIR/skills/research/SKILL.md" && grep -q "Phase 3C" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has Chain-of-Retrieval (Phase 3B/3C)"
else
    fail "SKILL.md missing Chain-of-Retrieval phases"
fi

# Synthesizer has claim-evidence output
if grep -q "Claim-Evidence" "$PLUGIN_DIR/agents/research-synthesizer.md"; then
    pass "Synthesizer has claim-evidence output"
else
    fail "Synthesizer missing claim-evidence"
fi

# Evaluator has claim-evidence verification
if grep -q "Evidence Coverage" "$PLUGIN_DIR/agents/research-evaluator.md"; then
    pass "Evaluator has claim-evidence verification"
else
    fail "Evaluator missing claim-evidence verification"
fi

# Planner has anchor strategy
if grep -q "anchor_strategy" "$PLUGIN_DIR/agents/research-planner.md"; then
    pass "Planner has anchor strategy"
else
    fail "Planner missing anchor strategy"
fi

# Worker has anchor source handling
if grep -q "anchor_sources" "$PLUGIN_DIR/agents/research-worker.md"; then
    pass "Worker has anchor source handling"
else
    fail "Worker missing anchor source handling"
fi

# --- 10. Query Normalization & Cache ---
echo ""
echo "[10] Query Normalization & Cache"

# dr-normalize basic test
NORM_OUT=$("$PLUGIN_DIR/bin/dr-normalize" normalize "Best LLM Frameworks vs Libraries 2026" 2>/dev/null)
echo "$NORM_OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert 'cache_key' in d and len(d['cache_key'])==12
assert 'normalized' in d
assert d['tokens'] == sorted(d['tokens']), 'tokens should be sorted'
" 2>/dev/null && pass "dr-normalize produces sorted tokens + cache key" || fail "dr-normalize output invalid"

# dr-normalize synonym mapping
NORM_SYN=$("$PLUGIN_DIR/bin/dr-normalize" normalize "comparing React vs Vue tutorials" 2>/dev/null)
echo "$NORM_SYN" | python3 -c "
import json,sys
d=json.load(sys.stdin)
# 'comparing' → 'compare', 'vs' → 'versus', 'tutorials' → 'guide'
assert 'compare' in d['tokens'], f'expected compare: {d[\"tokens\"]}'
assert 'versus' in d['tokens'], f'expected versus: {d[\"tokens\"]}'
assert 'guide' in d['tokens'], f'expected guide: {d[\"tokens\"]}'
assert 'comparing' not in d['tokens']
assert 'vs' not in d['tokens']
" 2>/dev/null && pass "dr-normalize synonym mapping works" || fail "dr-normalize synonyms failed"

# dr-normalize similar test
SIM_OUT=$("$PLUGIN_DIR/bin/dr-normalize" similar "React vs Vue comparison" "Vue vs React compare" 2>/dev/null)
echo "$SIM_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['similar']==True and d['cosine']>0.5" 2>/dev/null && pass "dr-normalize similar detection works" || fail "dr-normalize similar failed"

# dr-normalize cache key stability (same query → same key)
KEY1=$("$PLUGIN_DIR/bin/dr-normalize" cache-key "Best LLM frameworks" 2>/dev/null)
KEY2=$("$PLUGIN_DIR/bin/dr-normalize" cache-key "best llm frameworks" 2>/dev/null)
[ "$KEY1" = "$KEY2" ] && pass "dr-normalize cache key is case-insensitive" || fail "dr-normalize cache key not stable ($KEY1 vs $KEY2)"

# dr-cache save-query / load-query test
TEST_QUERY="__test_cache_$(date +%s)"
echo "Test findings with https://example.com/test and https://docs.python.org" | "$PLUGIN_DIR/bin/dr-cache" save-query "$TEST_QUERY" > /dev/null 2>&1
CACHE_LOAD=$("$PLUGIN_DIR/bin/dr-cache" load-query "$TEST_QUERY" 2>/dev/null)
echo "$CACHE_LOAD" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d.get('hit')==True, f'expected hit: {d}'
assert len(d.get('urls',[])) >= 2, f'expected 2+ urls: {d.get(\"urls\")}'
" 2>/dev/null && pass "dr-cache save-query/load-query works" || fail "dr-cache query cache failed"

# Cleanup test cache
TEST_CACHE_KEY=$("$PLUGIN_DIR/bin/dr-normalize" cache-key "$TEST_QUERY" 2>/dev/null)
rm -f "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/deep-research}/cache/query-results/${TEST_CACHE_KEY}.json" 2>/dev/null
rm -f "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/deep-research}/cache/query-results/${TEST_CACHE_KEY}.findings.txt" 2>/dev/null

# SKILL.md has query normalization
if grep -q "쿼리 정규화" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has query normalization phase"
else
    fail "SKILL.md missing query normalization"
fi

# --- 11. Extended Harness Scripts ---
echo ""
echo "[11] Extended Harness Scripts"

# dr-score diversity test
DIV_OUT=$(echo '["https://a.com","https://b.com","https://a.com/page"]' | "$PLUGIN_DIR/bin/dr-score" diversity 2>/dev/null)
echo "$DIV_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'entropy' in d and d['total']==3" 2>/dev/null && pass "dr-score diversity works" || fail "dr-score diversity failed"

# dr-score recency test
REC_OUT=$(echo '[{"url":"a","year":2026},{"url":"b","year":2024}]' | "$PLUGIN_DIR/bin/dr-score" recency 2>/dev/null)
echo "$REC_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'recency_score' in d and d['total']==2" 2>/dev/null && pass "dr-score recency works" || fail "dr-score recency failed"

# dr-score xref test
XREF_OUT=$(echo '[{"claim":"A","evidence":[{"url":"x"},{"url":"y"}]},{"claim":"B","evidence":[]}]' | "$PLUGIN_DIR/bin/dr-score" xref 2>/dev/null)
echo "$XREF_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['multi_cited']==1 and d['no_evidence']==1" 2>/dev/null && pass "dr-score xref works" || fail "dr-score xref failed"

# dr-score structure test
STRUCT_OUT=$(printf '# Title\n## A\nContent.\n## B\nMore.\n' | "$PLUGIN_DIR/bin/dr-score" structure 2>/dev/null)
echo "$STRUCT_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'structure_score' in d and d['headings']['h2']==2" 2>/dev/null && pass "dr-score structure works" || fail "dr-score structure failed"

# dr-score calc blending test
BLEND_OUT=$(echo '{"scores":{"accuracy":80,"coverage":80,"recency":70,"structure_coherence":80,"proven":80,"actionability":80,"efficiency":80,"env_fit":80,"citation_quality":80,"depth":80},"target_score":80}' | "$PLUGIN_DIR/bin/dr-score" calc --rubric "$PLUGIN_DIR/skills/research/rubrics/default.md" --code-metrics '{"recency_score":90,"structure_score":60,"sea_rate":85}' 2>/dev/null)
echo "$BLEND_OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
# recency should be blended: 0.7*90 + 0.3*70 = 84
assert abs(d['breakdown']['recency']['score'] - 84) < 1, f'recency={d[\"breakdown\"][\"recency\"][\"score\"]}'
# structure_coherence should be 100% code: 60
assert abs(d['breakdown']['structure_coherence']['score'] - 60) < 1, f'structure={d[\"breakdown\"][\"structure_coherence\"][\"score\"]}'
# coverage should be 100% code: 85 (sea_rate)
assert abs(d['breakdown']['coverage']['score'] - 85) < 1, f'coverage={d[\"breakdown\"][\"coverage\"][\"score\"]}'
" 2>/dev/null && pass "dr-score calc blending+code-only works" || fail "dr-score calc blending failed"

# Rubric calibration anchors
for rubric in default poc exploration; do
    if grep -q "캘리브레이션 앵커" "$PLUGIN_DIR/skills/research/rubrics/$rubric.md"; then
        pass "$rubric.md has calibration anchors"
    else
        fail "$rubric.md missing calibration anchors"
    fi
done

# SKILL.md has code_metrics
if grep -q "code_metrics" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has code_metrics integration"
else
    fail "SKILL.md missing code_metrics"
fi

# --- 12. Phase C: Advanced Optimization ---
echo ""
echo "[12] Phase C: Advanced Optimization"

# dr-tokens record + report test
TEST_SESSION="__test_$(date +%s)"
"$PLUGIN_DIR/bin/dr-tokens" record --phase "planner" --input 5000 --output 2000 --model sonnet --session "$TEST_SESSION" > /dev/null 2>&1
"$PLUGIN_DIR/bin/dr-tokens" record --phase "evaluator" --input 20000 --output 5000 --model opus --session "$TEST_SESSION" > /dev/null 2>&1
TOKEN_REPORT=$("$PLUGIN_DIR/bin/dr-tokens" report --session "$TEST_SESSION" 2>/dev/null)
echo "$TOKEN_REPORT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['session']=='$TEST_SESSION'
assert d['total']['input_tokens']==25000
assert d['total']['output_tokens']==7000
assert d['total']['total_tokens'] == 32000
assert 'planner' in d['by_phase'] and 'evaluator' in d['by_phase']
" 2>/dev/null && pass "dr-tokens record+report works" || fail "dr-tokens record+report failed"

# dr-tokens estimate test
EST_OUT=$("$PLUGIN_DIR/bin/dr-tokens" estimate --query "test" --depth standard 2>/dev/null)
echo "$EST_OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['depth']=='standard'
assert d['estimated_total_tokens'] > 0
" 2>/dev/null && pass "dr-tokens estimate works" || fail "dr-tokens estimate failed"

# Cleanup test token data
sed -i "/$TEST_SESSION/d" "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/deep-research}/tokens/usage.jsonl" 2>/dev/null || true

# dr-cache semantic-match test
# First save a cache entry
echo "Findings about LLM plugins https://example.com/llm https://docs.anthropic.com" | "$PLUGIN_DIR/bin/dr-cache" save-query "LLM plugin architecture" > /dev/null 2>&1
SEM_OUT=$("$PLUGIN_DIR/bin/dr-cache" semantic-match "plugin architecture for language models" 0.3 2>/dev/null)
echo "$SEM_OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d.get('hit')==True, f'expected semantic hit: {d}'
assert d['type']=='semantic'
assert d['best_match']['similarity'] >= 0.3
" 2>/dev/null && pass "dr-cache semantic-match works" || fail "dr-cache semantic-match failed"

# Cleanup
SEM_KEY=$("$PLUGIN_DIR/bin/dr-normalize" cache-key "LLM plugin architecture" 2>/dev/null)
rm -f "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/deep-research}/cache/query-results/${SEM_KEY}.json" 2>/dev/null
rm -f "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/deep-research}/cache/query-results/${SEM_KEY}.findings.txt" 2>/dev/null

# SKILL.md has Phase C features
if grep -q "시맨틱 캐시" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has semantic cache"
else
    fail "SKILL.md missing semantic cache"
fi
if grep -q "토큰 대시보드" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has token dashboard"
else
    fail "SKILL.md missing token dashboard"
fi
# Batch API removed (not available in current environment)

# --- 13. Meta-Research Improvements (P0-P2) ---
echo ""
echo "[13] Meta-Research Improvements"

# dr-classify profile detection
CLASSIFY_OUT=$("$PLUGIN_DIR/bin/dr-classify" profile "최신 연구 트렌드 조사" 2>/dev/null)
echo "$CLASSIFY_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['profile']=='exploration', f'expected exploration: {d}'" 2>/dev/null && pass "dr-classify exploration profile works" || fail "dr-classify exploration failed"

CLASSIFY_POC=$("$PLUGIN_DIR/bin/dr-classify" profile "이 방법이 가능한가 PoC 검증" 2>/dev/null)
echo "$CLASSIFY_POC" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['profile']=='poc', f'expected poc: {d}'" 2>/dev/null && pass "dr-classify poc profile works" || fail "dr-classify poc failed"

CLASSIFY_DEF=$("$PLUGIN_DIR/bin/dr-classify" profile "React 구현 방법 비교" 2>/dev/null)
echo "$CLASSIFY_DEF" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['profile']=='default', f'expected default: {d}'" 2>/dev/null && pass "dr-classify default profile works" || fail "dr-classify default failed"

# dr-classify all test
CLASSIFY_ALL=$("$PLUGIN_DIR/bin/dr-classify" all "심층 비교 분석" "deep" 2>/dev/null)
echo "$CLASSIFY_ALL" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert 'profile' in d and 'complexity' in d and 'workers' in d and 'recency' in d
" 2>/dev/null && pass "dr-classify all returns complete classification" || fail "dr-classify all failed"

# P1: SOURCE_TIERS.md exists
[ -f "$PLUGIN_DIR/skills/research/SOURCE_TIERS.md" ] && pass "SOURCE_TIERS.md exists (unified tier definition)" || fail "SOURCE_TIERS.md missing"

# P2: dr-score kpr-kpc test
KPR_OUT=$(echo '{"key_points":["React performance","Vue reactivity","Angular modules"],"report_claims":["React performance optimization","Vue reactive system","Svelte compilation"]}' | "$PLUGIN_DIR/bin/dr-score" kpr-kpc 2>/dev/null)
echo "$KPR_OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert 'kpr' in d and 'kpc' in d and 'cci' in d
assert d['kpr'] > 0, f'expected some coverage: {d}'
assert d['key_points_total']==3
" 2>/dev/null && pass "dr-score kpr-kpc works" || fail "dr-score kpr-kpc failed"

# P2: dr-dedup text (previously broken)
DEDUP_TEXT_OUT=$(echo "Some text with https://example.com/a and https://www.example.com/a duplicate URLs" | "$PLUGIN_DIR/bin/dr-dedup" text 2>/dev/null)
echo "$DEDUP_TEXT_OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d.get('total_urls',0) >= 2, f'expected urls: {d}'
assert d.get('has_duplicates')==True, f'expected duplicates: {d}'
" 2>/dev/null && pass "dr-dedup text works (bug fixed)" || fail "dr-dedup text still broken"

# P2: dr-score sea test
SEA_OUT=$(echo '{"checked":["item1","item2"],"total":["item1","item2","item3"],"threshold":75}' | "$PLUGIN_DIR/bin/dr-score" sea 2>/dev/null)
echo "$SEA_OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert abs(d['rate'] - 66.7) < 1
assert d['sufficient']==False
assert len(d['unchecked'])==1
" 2>/dev/null && pass "dr-score sea works" || fail "dr-score sea failed"

# P2: SKILL.md has SOTA features
if grep -q "Unified Intent-Planning" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has Unified Intent-Planning (SOTA)"
else
    fail "SKILL.md missing Unified Intent-Planning"
fi
if grep -q "다중 판사 앙상블" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has multi-judge ensemble (SOTA)"
else
    fail "SKILL.md missing multi-judge ensemble"
fi
if grep -q "kpr-kpc" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has KPR/KPC metrics (SOTA)"
else
    fail "SKILL.md missing KPR/KPC"
fi
if grep -q "evolve" "$PLUGIN_DIR/agents/research-synthesizer.md"; then
    pass "Synthesizer has A-Mem knowledge evolution"
else
    fail "Synthesizer missing A-Mem evolution"
fi

# --- 14. v2.5 Meta-Evaluation Improvements ---
echo ""
echo "[14] v2.5 Improvements (P0-P2)"

# P0-1: dr-compress functional test
COMPRESS_OUT=$(printf '#### 발견 1: React Performance\n- **소스**: https://react.dev\n- **내용**: React 18 introduces concurrent features that improve rendering performance significantly with automatic batching.\n\n#### 발견 2: Vue Reactivity\n- **소스**: https://vuejs.org\n- **내용**: Vue 3 reactivity system uses Proxy-based tracking for better performance.\n' | "$PLUGIN_DIR/bin/dr-compress" summarize --max-words 50 2>/dev/null)
[ -n "$COMPRESS_OUT" ] && pass "dr-compress summarize produces output" || fail "dr-compress summarize failed"

# P0-2: dr-cite-check functional test
CITE_OUT=$(echo '{"claims":[{"id":"CL-001","text":"React uses virtual DOM for performance","evidence":[{"url":"https://react.dev","excerpt":"virtual DOM diffing algorithm"}]},{"id":"CL-002","text":"unsupported claim","evidence":[]}],"sources":[{"url":"https://react.dev","content":"React uses a virtual DOM diffing algorithm to efficiently update the real DOM"}]}' | "$PLUGIN_DIR/bin/dr-cite-check" validate 2>/dev/null)
echo "$CITE_OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['summary']['valid'] >= 1, f'expected valid: {d}'
assert d['summary']['unsupported'] >= 1, f'expected unsupported: {d}'
assert d['summary']['total'] == 2
" 2>/dev/null && pass "dr-cite-check validate works" || fail "dr-cite-check validate failed"

# P2-2: dr-contradict functional test
CONTRA_OUT=$(echo '[{"id":"CL-A","text":"React is faster than Vue in benchmarks","source":"url1"},{"id":"CL-B","text":"Vue outperforms React and is not slower","source":"url2"}]' | "$PLUGIN_DIR/bin/dr-contradict" detect 2>/dev/null)
echo "$CONTRA_OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['total_claims'] == 2
assert 'conflicts' in d
" 2>/dev/null && pass "dr-contradict detect works" || fail "dr-contradict detect failed"

# SKILL.md has new phases
if grep -q "Phase 3A.2" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has Phase 3A.2 (Worker compression)"
else
    fail "SKILL.md missing Phase 3A.2"
fi
if grep -q "반성적 재검색" "$PLUGIN_DIR/skills/research/SKILL.md" || grep -q "FAIR-RAG" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has reflective re-search (FAIR-RAG)"
else
    fail "SKILL.md missing reflective re-search"
fi
if grep -q "Phase 4.5" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has Phase 4.5 (post-evaluate verification)"
else
    fail "SKILL.md missing Phase 4.5"
fi
if grep -q "인용 검증" "$PLUGIN_DIR/skills/research/SKILL.md" || grep -q "dr-cite-check" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has citation validation"
else
    fail "SKILL.md missing citation validation"
fi
if grep -q "모순 탐지" "$PLUGIN_DIR/skills/research/SKILL.md" || grep -q "dr-contradict" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has contradiction detection"
else
    fail "SKILL.md missing contradiction detection"
fi
if grep -q "모든 depth에서" "$PLUGIN_DIR/skills/research/SKILL.md" && grep -q "병렬 독립 실행" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has 2-run ensemble for all depths"
else
    fail "SKILL.md missing all-depth ensemble"
fi

# Planner has HyDE
if grep -q "HyDE" "$PLUGIN_DIR/agents/research-planner.md" || grep -q "hyde_paragraph" "$PLUGIN_DIR/agents/research-planner.md"; then
    pass "Planner has HyDE (Hypothetical Document Embeddings)"
else
    fail "Planner missing HyDE"
fi

# hooks.json has PostToolUse
if grep -q "PostToolUse" "$PLUGIN_DIR/hooks/hooks.json"; then
    pass "hooks.json has PostToolUse cache hook"
else
    fail "hooks.json missing PostToolUse"
fi

# dr-compress stats test
STATS_OUT=$(echo "Some text with findings about React and Vue performance benchmarks" | "$PLUGIN_DIR/bin/dr-compress" stats 2>/dev/null)
echo "$STATS_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'words' in d and d['words'] > 0" 2>/dev/null && pass "dr-compress stats works" || fail "dr-compress stats failed"

# dr-cite-check check-urls test
URL_CHECK=$(echo '["https://react.dev","https://fake-site.example.com"]' | "$PLUGIN_DIR/bin/dr-cite-check" check-urls 2>/dev/null)
echo "$URL_CHECK" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['total'] == 2
" 2>/dev/null && pass "dr-cite-check check-urls works" || fail "dr-cite-check check-urls failed"

# --- 15. v2.5.1 Evaluation Optimization ---
echo ""
echo "[15] v2.5.1 Evaluation Optimization"

# E1: default rubric has accuracy 0.20 + hard_floor
python3 -c "
import json, re
with open('$PLUGIN_DIR/skills/research/rubrics/default.md') as f:
    m = re.search(r'\`\`\`json\s*\n({.*?})\s*\n\`\`\`', f.read(), re.DOTALL)
    w = json.loads(m.group(1))
    assert w['core']['accuracy'] == 0.20, f'accuracy={w[\"core\"][\"accuracy\"]}'
    assert 'hard_floor' in w, 'missing hard_floor'
    assert w['hard_floor']['accuracy'] == 40
" 2>/dev/null && pass "default rubric: accuracy=0.20 + hard_floor" || fail "default rubric weight incorrect"

# E2: default rubric has new dimensions
python3 -c "
import json, re
with open('$PLUGIN_DIR/skills/research/rubrics/default.md') as f:
    m = re.search(r'\`\`\`json\s*\n({.*?})\s*\n\`\`\`', f.read(), re.DOTALL)
    w = json.loads(m.group(1))
    assert 'citation_quality' in w['context'], 'missing citation_quality'
    assert 'depth' in w['context'], 'missing depth'
    assert 'structure_coherence' in w['core'], 'missing structure_coherence'
" 2>/dev/null && pass "default rubric: citation_quality + depth + structure_coherence" || fail "default rubric missing new dims"

# E3: dr-score calc hard floor test
FLOOR_OUT=$(echo '{"scores":{"accuracy":30,"coverage":80,"recency":80,"structure_coherence":85,"proven":80,"actionability":80,"efficiency":80,"env_fit":80,"citation_quality":80,"depth":80},"target_score":80}' | "$PLUGIN_DIR/bin/dr-score" calc --rubric "$PLUGIN_DIR/skills/research/rubrics/default.md" 2>/dev/null)
echo "$FLOOR_OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d.get('hard_floor_applied') == True, f'hard floor not applied: {d}'
assert d['total'] <= 50, f'total should be capped at 50: {d[\"total\"]}'
" 2>/dev/null && pass "dr-score calc hard floor works (accuracy<40 → cap 50)" || fail "dr-score calc hard floor failed"

# E4: dr-score calc code-only structure (no AI blend)
CODE_STRUCT_OUT=$(echo '{"scores":{"accuracy":80,"coverage":80,"recency":80,"structure_coherence":50,"proven":80,"actionability":80,"efficiency":80,"env_fit":80,"citation_quality":80,"depth":80},"target_score":80}' | "$PLUGIN_DIR/bin/dr-score" calc --rubric "$PLUGIN_DIR/skills/research/rubrics/default.md" --code-metrics '{"structure_score":90,"sea_rate":85}' 2>/dev/null)
echo "$CODE_STRUCT_OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
# structure_coherence should be 100% code: 90 (not blended)
assert d['breakdown']['structure_coherence']['score'] == 90, f'structure={d[\"breakdown\"][\"structure_coherence\"][\"score\"]}'
# coverage should be 100% code: 85 (sea_rate)
assert d['breakdown']['coverage']['score'] == 85, f'coverage={d[\"breakdown\"][\"coverage\"][\"score\"]}'
" 2>/dev/null && pass "dr-score calc: structure/coverage 100% code" || fail "dr-score calc code-only dims failed"

# E5: new rubric profiles exist
for rubric in compliance comparative; do
    [ -f "$PLUGIN_DIR/skills/research/rubrics/$rubric.md" ] && pass "rubrics/$rubric.md exists" || fail "rubrics/$rubric.md missing"
done

# E6: new profiles have JSON weight blocks
for rubric in compliance comparative; do
    if grep -q '"core"' "$PLUGIN_DIR/skills/research/rubrics/$rubric.md"; then
        pass "$rubric.md has JSON weight block"
    else
        fail "$rubric.md missing JSON weight block"
    fi
done

# E7: new profiles have calibration anchors
for rubric in compliance comparative; do
    if grep -q "점수 30 예시" "$PLUGIN_DIR/skills/research/rubrics/$rubric.md"; then
        pass "$rubric.md has 30-point calibration anchor"
    else
        fail "$rubric.md missing 30-point anchor"
    fi
done

# E8: dr-classify detects new profiles
CLASSIFY_COMP=$("$PLUGIN_DIR/bin/dr-classify" profile "GDPR 규정 compliance 감사" 2>/dev/null)
echo "$CLASSIFY_COMP" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['profile']=='compliance', f'expected compliance: {d}'" 2>/dev/null && pass "dr-classify compliance profile works" || fail "dr-classify compliance failed"

CLASSIFY_COMPARE=$("$PLUGIN_DIR/bin/dr-classify" profile "React vs Vue vs Angular 비교 분석" 2>/dev/null)
echo "$CLASSIFY_COMPARE" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['profile']=='comparative', f'expected comparative: {d}'" 2>/dev/null && pass "dr-classify comparative profile works" || fail "dr-classify comparative failed"

# E9: SKILL.md has hard-reject gate
if grep -q "Hard-Reject 게이트" "$PLUGIN_DIR/skills/research/SKILL.md" || grep -q "hard_reject" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has hard-reject gate"
else
    fail "SKILL.md missing hard-reject gate"
fi

# E10: SKILL.md has evaluator parallel execution
if grep -q "병렬 호출" "$PLUGIN_DIR/skills/research/SKILL.md" && grep -q "벽시계 시간 50%" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has parallel evaluator execution"
else
    fail "SKILL.md missing parallel evaluator"
fi

# E11: Evaluator has token budget rule
if grep -q "토큰 예산" "$PLUGIN_DIR/agents/research-evaluator.md"; then
    pass "Evaluator has token budget rule"
else
    fail "Evaluator missing token budget"
fi

# E12: Evaluator has hard floor rule
if grep -q "Hard Floor" "$PLUGIN_DIR/agents/research-evaluator.md"; then
    pass "Evaluator has hard floor warning rule"
else
    fail "Evaluator missing hard floor rule"
fi

# E13: default rubric weights sum to ~1.0
python3 -c "
import json, re
with open('$PLUGIN_DIR/skills/research/rubrics/default.md') as f:
    m = re.search(r'\`\`\`json\s*\n({.*?})\s*\n\`\`\`', f.read(), re.DOTALL)
    w = json.loads(m.group(1))
    skip_keys = {'sea_threshold', 'hard_floor'}
    total = sum(v for k, cat in w.items() if isinstance(cat, dict) and k not in skip_keys for v in cat.values() if isinstance(v, (int, float)))
    assert abs(total - 1.0) < 0.02, f'weights sum to {total}, expected ~1.0'
" 2>/dev/null && pass "default rubric weights sum to ~1.0" || fail "default rubric weights don't sum to 1.0"

# --- 16. Benchmark + Env_Fit ---
echo ""
echo "[16] Benchmark + Env_Fit"

# SKILL.md has context: fork
if grep -q "^context: fork" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has context: fork (isolated execution)"
else
    fail "SKILL.md missing context: fork"
fi

# Synthesizer has 32K handling
if grep -q "32K" "$PLUGIN_DIR/agents/research-synthesizer.md"; then
    pass "Synthesizer has 32K output limit handling"
else
    fail "Synthesizer missing 32K handling"
fi

# hooks.json has UserPromptSubmit
python3 -c "import json; d=json.load(open('$PLUGIN_DIR/hooks/hooks.json')); assert 'UserPromptSubmit' in d['hooks']" 2>/dev/null && pass "hooks.json has UserPromptSubmit (KB injection)" || fail "hooks.json missing UserPromptSubmit"

# hooks.json has PostToolUse with matcher
python3 -c "import json; d=json.load(open('$PLUGIN_DIR/hooks/hooks.json')); assert 'PostToolUse' in d['hooks']" 2>/dev/null && pass "hooks.json has PostToolUse (web cache)" || fail "hooks.json missing PostToolUse"

# dr-contradict IDF fix (small corpus)
CONTRA_SMALL=$(echo '[{"id":"A","text":"X is fast and efficient"},{"id":"B","text":"X is not fast and is slow"}]' | "$PLUGIN_DIR/bin/dr-contradict" detect --threshold 0.3 2>/dev/null)
echo "$CONTRA_SMALL" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['conflicts_found'] >= 1" 2>/dev/null && pass "dr-contradict works on small corpus (IDF fix)" || fail "dr-contradict small corpus failed"

# dr-dry-run functional test
DRY_OUT=$("$PLUGIN_DIR/bin/dr-dry-run" "test query" --depth surface 2>/dev/null)
echo "$DRY_OUT" | grep -q "Dry Run Complete" && pass "dr-dry-run produces output" || fail "dr-dry-run failed"

# --- Summary ---
echo ""
echo "=== Results ==="
echo "  Pass: $PASS | Fail: $FAIL | Warn: $WARN"
echo ""
if [ $FAIL -gt 0 ]; then
    echo "❌ VALIDATION FAILED ($FAIL failures)"
    exit 1
else
    echo "✅ ALL TESTS PASSED"
    exit 0
fi
