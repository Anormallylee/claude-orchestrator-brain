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

## 兼容性

**目前只在 Claude Code 桌面版上验证过。** 调度依赖它的跨会话能力：

| 能力 | 用到的工具 |
|---|---|
| 开新会话派活 | `spawn_task` |
| 会话之间互发消息（派活、回报、交回） | `SendMessage`、`ListAgents` |
| 盘点和归档会话 | `list_sessions`、`get_session`、`archive_session` |
| 主脑切换 output style | `set_session_output_style` |

- **Claude Code 命令行版**：skill、plugin、output style 都能用。桌面版专属的工具（名字带 `ccd_` 前缀：开新会话、盘点和归档会话、切 output style）在命令行版里没有，skill 会自动退回手动方式：
  - 主脑把派活提示贴出来，你自己开新会话粘贴进去；
  - output style 由你手动切换；
  - 归档改为提醒你自己关掉会话。

  `SendMessage` / `ListAgents` 是核心工具，命令行版大概率可以用，但还没实测。
- **其他 AI 编程工具**：未验证，不保证能用。
- **可以通用的部分**：台账增删改、自报不算验收、变异探针、契约先行、按周交接这些做法，本身跟工具无关，在任何工具里都可以手动照搬。

## 其他说明

- skill 只能手动调用（`disable-model-invocation: true`），不会被自动触发。

## 许可证

[MIT](LICENSE)
