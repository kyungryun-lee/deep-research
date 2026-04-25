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
for rubric in default poc exploration; do
    [ -f "$PLUGIN_DIR/skills/research/rubrics/$rubric.md" ] && pass "rubrics/$rubric.md exists" || fail "rubrics/$rubric.md missing"
done
[ -f "$PLUGIN_DIR/hooks/hooks.json" ] && pass "hooks.json exists" || fail "hooks.json missing"
[ -x "$PLUGIN_DIR/bin/dr-memory" ] && pass "dr-memory is executable" || fail "dr-memory not executable"
[ -x "$PLUGIN_DIR/bin/dr-cache" ] && pass "dr-cache is executable" || fail "dr-cache not executable"
[ -x "$PLUGIN_DIR/bin/dr-verify" ] && pass "dr-verify is executable" || fail "dr-verify not executable"
[ -x "$PLUGIN_DIR/bin/dr-score" ] && pass "dr-score is executable" || fail "dr-score not executable"
[ -x "$PLUGIN_DIR/bin/dr-dedup" ] && pass "dr-dedup is executable" || fail "dr-dedup not executable"

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
[ -x "$PLUGIN_DIR/bin/dr-knowledge" ] && pass "dr-knowledge is executable" || fail "dr-knowledge not executable"

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
[ -x "$PLUGIN_DIR/bin/dr-normalize" ] && pass "dr-normalize is executable" || fail "dr-normalize not executable"

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
BLEND_OUT=$(echo '{"scores":{"accuracy":80,"coverage":80,"recency":70,"structure":80,"proven":80,"actionability":80,"efficiency":80,"env_fit":80},"target_score":80}' | "$PLUGIN_DIR/bin/dr-score" calc --rubric "$PLUGIN_DIR/skills/research/rubrics/default.md" --code-metrics '{"recency_score":90,"structure_score":60}' 2>/dev/null)
echo "$BLEND_OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
# recency should be blended: 0.7*90 + 0.3*70 = 84
assert abs(d['breakdown']['recency']['score'] - 84) < 1, f'recency={d[\"breakdown\"][\"recency\"][\"score\"]}'
# structure should be blended: 0.7*60 + 0.3*80 = 66
assert abs(d['breakdown']['structure']['score'] - 66) < 1, f'structure={d[\"breakdown\"][\"structure\"][\"score\"]}'
" 2>/dev/null && pass "dr-score calc blending works" || fail "dr-score calc blending failed"

# dr-consistency executable
[ -x "$PLUGIN_DIR/bin/dr-consistency" ] && pass "dr-consistency is executable" || fail "dr-consistency not executable"

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

# dr-tokens executable
[ -x "$PLUGIN_DIR/bin/dr-tokens" ] && pass "dr-tokens is executable" || fail "dr-tokens not executable"

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
assert d['total']['potential_savings_pct']==50.0
assert 'planner' in d['by_phase'] and 'evaluator' in d['by_phase']
" 2>/dev/null && pass "dr-tokens record+report works" || fail "dr-tokens record+report failed"

# dr-tokens estimate test
EST_OUT=$("$PLUGIN_DIR/bin/dr-tokens" estimate --query "test" --depth standard 2>/dev/null)
echo "$EST_OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['depth']=='standard'
assert d['estimated_total_cost_usd'] > 0
assert d['estimated_batch_cost_usd'] < d['estimated_total_cost_usd']
" 2>/dev/null && pass "dr-tokens estimate works" || fail "dr-tokens estimate failed"

# Cleanup test token data
sed -i "/$TEST_SESSION/d" "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/deep-research}/tokens/usage.jsonl" 2>/dev/null || true

# dr-batch executable
[ -x "$PLUGIN_DIR/bin/dr-batch" ] && pass "dr-batch is executable" || fail "dr-batch not executable"

# dr-batch list test (no API key needed)
BATCH_LIST=$("$PLUGIN_DIR/bin/dr-batch" list 2>/dev/null)
echo "$BATCH_LIST" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'total' in d" 2>/dev/null && pass "dr-batch list works" || fail "dr-batch list failed"

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
if grep -q "Batch API" "$PLUGIN_DIR/skills/research/SKILL.md"; then
    pass "SKILL.md has Batch API"
else
    fail "SKILL.md missing Batch API"
fi

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
