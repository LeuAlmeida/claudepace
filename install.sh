#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.claude/scripts"
TARGET="$TARGET_DIR/claudepace.sh"
SETTINGS="$HOME/.claude/settings.json"

echo "→ Installing claudepace..."

mkdir -p "$TARGET_DIR"
cp "$SCRIPT_DIR/claudepace.sh" "$TARGET"
chmod +x "$TARGET"

echo "  ✓ Script copied to $TARGET"

# Wire into Claude Code settings.json
if [ ! -f "$SETTINGS" ]; then
    echo '{}' > "$SETTINGS"
fi

# Check if statusLine already set
current=$(python3 -c "
import json
with open('$SETTINGS') as f:
    d = json.load(f)
print(d.get('statusLine', {}).get('command', ''))
" 2>/dev/null || echo "")

if [ -n "$current" ] && [ "$current" != "$TARGET" ]; then
    echo ""
    echo "  ⚠  settings.json already has a statusLine command:"
    echo "     $current"
    echo ""
    read -r -p "  Replace it with claudepace? [y/N] " reply
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
        echo "  Skipped. Add manually to ~/.claude/settings.json:"
        echo '  "statusLine": {"command": "'"$TARGET"'"}'
        exit 0
    fi
fi

python3 -c "
import json
with open('$SETTINGS') as f:
    d = json.load(f)
d['statusLine'] = {'command': '$TARGET'}
with open('$SETTINGS', 'w') as f:
    json.dump(d, f, indent=2)
print('  ✓ settings.json updated')
"

echo ""
echo "  Done. Restart Claude Code to see your quota bar."
echo ""
echo "  Optional: set a custom daily cap in ~/.claudepace"
echo "  echo 'DAILY_CAP=14' > ~/.claudepace"
echo ""
