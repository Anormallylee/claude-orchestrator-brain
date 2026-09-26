#!/usr/bin/env python3
"""PreToolUse(Bash) 守卫：拦截 `pkill -f`、`killall`、`kill $(pgrep -f ...)`。

背景（2026-09-26）：某子代理执行 `pkill -f "cat" -n`，-f 匹配完整命令行，
"/Applications" 含子串 "cat"，一次性 SIGTERM 了 47 个进程（几乎所有 GUI 应用）。
BSD pkill 遇到首个非选项参数就停止解析，写在后面的 -n 并不生效。
"""
import json, re, sys

try:
    cmd = json.load(sys.stdin).get("tool_input", {}).get("command", "") or ""
except Exception:
    sys.exit(0)

# 按 shell 分隔符切段，逐段看命令词（允许 sudo / env / 绝对路径前缀）
segments = re.split(r"[;&|\n(){}`]|\$\(", cmd)
reason = None
for seg in segments:
    toks = seg.strip().split()
    while toks and (toks[0] in ("sudo", "env", "exec", "command", "nohup", "time", "xargs")
                    or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", toks[0]) or toks[0].startswith("-")):
        toks = toks[1:]
    if not toks:
        continue
    name = toks[0].rsplit("/", 1)[-1].strip("\"'")
    if name == "killall":
        reason = "killall"
        break
    if name == "pkill":
        for t in toks[1:]:
            t = t.strip("\"'")
            if t == "--full" or re.match(r"^-[A-Za-z0-9]*f[A-Za-z0-9]*$", t):
                reason = "pkill -f"
                break
        if reason:
            break

# `kill $(pgrep -f ...)` / kill `pgrep -f ...` / `pgrep -f ... | xargs kill`：与 pkill -f 等价
PGREP_F = r"pgrep\b[^)`|;&\n]*?\s(-[A-Za-z0-9]*f[A-Za-z0-9]*|--full)(?=\s|$)"
if not reason and (
    re.search(r"\bkill\b[^;&|\n]*(\$\(|`)\s*(\S*/)?" + PGREP_F, cmd)
    or re.search(PGREP_F + r"[^|;&\n]*\|\s*(sudo\s+)?xargs\b[^|;&\n]*\bkill\b", cmd)
):
    reason = "kill $(pgrep -f ...)"

if not reason:
    sys.exit(0)

msg = (
    f"已被全局 hook 拦截：禁止使用 `{reason}`。"
    "它按名字/整条命令行正则匹配，范围不可控——曾因 `pkill -f \"cat\"` 命中 \"/Applications\" "
    "而杀掉用户几乎全部应用。请改为：先 `pgrep -fl '<精确模式>'` 列出并确认 PID，"
    "再 `kill <PID>`；或者用自己启动时记录的 PID（`$!`）。"
    "如确需此操作，请停下来向用户说明具体要杀哪些进程，由用户亲自执行。"
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": msg,
    }
}, ensure_ascii=False))
