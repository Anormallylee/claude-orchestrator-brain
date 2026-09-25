-- 分支卡片通知器（macOS）。
-- 依据 Apple《Mac Automation Scripting Guide · Displaying Notifications》：
--   脚本编译成 App 后，通知记在该 App 名下；点击通知会重新打开该 App 并再次执行 run。
-- 用状态文件区分两种进入方式：
--   hook 写入 notify 请求 → 发通知；
--   没有请求 → 视为用户点了通知 → 切回 Claude。
on run
	set stateFile to (POSIX path of (path to home folder)) & ".claude/hooks/notify/pending.txt"
	set req to ""
	try
		set req to do shell script "cat " & quoted form of stateFile & " 2>/dev/null; rm -f " & quoted form of stateFile
	end try
	if req starts with "notify" then
		set AppleScript's text item delimiters to tab
		set parts to text items of req
		set AppleScript's text item delimiters to ""
		set t to "新分支任务"
		set p to ""
		if (count of parts) ≥ 2 then set t to item 2 of parts
		if (count of parts) ≥ 3 then set p to item 3 of parts
		display notification t with title "Claude：有分支待你点击启动" subtitle p sound name "Glass"
	else
		tell application "Claude" to activate
	end if
end run
