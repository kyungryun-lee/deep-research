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
for rubric in default academic practical trend; do
    [ -f "$PLUGIN_DIR/skills/research/rubrics/$rubric.md" ] && pass "rubrics/$rubric.md exists" || fail "rubrics/$rubric.md missing"
done
[ -f "$PLUGIN_DIR/hooks/hooks.json" ] && pass "hooks.json exists" || fail "hooks.json missing"
[ -x "$PLUGIN_DIR/bin/dr-memory" ] && pass "dr-memory is executable" || fail "dr-memory not executable"

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
for rubric in default academic practical trend; do
    if grep -q '"weights"' "$PLUGIN_DIR/skills/research/rubrics/$rubric.md"; then
        pass "$rubric.md has JSON weight block"
    else
        fail "$rubric.md missing JSON weight block"
    fi
done

# --- 6. Independence Rules ---
echo ""
echo "[6] Independence Rules"
if grep -q "원본 전달 원칙" "$PLUGIN_DIR/skills/research/SKILL.md"; then
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
