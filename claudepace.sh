#!/usr/bin/env bash
# claudepace - weekly quota tracker for Claude Code
# https://github.com/LeuAlmeida/claudepace

cat | python3 -c "
import sys, json, datetime, os

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

# Debug mode: CLAUDEPACE_DEBUG=1 logs raw JSON to ~/.claudepace-debug.json
if os.environ.get('CLAUDEPACE_DEBUG') == '1':
    try:
        with open(os.path.expanduser('~/.claudepace-debug.json'), 'w') as f:
            json.dump(data, f, indent=2)
    except Exception:
        pass

rl = data.get('rate_limits', {})
week = rl.get('seven_day', {})
fiveh = rl.get('five_hour', {})

used = float(week.get('used_percentage') or 0)
fiveh_used = float(fiveh.get('used_percentage') or 0)

# resets_at can be Unix timestamp (int) or ISO string
def parse_resets_at(val):
    if not val:
        return ''
    try:
        if isinstance(val, (int, float)):
            dt = datetime.datetime.fromtimestamp(val, tz=datetime.timezone.utc)
        else:
            dt = datetime.datetime.fromisoformat(str(val).replace('Z', '+00:00'))
        return dt.isoformat()
    except Exception:
        return ''

resets_at_str = parse_resets_at(week.get('resets_at'))

# --- Session data ---
session_cost = float((data.get('cost') or {}).get('total_cost_usd') or 0)
ctx_pct = float((data.get('context_window') or {}).get('used_percentage') or 0)

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

# --- State file: track today's baseline + persist resets_at ---
state_path = os.path.expanduser('~/.claudepace-state')
today = datetime.date.today().isoformat()
start_pct = used
stored_resets_at = ''

state = {}
if os.path.exists(state_path):
    try:
        with open(state_path) as f:
            state = dict(l.strip().split('=', 1) for l in f if '=' in l)
    except Exception:
        pass

if state.get('date') == today:
    start_pct = float(state.get('start_pct', used))
    stored_resets_at = state.get('resets_at', '')
else:
    # New day — reset daily baseline, keep resets_at if still valid
    stored_resets_at = state.get('resets_at', '')
    start_pct = used
    state = {'date': today, 'start_pct': str(used), 'resets_at': stored_resets_at}

# Update resets_at if API gave us a fresh one
if resets_at_str:
    state['resets_at'] = resets_at_str
    stored_resets_at = resets_at_str

# Cache last known non-zero values — shared across all sessions via state file.
# When a session opens with 0% (no response yet), show cached value with ~ prefix.
cached_week = float(state.get('last_week_pct', 0))
cached_5h   = float(state.get('last_5h_pct', 0))

week_stale = fiveh_stale = False

if used == 0 and cached_week > 0:
    used = cached_week
    week_stale = True
    if start_pct == 0:
        start_pct = float(state.get('start_pct', used))

if fiveh_used == 0 and cached_5h > 0:
    fiveh_used = cached_5h
    fiveh_stale = True

if not week_stale and used > 0:
    state['last_week_pct'] = str(used)
if not fiveh_stale and fiveh_used > 0:
    state['last_5h_pct'] = str(fiveh_used)
fiveh_resets_at_str_local = parse_resets_at(fiveh.get('resets_at'))
if fiveh_resets_at_str_local:
    state['last_5h_resets_at'] = fiveh_resets_at_str_local

try:
    with open(state_path, 'w') as f:
        for k, v in state.items():
            f.write(f'{k}={v}\n')
except Exception:
    pass

# --- Days left in week ---
days_left = 7.0
effective_resets_at = resets_at_str or stored_resets_at
if effective_resets_at:
    try:
        resets_at = datetime.datetime.fromisoformat(effective_resets_at.replace('Z', '+00:00'))
        now = datetime.datetime.now(datetime.timezone.utc)
        delta = resets_at - now
        days_left = min(7.0, max(0.5, delta.total_seconds() / 86400))
    except Exception:
        pass

