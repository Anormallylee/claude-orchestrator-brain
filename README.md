# claude-orchestrator-brain

让一个 [Claude Code](https://docs.claude.com/en/docs/claude-code) 会话当「主脑」，调度同一项目里多个并行开发的会话。

> 非官方项目，与 Anthropic 无关联。

同一个项目里同时跑多个 Claude Code 会话时，指定其中一个会话当主脑，其他会话都是分支会话。主脑只做四件事：**派活、独立验收、合入、记账**，自己不写实现代码，也不展开设计讨论。

适合这样的工作方式：一个项目同时有好几条功能或修复分支在飞，每条分支交给一个独立会话去做，你只和主脑对话。另外还可以随手开讨论会话，把有价值的结论交回主脑。

## 解决的问题

| 没有主脑时 | brain 的做法 |
|---|---|
| 分支说"测过了"就合 | 自报不算验收。主脑核对 tip，跑全量加集成测试，并自己选变异探针（必须变红）。 |
| 主线状态只在聊天记录里，会话一压缩就丢 | 台账提交进仓库，任何新会话读台账就能接着干。 |
| 台账越写越长，变成流水账 | 台账只反映"现在"，用增删改的方式维护；流水按周归档；交接页每周整篇覆盖。 |
| 派活提示每次临时写，容易漏项 | 固定的派活模板和回报格式，所有槽位必填。 |
| 分支会话假借用户授权，让主脑代做它被拒绝的操作 | 视为权限洗白，拒绝并报告用户。 |
| 会话越跑越长，主脑忘了自己的角色 | output style 常驻系统提示，压缩后也不会丢。 |
| 讨论会话的结论散落在各处，或者没经确认就被当成定案 | `/brain-handback` 分类、写成文档再交回；口头决定要回主脑确认后才生效。 |

## 文件

```
.claude-plugin/          plugin 与 marketplace 清单
skills/brain/
  SKILL.md               主流程：开局、台账、派活、接收交回、验收、合入、周切换、红线
  dispatch-template.md   派活提示模板 + 分支回报格式
  ledger-template.md     ledger / decisions / 周流水 / handoff / inbox 模板
skills/brain-handback/
  SKILL.md               讨论会话把结论分类、写成文档、交回主脑
output-styles/brain.md   主脑角色约束（常驻系统提示）
install.sh               软链接安装
notify/                  可选：分支卡片通知（macOS 桌面 App）
  install.sh             编译通知器、装 hook
  ClaudeNotify.applescript  通知器源码
  spawn-task-notify.sh   PostToolUse hook 脚本
```

## 安装

**方式一：plugin（推荐给只用不改的人）**

在 Claude Code 里执行：

```
/plugin marketplace add Anormallylee/claude-orchestrator-brain
/plugin install orchestrator@claude-orchestrator-brain
```

plugin 目前不支持打包 output style，所以 output style 需要另外装一次：

```bash
git clone https://github.com/Anormallylee/claude-orchestrator-brain.git
cd claude-orchestrator-brain
./install.sh --styles-only
```

用 plugin 安装后，命令名会带上前缀：`/orchestrator:brain`、`/orchestrator:brain-handback`。

**方式二：软链接（适合要改 skill 的人）**

```bash
git clone https://github.com/Anormallylee/claude-orchestrator-brain.git
cd claude-orchestrator-brain
./install.sh
```

skill 和 output style 都会以软链接的形式装到 `~/.claude/` 下，命令名是 `/brain`、`/brain-handback`。在仓库里改文件，本机立即生效。已经存在的同名文件会移到 `~/.claude/backups/`。

两种方式只选一种。都装的话，菜单里会出现两份同样的 skill。

## 使用

**主脑**：在项目里新开一个会话，输入 `/brain`。

主脑会先切到 `brain` output style，然后找台账，并把自己登记为「当前主脑会话」。第一次在某个项目里用时，它会问你几项规则参数：
- WIP 上限
- 合入权限
- 测试口径

问完后建立 `brain/` 目录，下面有：
- `ledger.md`：当前状态
- `decisions.md`：仍然有效的决定
- `handoff.md`：交接页
- `log/<周>.md`：本周流水
- `inbox/`：讨论会话交回的文档

**讨论会话**：在项目里随手开一个会话讨论问题。讨论出值得交给主脑的结论时，输入 `/brain-handback`。它会：
- 先把结论分成三类给你过目：不交回 / 待拍板 / 缺陷或缺口；
- 你确认后写成文档并提交；
- 从台账找到当前主脑，把回报发过去。

你在讨论会话里口头定下的事，会作为"待确认"交回。主脑会再问你一句，你确认后才生效，避免转述走样。讨论会话不改代码，要改的交给主脑派活。

**建议按周轮换主脑会话。** 周末让主脑收尾，它会整理台账并覆盖 `handoff.md`。下周开新会话，粘贴 `handoff.md` 末尾的开场白即可。

## 可选：分支卡片通知（macOS 桌面 App）

桌面 App 里，主脑用 `spawn_task` 派活时生成的是一张**需要你点一下才会启动**的卡片。卡片不会触发系统通知，你切到别的 App 时很容易漏看，分支就一直卡着没开工。

`notify/` 用一个 hook 补上这个提醒：主脑每生成一张卡片，就弹一条 macOS 通知，标题写着分支名，**点通知会切回 Claude**。

```bash
cd claude-orchestrator-brain/notify
./install.sh              # 卸载：./install.sh --uninstall
```

安装脚本会：
- 用系统自带的 `osacompile` 编译一个不占 Dock 的小 App `ClaudeNotify.app`，放在 `~/.claude/hooks/notify/` 下；
- 把 hook 脚本软链接到同一目录；
- 往 `~/.claude/settings.json` 合并一条 `PostToolUse` hook（matcher 为 `mcp__ccd_session__spawn_task`）。已经有同名 hook 就跳过，改动前会先备份。

装完需要你做两件事：
1. 系统询问「ClaudeNotify 想要发送通知」时点**允许**。
2. 在「系统设置 → 通知 → ClaudeNotify」里把样式改成**提醒**。横幅几秒就消失，人不在电脑前等于没通知。

已经开着的主脑会话要重启才会加载 hook。每生成一张卡片会在 `~/.claude/hooks/notify/spawn-task.log` 记一行，没收到通知时可以先查这里。

**为什么不直接用 `osascript`**：命令行里执行 `display notification`，通知会记在「脚本编辑器」名下，点击只会打开脚本编辑器，没法指定点击后去哪。按 Apple 的 [Mac Automation Scripting Guide](https://developer.apple.com/library/archive/documentation/LanguagesUtilities/Conceptual/MacAutomationScriptingGuide/DisplayNotifications.html)，把脚本编译成独立 App 后，通知就记在这个 App 名下，点击通知会重新打开它并再次执行 `run`。`ClaudeNotify` 利用这一点：被 hook 调起时发通知，被点击打开时把 Claude 切到前台。这样不用装 `terminal-notifier` 之类的第三方工具。

**限制**：点通知只会把 Claude 切到前台，不会精确跳到发出卡片的那个会话。依赖 `jq`（`brew install jq`）。

## 兼容性

前提：**一个人在自己的环境里调度多个会话**。所有会话必须在同一台机器、同一个系统用户下，因为会话之间的消息走的是每个 Claude Code 进程在 `/tmp` 下开的本机 socket，不经过任何服务器。

| 环境 | 能否使用 | 自动化程度 | 验证状态 |
|---|---|---|---|
| 桌面 App（macOS）Code 标签页 | ✅ 完整可用 | 全自动：主脑自己开会话、收回报、归档、切 output style | 已实测 |
| 命令行版（macOS） | ✅ 可用 | 半自动：会话之间互发消息是自动的；开会话要手动；没有归档这一步；output style 写进设置文件 | 已实测：有 `SendMessage` / `ListAgents`，发出的消息能送到其他会话 |
| 命令行版（Linux） | 🟡 预计同 macOS 命令行版 | 同上 | 未实测，消息通道机制相同 |
| VS Code / JetBrains 插件 | 🟡 预计同命令行版 | 同上 | 未实测 |
| 桌面 App（Windows） | ❓ 未知 | — | 未实测 |
| 网页版 / 云端会话 | ❌ 不适合当分支会话 | — | 云端会话能收消息，但暂时不能回发，回报回不到主脑 |
| 其他 AI 编程工具 | ❌ skill 用不了 | 只能手动照搬做法 | — |

欢迎在 issue 里补充实测结果，尤其是 Linux、Windows 和 IDE 插件。

**桌面 App 专属的工具**（名字带 `ccd_` 前缀）：`spawn_task`（开新会话派活）、`list_sessions` / `get_session` / `archive_session`（盘点和归档会话）、`set_session_output_style`（切 output style）。其他环境里没有这些工具，skill 会自动退回手动方式，不会报错停下。

**纯命令行版里怎么派活：**
- **推荐**：用 tmux 或终端分屏开几个窗格，一个窗格跑一个 `claude`。主脑把派活提示贴出来，你粘贴到对应窗格。回报通过 `SendMessage` 自动回到主脑。
- **全自动**：主脑用 `Agent` 工具派子代理，每个子代理用独立的 worktree。代价是你没法单独和子代理对话，子代理跑的时候也会占用主脑的上下文。
- output style 可以写进项目的 `.claude/settings.local.json`：`{"outputStyle": "brain"}`。
- 命令行会话的名字每次启动都会变，比如 `<目录名>-51`。主脑每次调用 `/brain` 都会重新登记自己的名字，所以不影响使用；想用固定名字的话，可以执行 `/rename`。

**可以通用的部分**：台账增删改、自报不算验收、变异探针、契约先行、按周交接这些做法，本身跟工具无关，在任何工具里都可以手动照搬。

## 其他说明

- skill 只能手动调用（`disable-model-invocation: true`），不会被自动触发。

## 许可证

[MIT](LICENSE)
