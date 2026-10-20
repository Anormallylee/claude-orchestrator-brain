#!/bin/bash
# 派活卡片通知 hook（PreToolUse + PostToolUse，matcher: start_session|spawn_task）
# 只在出现"要用户点一下"的卡片时弹 macOS 通知，避免用户切走时漏点：
#   新版 start_session：
#     own_initiative → PostToolUse 时提醒（生成提议卡片，点了才启动；
#                      主脑被分支回报自动唤醒的那一轮只能这样派活）
#     offer          → PreToolUse 时提醒（调用会卡住，等用户选"新开会话 / 在这里做"）
#     user_asked、带 proposal_id 的启动 → 会话直接开跑，不提醒
#   旧版 spawn_task：每次都生成待点击卡片，PostToolUse 时提醒
# 通知由 ClaudeNotify.app 发出（记在它名下），点击通知会切回 Claude。
[ "$(uname)" = "Darwin" ] || exit 0  # 仅 macOS；其他平台静默跳过，避免每次派活都报 hook 错误
D="$HOME/.claude/hooks/notify"
input=$(cat)
field() { printf '%s' "$input" | jq -r "($1) | tostring | gsub(\"[\\t\\n]\"; \" \")"; }
tool=$(field '.tool_name // ""')
event=$(field '.hook_event_name // ""')
initiation=$(field '.tool_input.initiation // ""')
title=$(field '.tool_input.title // "新分支任务"')
proj=$(basename "$(field '.cwd // ""')")

heading=""
case "$tool" in
  *__spawn_task)
    [ "$event" = "PostToolUse" ] && heading="Claude：有分支待你点击启动" ;;
  *__start_session)
    if [ "$event" = "PostToolUse" ] && [ "$initiation" = "own_initiative" ]; then
      heading="Claude：有提议卡片待你点击启动"
    elif [ "$event" = "PreToolUse" ] && [ "$initiation" = "offer" ]; then
      heading="Claude：在等你选新开会话还是在这里做"
    fi ;;
esac
[ -n "$heading" ] || exit 0

echo "$(date '+%F %T') ${tool##*__}/${initiation:-card}: $title ($proj)" >> "$D/spawn-task.log"
if [ -d "$D/ClaudeNotify.app" ]; then
  printf 'notify\t%s\t%s\t%s' "$title" "$proj" "$heading" > "$D/pending.txt"
  open -g "$D/ClaudeNotify.app"
else
  # 退路：通知记在「脚本编辑器」名下，点击无法回到 Claude
  osascript -e 'on run argv' -e 'display notification (item 1 of argv) with title (item 3 of argv) subtitle (item 2 of argv) sound name "Glass"' -e 'end run' "$title" "$proj" "$heading"
fi
exit 0
