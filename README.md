# Deep Research Plugin for Claude Code

Adaptive deep research plugin that dynamically plans strategy per query, evaluates quality with an independent verifier, and learns from every execution.

## Features

- **Adaptive Strategy**: Automatically adjusts agent count, source types, and search depth based on query complexity
- **Generator-Verifier Separation**: Research execution and quality evaluation run in independent contexts to prevent self-confirmation bias
- **ARISE 7-Dimension Evaluation**: Scope, Literature, Analysis, Recency, Actionability, Organization, References
- **FAIR-RAG SEA Gating**: Structured Evidence Assessment checklist ensures information completeness
- **Self-Improvement**: Reflexion-based episodic memory learns from every execution
- **4 Evaluation Rubrics**: default, academic, practical, trend — each with different weight profiles
- **Independent Package**: Zero dependencies on any external project

---

## Prerequisites

Before installing, ensure you have:

| Requirement | Check Command | Minimum Version |
|-------------|--------------|-----------------|
| Claude Code CLI | `claude --version` | v2.1.30+ |
| Internet access | — | WebSearch/WebFetch tools |

**No API keys or additional software required.** The plugin uses Claude Code's built-in WebSearch and WebFetch tools.

---

## Installation

### Option A: From Marketplace (recommended for teams)

```bash
# 1. Add the marketplace (one-time)
/plugin marketplace add https://github.com/anthropics/deep-research.git

# 2. Install the plugin
/plugin install deep-research@deep-research-marketplace

# 3. Verify installation
/deep-research:research --help
```

### Option B: Local Directory (for development/testing)

```bash
# Clone the repository
git clone https://github.com/anthropics/deep-research.git

# Run Claude Code with the plugin loaded
claude --plugin-dir ./deep-research
```

### Option C: Team-wide Auto-install

Add to your project's `.claude/settings.json`:
```json
{
  "extraKnownMarketplaces": {
    "deep-research-marketplace": {
      "source": { "source": "github", "repo": "your-org/deep-research" }
    }
  }
}
```

Then every team member can install with:
```bash
/plugin install deep-research@deep-research-marketplace
```

---

## Quick Start

### Basic Research
```
/deep-research:research "What are the latest trends in agentic AI development?"
```

### With Options
```
/deep-research:research --depth deep --rubric academic "Transformer architecture variants 2025"
/deep-research:research --rubric practical --output ./reports/gerrit.md "Gerrit AI automation"
/deep-research:research --rubric trend "2026 agentic coding trends"
```

### Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `query` | any text | (required) | Research topic or question |
| `--depth` | `surface` / `standard` / `deep` | `standard` | Controls agent count and search breadth |
| `--rubric` | `default` / `academic` / `practical` / `trend` | `default` | Evaluation criteria profile |
| `--output` | file path | `./research-report-{date}.md` | Report save location |

---

## Configuration

After installation, you can customize the plugin behavior through Claude Code's plugin config system.

### User Config (set during install or later)

| Setting | Description | Default |
|---------|-------------|---------|
| `default_depth` | Default research depth | `standard` |
| `max_iterations` | Max Generator-Verifier loops | `3` |
| `output_dir` | Default report output directory | current directory |
| `default_rubric` | Default evaluation rubric | `default` |

### How to Change Settings

```bash
# View current plugin config
/plugin config deep-research

# Or manually edit your settings file
# ~/.claude/settings.json (personal)
# .claude/settings.json (project-level, shared via git)
```

---

## Evaluation Rubrics

Each rubric adjusts dimension weights for different research goals:

| Rubric | Best For | Key Weights |
|--------|----------|-------------|
| `default` | General research | Balanced across all 7 dimensions |
| `academic` | Paper surveys, theory | Literature 25%, References 15% (stricter) |
| `practical` | Implementation guides | Actionability 25%, code examples prioritized |
| `trend` | Market/tech trends | Recency 25%, Scope 20%, diverse perspectives |

### Dimension Weights Comparison

| Dimension | default | academic | practical | trend |
|-----------|---------|----------|-----------|-------|
| Scope | 15% | 10% | 10% | **20%** |
| Literature | 20% | **25%** | 15% | 15% |
| Analysis | 20% | 20% | 15% | 15% |
| Recency | 15% | 15% | 15% | **25%** |
| Actionability | 15% | 10% | **25%** | 10% |
| Organization | 5% | 5% | 5% | 5% |
| References | 10% | **15%** | 15% | 10% |
| SEA Threshold | 80% | **85%** | 75% | 75% |

---

## How It Works

