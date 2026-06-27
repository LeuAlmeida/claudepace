# claudepace

Stop burning through your Claude Code tokens by Wednesday.

Adds a live progress bar to your Claude Code status line — shows weekly quota usage, your safe daily budget, and whether you're on track to last the full week.

```
┄ ████████████░░░░░░░░ 58%  week  ·  6.1%/day left  ·  3d 4h  ·  ↑ fast  ┄
```

---

## The problem

Claude Code Max resets weekly. If you don't pace yourself, you hit the limit on Thursday and have nothing left for the actual deadlines that show up Friday.

## Install

```bash
git clone https://github.com/leuAlmeida/claudepace
cd claudepace
./install.sh
```

Then restart Claude Code. That's it.

## What it shows

```
┄ ████████░░░░░░░░░░░░ 34%  week  ·  12.0%/day left  ·  4d 6h  ·  ~ pace  ┄
```

| Field | Meaning |
|-------|---------|
| `34% week` | How much of your weekly quota you've used |
| `12.0%/day left` | How much you can safely burn per day to reach Sunday |
| `4d 6h` | Time until quota resets |
| `~ pace` | Whether you're on track — `~ pace`, `↑ fast`, `↑↑ over`, or `↓ slow` |

The bar turns yellow when you're burning faster than the safe pace, red when you're significantly over.

## Pace status

claudepace compares your actual usage against the ideal burn rate for the current point in the week:

- `~ pace` — you're on track to finish Sunday with quota to spare
- `↑ fast` — slightly ahead of pace, slow down a bit
- `↑↑ over` — burning too fast, today's budget is nearly gone
- `↓ slow` — well under pace, you have headroom to go harder

## Optional config

Create `~/.claudepace` to override the daily cap target:

```bash
echo 'DAILY_CAP=14' > ~/.claudepace
```

Default is `100/7 ≈ 14.3%` — evenly distributed across the week. Set a lower number if you need to preserve quota for specific days.

## How it works

Claude Code passes usage data to a configurable status line script after each response. claudepace reads the 7-day rate limit percentage and reset timestamp, then calculates expected vs actual burn to give you a real-time pace signal.

No API calls. No background process. Just a shell script that runs locally in under 50ms.

## Manual setup

If you'd rather wire it up yourself, add this to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "command": "/path/to/claudepace/claudepace.sh"
  }
}
```

## Uninstall

```bash
# Remove the script
rm ~/.claude/scripts/claudepace.sh

# Remove the config file (if you created one)
rm -f ~/.claudepace

# Remove from ~/.claude/settings.json
# Delete the "statusLine" key, or set it back to your previous command
```

---

MIT License
