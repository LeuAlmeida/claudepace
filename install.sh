#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.claude/scripts"
TARGET="$TARGET_DIR/claudepace.sh"
SETTINGS="$HOME/.claude/settings.json"
CONFIG="$HOME/.claudepace"

echo ""
echo "  claudepace install"
echo "  ──────────────────"

mkdir -p "$TARGET_DIR"
cp "$SCRIPT_DIR/claudepace.sh" "$TARGET"
chmod +x "$TARGET"
echo "  ✓ Script → $TARGET"

# Daily cap config
DEFAULT_CAP=$(python3 -c "print(round(100/7, 1))")
echo ""
echo "  Weekly quota resets every 7 days."
echo "  Default daily cap: ${DEFAULT_CAP}% (100% ÷ 7 days)"
echo ""
read -r -p "  Daily cap % [${DEFAULT_CAP}]: " cap_input
CAP="${cap_input:-$DEFAULT_CAP}"

echo "DAILY_CAP=${CAP}" > "$CONFIG"
echo "  ✓ Daily cap set to ${CAP}% → $CONFIG"

# Wire into settings.json
if [ ! -f "$SETTINGS" ]; then
    echo '{}' > "$SETTINGS"
fi

current=$(python3 -c "
import json
with open('$SETTINGS') as f:
    d = json.load(f)
print(d.get('statusLine', {}).get('command', ''))
" 2>/dev/null || echo "")

if [ -n "$current" ] && [ "$current" != "$TARGET" ]; then
    echo ""
    echo "  ⚠  statusLine já configurada:"
    echo "     $current"
    echo ""
    read -r -p "  Substituir? [y/N] " reply
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
        echo ""
        echo "  Skipped. Adicione manualmente ao ~/.claude/settings.json:"
        echo "    \"statusLine\": {\"command\": \"$TARGET\"}"
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
"
echo "  ✓ settings.json atualizado"

echo ""
echo "  ✅  Pronto. Reinicie o Claude Code."
echo ""
echo "  Para mudar o cap depois:"
echo "  echo 'DAILY_CAP=10' > ~/.claudepace"
echo ""