# --- Calendar-day pace (Sat=day1, Sun=day2, Mon=day3) ---
current_day = 1
days_elapsed_calendar = 0
if effective_resets_at:
    try:
        resets_at_dt = datetime.datetime.fromisoformat(effective_resets_at.replace('Z', '+00:00'))
        reset_start_date = (resets_at_dt - datetime.timedelta(days=7)).date()
        days_elapsed_calendar = max(0, (datetime.date.today() - reset_start_date).days)
        current_day = days_elapsed_calendar + 1
    except Exception:
        days_elapsed_calendar = int(7.0 - days_left)
        current_day = days_elapsed_calendar + 1

ideal_used = (days_elapsed_calendar / 7.0) * 100.0
pace_delta = used - ideal_used

# --- Today's budget: distribute remaining quota across remaining days ---
today_used = max(0.0, used - start_pct)
days_remaining = max(1, 7 - days_elapsed_calendar)  # includes today
smart_daily_budget = (100.0 - used) / days_remaining
effective_daily_budget = min(smart_daily_budget, daily_cap)  # never exceed configured cap
today_remaining = max(0.0, effective_daily_budget - today_used)

USD = chr(36)  # avoid bash $ expansion inside double-quoted heredoc

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

# --- 5h resets_at ---
fiveh_resets_at_str = parse_resets_at(fiveh.get('resets_at'))
fiveh_time_left = ''
if fiveh_resets_at_str:
    try:
        fiveh_resets = datetime.datetime.fromisoformat(fiveh_resets_at_str)
        now = datetime.datetime.now(datetime.timezone.utc)
        delta = (fiveh_resets - now).total_seconds()
        if delta > 0:
            hh = int(delta // 3600)
            mm = int((delta % 3600) // 60)
            fiveh_time_left = f'{hh}h {mm}m'
    except Exception:
        pass

# --- Bars ---
BAR_W = 16
filled = min(round(used / 100.0 * BAR_W), BAR_W)
bar_week = pace_color + ('█' * filled) + DIM + ('░' * (BAR_W - filled)) + RESET

fiveh_color = RED if fiveh_used > 80 else (YELLOW if fiveh_used > 50 else GREEN)
fiveh_filled = min(round(fiveh_used / 100.0 * BAR_W), BAR_W)
bar_5h = fiveh_color + ('█' * fiveh_filled) + DIM + ('░' * (BAR_W - fiveh_filled)) + RESET

# --- Time left (week) ---
d = int(days_left)
h = int((days_left - d) * 24)
time_left = f'{d}d {h}h' if d > 0 else f'{h}h'

fiveh_reset_str = f'  {DIM}resets {fiveh_time_left}{RESET}' if fiveh_time_left else ''

week_pct_str  = f'{DIM}~{RESET}{pace_color}{BOLD}{used:.0f}%{RESET}' if week_stale  else f'{pace_color}{BOLD}{used:.0f}%{RESET}'
fiveh_pct_str = f'{DIM}~{RESET}{fiveh_color}{BOLD}{fiveh_used:.0f}%{RESET}' if fiveh_stale else f'{fiveh_color}{BOLD}{fiveh_used:.0f}%{RESET}'

pace_delta_str = f'{pace_delta:+.0f}%'

print(
    f'{DIM}┄{RESET} '
    f'{DIM}week{RESET} {bar_week} {week_pct_str}'
    f'  {DIM}5h{RESET} {bar_5h} {fiveh_pct_str}{fiveh_reset_str}'
    f'  {DIM}·{RESET}  '
    f'{today_color}{BOLD}{today_remaining:.1f}%{RESET}{DIM} left today{RESET}'
    f'  {DIM}({today_used:.1f}% used · {effective_daily_budget:.1f}% budget){RESET}'
    f'  {DIM}·{RESET}  '
    f'{DIM}day {current_day}/7  {time_left}{RESET}'
    f'  {DIM}·{RESET}  '
    f'{pace_color}{pace_icon} {pace_label} {DIM}({pace_delta_str}){RESET}'
    f'  {DIM}┄{RESET}'
)
"
