# claudepace

Stop burning through your Claude Code tokens by Wednesday.

Adds a live status line to Claude Code — weekly quota bar, 5-hour session bar, daily budget tracking, and pace signal so you always know if you're on track to last the full week.

```
┄ week ████████░░░░░░░░ 48%  5h ████░░░░░░░░░░░░ 22%  ·  9.1% left today  (5.2% of 14.3% cap)  ·  3d 6h  ·  ~ pace  ┄
```

---

## The problem

Claude Code Max resets weekly. If you don't pace yourself, you hit the limit on Thursday and have nothing left for the deadlines that show up Friday.

## Install

```bash
git clone https://github.com/leuAlmeida/claudepace
cd claudepace
./install.sh
```

Restart Claude Code. Done.

The installer asks for your daily cap target (default `14.3%` — 100% ÷ 7 days).

## What it shows

```
┄ week ████████░░░░░░░░ 48%  5h ████░░░░░░░░░░░░ 22%  resets 1h 12m  ·  9.1% left today  (5.2% of 14.3% cap)  ·  3d 6h  ·  ~ pace  ┄
```

| Field | Meaning |
|-------|---------|
| `week 48%` | Weekly quota used |
| `5h 22%` | 5-hour rolling session used (matches `/usage`) |
| `resets 1h 12m` | Time until 5-hour window resets |
| `9.1% left today` | Remaining daily budget |
| `(5.2% of 14.3% cap)` | How much you've used today vs your daily cap |
| `3d 6h` | Time until weekly quota resets |
| `~ pace` | Whether you're on track for the week |

Values shown with `~` prefix are cached from the last active session — they update automatically on the next response.

## Pace signal

Compares actual usage against the ideal burn rate for the current point in the week:

| Signal | Meaning |
|--------|---------|
| `~ pace` | On track to finish Sunday with quota to spare |
| `↑ fast` | Slightly ahead of pace |
| `↑↑ over` | Burning too fast, daily budget nearly gone |
| `↓ slow` | Well under pace, headroom to go harder |

Bar color follows the same signal — green, yellow, or red.

## Cross-session sync

The state file (`~/.claudepace-state`) is shared across all Claude Code sessions. Any active session keeps it updated — open a new session without sending a message and it will still show your real current usage from the last response in any session.

## Optional config

```bash
echo 'DAILY_CAP=14.3' > ~/.claudepace
```

Default is `100/7 ≈ 14.3%`. Lower it to preserve quota for specific days.

## Debug mode

```bash
CLAUDEPACE_DEBUG=1 claude
```

Dumps the raw JSON context to `~/.claudepace-debug.json` on each response.

## How it works

Claude Code passes usage data to a configurable status line script after each response. claudepace reads the 7-day and 5-hour rate limit fields, calculates pace against a daily baseline, and persists state for cross-session accuracy.

No background process. No API calls. Runs locally in under 50ms.

## Manual setup

```json
{
  "statusLine": {
    "command": "/path/to/claudepace/claudepace.sh"
  }
}
```

Or combine with another status line script by calling claudepace as a final line from your existing script:

```bash
echo "$INPUT" | bash "$HOME/.claude/scripts/claudepace.sh"
```

## Uninstall

```bash
rm ~/.claude/scripts/claudepace.sh
rm -f ~/.claudepace ~/.claudepace-state
# Remove "statusLine" key from ~/.claude/settings.json
```

---

MIT License
