# Clawdbot Cost Tracker

Track **accurate** Clawdbot API costs from session JSONL files.

## Installation

```bash
clawdhub install clawdbot-cost-tracker
```

## Quick Start

```bash
# Get all daily costs
bash scripts/extract-cost.sh

# Yesterday's cost
bash scripts/extract-cost.sh --yesterday

# Specific date
bash scripts/extract-cost.sh --date 2026-01-30

# JSON output
bash scripts/extract-cost.sh --json
```

## ⚠️ Important Note

This skill reads **actual API costs** from session JSONL files (`usage.cost.total`), not estimated token counts.

The `sessions_list` API's `totalTokens` field is **not suitable** for cost tracking - it represents current context window size and resets after compaction.

## Documentation

See [SKILL.md](./SKILL.md) for full documentation.