```
/deep-research:research "your question"
         |
   Phase 1-2: CLASSIFY + PLAN
         |  Planner (Opus) analyzes query complexity
         |  Assigns agent count, search queries, SEA checklist
         |  Loads past session reflections for strategy optimization
         v
   Phase 3: EXECUTE (Generator)
         |  Worker agents (Sonnet x N) search in parallel
         |  WebSearch + WebFetch with fallback chains
         |  Source grading: S(official/peer-reviewed) > A(engineering) > B(community) > C(blog)
         v
   Phase 4: EVALUATE (Verifier - independent context)
         |  ARISE 7-dimension scoring with rubric-specific weights
         |  FAIR-RAG SEA gating for completeness check
         |  FAIL -> supplement search -> re-evaluate (max 3 loops)
         v
   Phase 5: SYNTHESIZE + LEARN
         |  Report generation (trade-off matrices, implementation roadmap)
         |  Reflexion: lessons_learned saved for future sessions
         v
   Output: Report file + quality score + learning record
```

### Independence Guarantee

The Evaluator (Verifier) operates under strict independence rules:
1. **Raw delivery**: Generator output is passed unmodified — no summarization by the orchestrator
2. **No anchoring**: Previous round scores are never shared with the Evaluator
3. **No confirmation bias**: "Improved X" context is never provided — Evaluator judges absolute quality
4. **File-based transfer**: Generator saves to file, Evaluator reads directly — structural guarantee

---

## Memory & Self-Improvement

The plugin learns from every execution. Session data is stored at:
```
~/.claude/plugins/data/deep-research/memory/sessions.jsonl
```

Each session records:
- Query, type, complexity, strategy used
- Final quality score and iteration count
- `lessons_learned`: what worked, what failed, what to change next time
- Source statistics and execution metrics

### Memory CLI

```bash
dr-memory stats     # Cumulative statistics
dr-memory list      # Recent research sessions
dr-memory show 3    # Details of session #3
dr-memory clear     # Reset history (with confirmation)
```

---

## Architecture

```
deep-research/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest + user config schema
├── skills/research/
│   ├── SKILL.md                 # Orchestrator (5-phase pipeline)
│   └── rubrics/
│       ├── default.md           # Balanced 7-dimension rubric
│       ├── academic.md          # Paper/theory focused
│       ├── practical.md         # Implementation focused
│       └── trend.md             # Trends/market focused
├── agents/
│   ├── research-planner.md      # Strategy planning (Opus)
│   ├── research-worker.md       # Search/collection (Sonnet, parallel)
│   ├── research-evaluator.md    # Independent quality evaluation (Opus)
│   └── research-synthesizer.md  # Report generation + learning (Opus)
├── hooks/hooks.json             # Session start: memory directory init
├── bin/dr-memory                # Memory management CLI
├── marketplace.json             # Distribution manifest
├── README.md
├── CHANGELOG.md
└── LICENSE (MIT)
```

---

## Troubleshooting

### "WebFetch permission denied"
Grant WebFetch permission when prompted, or add to your settings:
```json
{ "permissions": { "allow": ["WebFetch(*)", "WebSearch(*)"] } }
```

### "Memory file not found"
Run any research once — the memory directory is auto-created on first session.
Or manually: `mkdir -p ~/.claude/plugins/data/deep-research/memory`

### "Rubric file not found"
Ensure the plugin is properly installed. Check with `/plugin list`.
If using `--plugin-dir`, verify the directory structure matches the Architecture section above.

### Research takes too long
- Use `--depth surface` for quick lookups
- Reduce `max_iterations` to 1 in plugin config
- Simple factual questions don't need this plugin — ask Claude directly

### Low quality scores
- Use `--rubric academic` for paper surveys (strict but appropriate)
- Use `--rubric practical` for implementation questions (emphasizes code examples)
- Check `dr-memory list` to see if past sessions are being leveraged

---

## Design References

| Design Decision | Based On |
|----------------|----------|
| Adaptive agent scaling | [Anthropic Multi-Agent Research System](https://www.anthropic.com/engineering/multi-agent-research-system) |
| ARISE 7-dimension evaluation | [ARISE: Agentic Rubric-Guided Survey Engine](https://arxiv.org/abs/2511.17689) |
| SEA gating | [FAIR-RAG](https://arxiv.org/abs/2510.22344) |
| Verifier independence | [INDICT: Dual-Critic Architecture](https://arxiv.org/abs/2407.02518) (NeurIPS 2024) |
| Reflexion self-improvement | [Reflexion](https://arxiv.org/abs/2303.11366) + [Anthropic 40% efficiency gain](https://www.anthropic.com/engineering/multi-agent-research-system) |
| Source grading (S/A/B/C) | Academic publication trust hierarchy |
| Plugin packaging | [Claude Code Plugin Spec](https://code.claude.com/docs/en/plugins) |

---

## Contributing

1. Fork the repository
2. Test locally: `claude --plugin-dir ./deep-research`
3. Run a research query and verify all 5 phases complete
4. Submit a pull request

---

## License

MIT
