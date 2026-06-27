#!/usr/bin/env bash
# claudepace - weekly quota tracker for Claude Code
# https://github.com/LeuAlmeida/claudepace

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

# --- Config (~/.claudepace) ---
daily_cap = 100.0 / 7  # default: 14.3%
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

# --- State file: track today's starting % ---
state_path = os.path.expanduser('~/.claudepace-state')
today = datetime.date.today().isoformat()
start_pct = used  # fallback: assume started at current

if os.path.exists(state_path):
    try:
        with open(state_path) as f:
            lines = dict(l.strip().split('=', 1) for l in f if '=' in l)
        if lines.get('date') == today:
            start_pct = float(lines.get('start_pct', used))
        else:
            # New day — reset baseline
            start_pct = used
            with open(state_path, 'w') as f:
                f.write(f'date={today}\nstart_pct={used}\n')
    except Exception:
        pass
else:
    try:
        with open(state_path, 'w') as f:
            f.write(f'date={today}\nstart_pct={used}\n')
    except Exception:
        pass

today_used = max(0.0, used - start_pct)
today_remaining = max(0.0, daily_cap - today_used)

# --- Days left in week ---
days_left = 7.0
if resets_at_str:
    try:
        resets_at = datetime.datetime.fromisoformat(resets_at_str.replace('Z', '+00:00'))
        now = datetime.datetime.now(datetime.timezone.utc)
        delta = resets_at - now
        days_left = min(7.0, max(0.5, delta.total_seconds() / 86400))
    except Exception:
        pass

# --- Pace (is weekly on track?) ---
days_elapsed = 7.0 - days_left
ideal_used = (days_elapsed / 7.0) * 100.0
pace_delta = used - ideal_used

# --- Colors ---
RED    = '\033[38;5;203m'
YELLOW = '\033[38;5;220m'
GREEN  = '\033[38;5;114m'
BLUE   = '\033[38;5;75m'
DIM    = '\033[2m'
BOLD   = '\033[1m'
RESET  = '\033[0m'

if pace_delta > 20:
    pace_color = RED;    pace_icon = '↑↑'; pace_label = 'over'
elif pace_delta > 8:
    pace_color = YELLOW; pace_icon = '↑';  pace_label = 'fast'
elif pace_delta < -15:
    pace_color = BLUE;   pace_icon = '↓';  pace_label = 'slow'
else:
    pace_color = GREEN;  pace_icon = '~';  pace_label = 'pace'

# Today remaining color
if today_remaining <= daily_cap * 0.15:
    today_color = RED
elif today_remaining <= daily_cap * 0.4:
    today_color = YELLOW
else:
    today_color = GREEN

# --- Weekly bar ---
BAR_W = 20
filled = min(round(used / 100.0 * BAR_W), BAR_W)
bar = pace_color + ('█' * filled) + DIM + ('░' * (BAR_W - filled)) + RESET

# --- Time left ---
d = int(days_left)
h = int((days_left - d) * 24)
time_left = f'{d}d {h}h' if d > 0 else f'{h}h'

# --- 5h burst (only if notable) ---
burst_str = ''
if fiveh_used > 50:
    burst_color = RED if fiveh_used > 80 else YELLOW
    burst_str = f'  {DIM}|{RESET}  {burst_color}5h {fiveh_used:.0f}%{RESET}'

print(
    f'{DIM}┄{RESET} '
    f'{bar} '
    f'{pace_color}{BOLD}{used:.0f}%{RESET}{DIM} week{RESET}'
    f'  {DIM}·{RESET}  '
    f'{today_color}{BOLD}{today_remaining:.1f}%{RESET}{DIM} left hoje{RESET}'
    f'  {DIM}({today_used:.1f}% of {daily_cap:.1f}% cap){RESET}'
    f'  {DIM}·{RESET}  '
    f'{DIM}{time_left}{RESET}'
    f'  {DIM}·{RESET}  '
    f'{pace_color}{pace_icon} {pace_label}{RESET}'
    f'{burst_str}'
    f'  {DIM}┄{RESET}'
)
"
