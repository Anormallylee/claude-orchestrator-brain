#!/usr/bin/env bash
# 安装分支卡片通知（仅 macOS 桌面 App）：
#   1. 编译 ClaudeNotify.app 到 ~/.claude/hooks/notify/
#   2. 软链接 hook 脚本到同一目录
#   3. 把 PreToolUse + PostToolUse hook 合并进 ~/.claude/settings.json（改前备份；
#      旧版只挂 spawn_task 的那条会被替换）
# 卸载：./install.sh --uninstall
# 新旧桌面 App 都适用：新版挂 start_session（只在生成待点击卡片时提醒），旧版挂 spawn_task。
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
DEST="$CLAUDE_DIR/hooks/notify"
SETTINGS="$CLAUDE_DIR/settings.json"
MATCHER="mcp__ccd_session__start_session|mcp__ccd_session__spawn_task"
OLD_MATCHER="mcp__ccd_session__spawn_task"
CMD="bash \"$DEST/spawn-task-notify.sh\""
BUNDLE_ID="local.claude-orchestrator.notify"

[ "$(uname)" = "Darwin" ] || { echo "仅支持 macOS"; exit 1; }
command -v jq >/dev/null || { echo "需要 jq：brew install jq"; exit 1; }

# 删掉本组件写过的 hook（含旧版只挂 spawn_task 的那条）
JQ_REMOVE='reduce ("PreToolUse","PostToolUse") as $e (.;
  if .hooks[$e] then .hooks[$e] |= map(select(.matcher != $m and .matcher != $o)) else . end)'

backup_settings() {
  [ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d%H%M%S)"
}

if [ "${1:-}" = "--uninstall" ]; then
  if [ -f "$SETTINGS" ]; then
    backup_settings
    tmp="$(mktemp)"
    jq --arg m "$MATCHER" --arg o "$OLD_MATCHER" "$JQ_REMOVE" "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
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

# 合并 hook 配置：先删旧条目再追加，重复安装结果一致
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
backup_settings
tmp="$(mktemp)"
jq --arg m "$MATCHER" --arg o "$OLD_MATCHER" --arg c "$CMD" "$JQ_REMOVE"' |
  reduce ("PreToolUse","PostToolUse") as $e (.;
    .hooks[$e] = ((.hooks[$e] // []) + [{matcher: $m, hooks: [{type: "command", command: $c, timeout: 10, async: true}]}]))' \
  "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
echo "已写入 settings.json 的 PreToolUse / PostToolUse hook"

# 触发一次通知：首次会弹出系统授权
printf 'notify\t%s\t%s\t%s' "安装完成：这是一条测试通知" "claude-orchestrator-brain" "Claude：派活卡片通知已就绪" > "$DEST/pending.txt"
open -g "$DEST/ClaudeNotify.app"

cat <<MSG

下一步：
  1. 系统询问「ClaudeNotify 想要发送通知」时点允许
  2. 系统设置 → 通知 → ClaudeNotify：样式改成「提醒」（横幅几秒就消失）
  3. 已经开着的主脑会话需要重启才会加载 hook
MSG
