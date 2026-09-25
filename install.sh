#!/usr/bin/env bash
# 把本仓库的 skill 和 output style 软链接到 ~/.claude/
# 参数（可组合）：
#   --styles-only  只装 output style（skill 已经通过 plugin 安装时用）
#   --notify       另外安装分支卡片通知（仅 macOS 桌面 App，见 notify/）
# 已存在的非链接文件移到 ~/.claude/backups/claude-orchestrator-brain-<时间>/（放在 skills/ 里会被当成重复 skill 加载）
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
BACKUP="$CLAUDE_DIR/backups/claude-orchestrator-brain-$(date +%Y%m%d%H%M%S)"

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    mkdir -p "$BACKUP"
    mv "$dst" "$BACKUP/"
    echo "已备份 $dst -> $BACKUP/"
  fi
  ln -s "$src" "$dst"
  echo "$dst -> $src"
}

STYLES_ONLY=0
NOTIFY=0
for arg in "$@"; do
  case "$arg" in
    --styles-only) STYLES_ONLY=1 ;;
    --notify) NOTIFY=1 ;;
    *) echo "未知参数：$arg（可用：--styles-only --notify）"; exit 1 ;;
  esac
done

# --styles-only：skill 已经通过 plugin 安装时，只装 output style（plugin 目前不支持打包 output style）
if [ "$STYLES_ONLY" = 0 ]; then
  for d in "$REPO"/skills/*/; do
    name="$(basename "$d")"
    link "${d%/}" "$CLAUDE_DIR/skills/$name"
  done
fi

for f in "$REPO"/output-styles/*.md; do
  link "$f" "$CLAUDE_DIR/output-styles/$(basename "$f")"
done

# --notify：分支卡片通知不打包进 plugin——它只对 macOS 桌面 App 有意义，且会改变系统通知行为，需显式选择
if [ "$NOTIFY" = 1 ]; then
  "$REPO/notify/install.sh"
fi
