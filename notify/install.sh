#!/usr/bin/env bash
# 安装分支卡片通知（仅 macOS 桌面 App）：
#   1. 编译 ClaudeNotify.app 到 ~/.claude/hooks/notify/
#   2. 软链接 hook 脚本到同一目录
#   3. 把 PostToolUse hook 合并进 ~/.claude/settings.json（已存在则跳过，改前备份）
# 卸载：./install.sh --uninstall
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
DEST="$CLAUDE_DIR/hooks/notify"
SETTINGS="$CLAUDE_DIR/settings.json"
MATCHER="mcp__ccd_session__spawn_task"
CMD="bash \"$DEST/spawn-task-notify.sh\""
BUNDLE_ID="local.claude-orchestrator.notify"

[ "$(uname)" = "Darwin" ] || { echo "仅支持 macOS"; exit 1; }
command -v jq >/dev/null || { echo "需要 jq：brew install jq"; exit 1; }

backup_settings() {
  [ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d%H%M%S)"
}

if [ "${1:-}" = "--uninstall" ]; then
  if [ -f "$SETTINGS" ]; then
    backup_settings
    tmp="$(mktemp)"
    jq --arg m "$MATCHER" 'if .hooks.PostToolUse then .hooks.PostToolUse |= map(select(.matcher != $m)) else . end' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  fi
  rm -rf "$DEST/ClaudeNotify.app" "$DEST/spawn-task-notify.sh" "$DEST/pending.txt"
  echo "已卸载（日志 $DEST/spawn-task.log 保留）"
  exit 0
fi

mkdir -p "$DEST"

# 编译通知器 App：不占 Dock（LSUIElement），固定 bundle id，本地 ad-hoc 签名
rm -rf "$DEST/ClaudeNotify.app"
osacompile -o "$DEST/ClaudeNotify.app" "$REPO/ClaudeNotify.applescript" 2>/dev/null  # 新版 macOS 会打印无害的 "replacing existing signature"
PLIST="$DEST/ClaudeNotify.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :LSUIElement true" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST"
codesign --force --deep -s - "$DEST/ClaudeNotify.app" 2>/dev/null
echo "已编译 $DEST/ClaudeNotify.app"

# hook 脚本
ln -sf "$REPO/spawn-task-notify.sh" "$DEST/spawn-task-notify.sh"
echo "$DEST/spawn-task-notify.sh -> $REPO/spawn-task-notify.sh"

# 合并 hook 配置
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
if jq -e --arg m "$MATCHER" '.hooks.PostToolUse // [] | any(.matcher == $m)' "$SETTINGS" >/dev/null; then
  echo "settings.json 已有 $MATCHER 的 hook，跳过"
else
  backup_settings
  tmp="$(mktemp)"
  jq --arg m "$MATCHER" --arg c "$CMD" \
    '.hooks.PostToolUse = ((.hooks.PostToolUse // []) + [{matcher: $m, hooks: [{type: "command", command: $c, timeout: 10, async: true}]}])' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "已写入 settings.json 的 PostToolUse hook"
fi

# 触发一次通知：首次会弹出系统授权
printf 'notify\t%s\t%s' "安装完成：这是一条测试通知" "claude-orchestrator-brain" > "$DEST/pending.txt"
open -g "$DEST/ClaudeNotify.app"

cat <<MSG

下一步：
  1. 系统询问「ClaudeNotify 想要发送通知」时点允许
  2. 系统设置 → 通知 → ClaudeNotify：样式改成「提醒」（横幅几秒就消失）
  3. 已经开着的主脑会话需要重启才会加载 hook
MSG
