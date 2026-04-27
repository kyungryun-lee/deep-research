# Changelog

For detailed change-by-change records (CHG-001~), see `.changes/changelog.jsonl`.

## [2.5.6] - 2026-04-27

### Refactored
- bin/lib/dr_text.py shared text utilities (tokenize/cosine/STOPWORDS/normalize_url) — 7 scripts unified, NFC normalization auto-corrected in 4 files
- SKILL.md prompt caching principle deduplicated (4 occurrences → 1 + reference)
- validate-plugin.sh file-existence checks consolidated into Section 1 loop
- 5 evaluation rubrics finalized: default, poc, exploration, compliance, comparative

### Fixed
- dr-dedup `cmd_text` `lstrip('www.')` bug — replaced with `re.sub`
- dr-classify `cmd_all` profile coverage (added compliance/comparative — earlier session)

### Documentation
- README.md rubric table updated (5 profiles with weights, SEA threshold, hard floor)
- plugin.json/marketplace.json/CHANGELOG version synchronized with implementation

## [2.5.0~2.5.5] - 2026-04-25~26
- Phase A optimization, Phase B knowledge & consistency, Phase C advanced caching
- Meta-evaluation P0 (8 changes) + P1 (3 changes) applied (CHG-084~094)
- See `.changes/changelog.jsonl` for full history

## [1.0.0] - 2026-04-23

### Added
- Initial release: 4 specialized agents (planner, worker, evaluator, synthesizer)
- SKILL.md orchestrator with 5-phase pipeline
- ARISE quality evaluation, FAIR-RAG SEA gating, Reflexion self-improvement
- dr-memory CLI, Generator-Verifier separation, adaptive strategy planning
