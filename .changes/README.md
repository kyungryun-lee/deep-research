# Change Tracking

This directory tracks all changes to the deep-research plugin with traceability for issue analysis.

## Structure

```
.changes/
├── README.md           # This file
├── changelog.jsonl     # Machine-readable change log (append-only)
└── decisions/          # Architecture Decision Records (ADRs)
    └── NNN-title.md
```

## changelog.jsonl Format

Each line is a JSON object:
```json
{
  "id": "CHG-001",
  "date": "2026-04-23",
  "type": "optimize|fix|feature|refactor",
  "scope": "planner|worker|evaluator|synthesizer|skill|infra",
  "summary": "Brief description",
  "rationale": "Why this change was made",
  "source": "research|verifier-feedback|bug-report|user-request",
  "files_changed": ["path1", "path2"],
  "metrics_before": {"cost": "X", "time": "Y", "quality": "Z"},
  "metrics_after": {"cost": "X", "time": "Y", "quality": "Z"},
  "risk": "low|medium|high",
  "rollback": "How to revert if issues arise",
  "test_result": "pass|fail|pending",
  "git_commit": "sha"
}
```

## Issue Tracing

When an issue occurs:
1. Check `changelog.jsonl` for recent changes in the affected scope
2. Each change has `rationale` (why) and `rollback` (how to revert)
3. `metrics_before/after` shows if the change caused degradation
4. `source` traces back to the original research/feedback that triggered the change
