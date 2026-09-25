#!/bin/bash
# PostToolUse hook（matcher: mcp__ccd_session__spawn_task）
# 主脑生成分支卡片后弹 macOS 通知，避免用户切走时漏点。
# 通知由 ClaudeNotify.app 发出（记在它名下），点击通知会切回 Claude。
D="$HOME/.claude/hooks/notify"
input=$(cat)
title=$(printf '%s' "$input" | jq -r '.tool_input.title // "新分支任务"' | tr '\t\n' '  ')
proj=$(basename "$(printf '%s' "$input" | jq -r '.cwd // ""')")
echo "$(date '+%F %T') spawn_task: $title ($proj)" >> "$D/spawn-task.log"
if [ -d "$D/ClaudeNotify.app" ]; then
  printf 'notify\t%s\t%s' "$title" "$proj" > "$D/pending.txt"
  open -g "$D/ClaudeNotify.app"
else
  # 退路：通知记在「脚本编辑器」名下，点击无法回到 Claude
  osascript -e 'on run argv' -e 'display notification (item 1 of argv) with title "Claude：有分支待你点击启动" subtitle (item 2 of argv) sound name "Glass"' -e 'end run' "$title" "$proj"
fi
exit 0
