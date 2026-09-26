#!/usr/bin/env bash
# 安装宽匹配杀进程守卫：
#   1. 软链接 hook 脚本到 ~/.claude/hooks/guard/
#   2. 把 PreToolUse(Bash) hook 合并进 ~/.claude/settings.json（已存在则跳过，改前备份）
# 卸载：./install.sh --uninstall
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
DEST="$CLAUDE_DIR/hooks/guard"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT="block-broad-kill.py"
CMD="python3 \"$DEST/$SCRIPT\""

command -v jq >/dev/null || { echo "需要 jq：brew install jq"; exit 1; }

backup_settings() {
  [ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d%H%M%S)"
}

# 按脚本名识别本 hook：Bash 这个 matcher 可能还挂着别的 hook，不能按 matcher 整条删
if [ "${1:-}" = "--uninstall" ]; then
  if [ -f "$SETTINGS" ]; then
    backup_settings
    tmp="$(mktemp)"
    jq --arg s "$SCRIPT" '
      if .hooks.PreToolUse then
        .hooks.PreToolUse |= (map(.hooks |= map(select((.command // "") | contains($s) | not)))
                              | map(select(.hooks | length > 0)))
      else . end' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  fi
  rm -f "$DEST/$SCRIPT"
  echo "已卸载"
  exit 0
fi

# python3 不可用时 hook 会报错但不阻塞命令，等于静默失效，所以装之前先查
if ! python3 -c 'import json, re' >/dev/null 2>&1; then
  echo "python3 不可用（macOS 需先 xcode-select --install），未安装"
  exit 1
fi

mkdir -p "$DEST"
link_dst="$DEST/$SCRIPT"
if [ -e "$link_dst" ] && [ ! -L "$link_dst" ]; then
  mv "$link_dst" "$link_dst.bak-$(date +%Y%m%d%H%M%S)"
  echo "已备份原有 $link_dst"
fi
ln -sf "$REPO/$SCRIPT" "$link_dst"
echo "$link_dst -> $REPO/$SCRIPT"

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
if jq -e --arg s "$SCRIPT" '.hooks.PreToolUse // [] | any(.[].hooks[]?; (.command // "") | contains($s))' "$SETTINGS" >/dev/null; then
  echo "settings.json 已有 $SCRIPT 的 hook，跳过"
else
  backup_settings
  tmp="$(mktemp)"
  jq --arg c "$CMD" \
    '.hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{matcher: "Bash", hooks: [{type: "command", command: $c, timeout: 5}]}])' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "已写入 settings.json 的 PreToolUse hook"
fi

echo "已开着的会话一般会自动加载；验证：在会话里让 Claude 执行 killall __guard_test__，应被拒绝。没生效就重启会话"
