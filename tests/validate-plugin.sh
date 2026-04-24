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
