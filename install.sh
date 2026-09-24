#!/usr/bin/env bash
# 把本仓库的 skill 和 output style 软链接到 ~/.claude/
# 已存在的非链接文件移到 ~/.claude/backups/claude-skills-<时间>/（放在 skills/ 里会被当成重复 skill 加载）
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
BACKUP="$CLAUDE_DIR/backups/claude-skills-$(date +%Y%m%d%H%M%S)"

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

# --styles-only：skill 已经通过 plugin 安装时，只装 output style（plugin 目前不支持打包 output style）
if [ "${1:-}" != "--styles-only" ]; then
  for d in "$REPO"/skills/*/; do
    name="$(basename "$d")"
    link "${d%/}" "$CLAUDE_DIR/skills/$name"
  done
fi

for f in "$REPO"/output-styles/*.md; do
  link "$f" "$CLAUDE_DIR/output-styles/$(basename "$f")"
done
