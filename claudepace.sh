#!/usr/bin/env bash
# claudepace - weekly quota tracker for Claude Code
# https://github.com/leuAlmeida/claudepace

cat | python3 -c "
import sys, json, datetime, os

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

rl = data.get('rate_limits', {})
week = rl.get('seven_day', {})
fiveh = rl.get('five_hour', {})

used = float(week.get('used_percentage') or 0)
resets_at_str = week.get('resets_at', '') or ''
fiveh_used = float(fiveh.get('used_percentage') or 0)

# Read optional daily cap from ~/.claudepace config
daily_cap = None
config_path = os.path.expanduser('~/.claudepace')
if os.path.exists(config_path):
    try:
        with open(config_path) as f:
            for line in f:
                line = line.strip()
                if line.startswith('DAILY_CAP='):
                    daily_cap = float(line.split('=', 1)[1].strip())
    except Exception:
        pass

# Calculate days remaining in reset window
days_left = 7.0
if resets_at_str:
    try:
        resets_at = datetime.datetime.fromisoformat(resets_at_str.replace('Z', '+00:00'))
        now = datetime.datetime.now(datetime.timezone.utc)
        delta = resets_at - now
        days_left = min(7.0, max(0.5, delta.total_seconds() / 86400))
    except Exception:
        pass

days_elapsed = 7.0 - days_left
ideal_used = (days_elapsed / 7.0) * 100.0

remaining = 100.0 - used
daily_budget = remaining / max(days_left, 0.5)

cap = daily_cap if daily_cap else round(100.0 / 7, 1)
pace_delta = used - ideal_used

# Color codes
RED    = '\033[38;5;203m'
YELLOW = '\033[38;5;220m'
GREEN  = '\033[38;5;114m'
BLUE   = '\033[38;5;75m'
DIM    = '\033[2m'
BOLD   = '\033[1m'
RESET  = '\033[0m'

if pace_delta > 20:
    status_color = RED
    status_icon = '↑↑'
    status_label = 'over'
elif pace_delta > 8:
    status_color = YELLOW
    status_icon = '↑'
    status_label = 'fast'
elif pace_delta < -15:
    status_color = BLUE
    status_icon = '↓'
    status_label = 'slow'
else:
    status_color = GREEN
    status_icon = '~'
    status_label = 'pace'

# Progress bar (week)
BAR_W = 20
filled = min(round(used / 100.0 * BAR_W), BAR_W)
bar = status_color + ('█' * filled) + DIM + ('░' * (BAR_W - filled)) + RESET

# Time left
d = int(days_left)
h = int((days_left - d) * 24)
time_left = f'{d}d {h}h' if d > 0 else f'{h}h'

# 5h burst indicator (only show if notable)
burst_str = ''
if fiveh_used > 50:
    burst_color = RED if fiveh_used > 80 else YELLOW
    burst_str = f'  {DIM}|{RESET}  {burst_color}5h {fiveh_used:.0f}%{RESET}'

budget_color = RED if daily_budget < cap * 0.3 else (YELLOW if daily_budget < cap * 0.7 else GREEN)

print(
    f'{DIM}┄{RESET} '
    f'{bar} '
    f'{status_color}{BOLD}{used:.0f}%{RESET}{DIM} week{RESET}'
    f'  {DIM}·{RESET}  '
    f'{budget_color}{daily_budget:.1f}%{RESET}{DIM}/day left{RESET}'
    f'  {DIM}·{RESET}  '
    f'{DIM}{time_left}{RESET}'
    f'  {DIM}·{RESET}  '
    f'{status_color}{status_icon} {status_label}{RESET}'
    f'{burst_str}'
    f'  {DIM}┄{RESET}'
)
"
