#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  从 GitHub 安装 flutter-skills 到当前项目
# ────────────────────────────────────────────────────────────────────
#  用法: 在项目根目录下跑
#    bash <(curl -s https://raw.githubusercontent.com/dus2183-commits/flutter-skills/main/scripts/install_skills.sh)
#  或:
#    bash path/to/install_skills.sh
#
#  效果:
#    1. 从 GitHub clone flutter-skills 仓库到临时目录
#    2. 复制 35 个 SKILL.md 到 .claude/skills/
#    3. 复制 _design + _knowledge + _governance 到项目根
#    4. 复制 CLAUDE_full.md 到 CLAUDE.md (如不存在)
#    5. 安装全局 flutter-init (如不存在)
#    6. 清理临时目录
# ════════════════════════════════════════════════════════════════════

set -e

REPO="https://github.com/dus2183-commits/flutter-skills.git"
TMP_DIR="/tmp/flutter-skills-install-$$"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Flutter Skills — 安装到项目         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
echo

# ─── 1. Clone ───
echo -e "${BLUE}[1/5]${NC} 从 GitHub 克隆..."
git clone --depth 1 "$REPO" "$TMP_DIR" 2>/dev/null
echo -e "${GREEN}  ✓ 克隆完成${NC}"

# ─── 2. 复制 SKILL.md ───
echo -e "${BLUE}[2/5]${NC} 安装 skill..."
TARGET=".claude/skills"
mkdir -p "$TARGET"

count=0
for dir in "$TMP_DIR"/flutter-*/; do
  name=$(basename "$dir")
  if [ -f "$dir/SKILL.md" ]; then
    mkdir -p "$TARGET/$name"
    cp "$dir/SKILL.md" "$TARGET/$name/"
    count=$((count + 1))
  fi
done
for dir in "$TMP_DIR"/_orchestration/flutter-flow-*/; do
  name=$(basename "$dir")
  if [ -f "$dir/SKILL.md" ]; then
    mkdir -p "$TARGET/$name"
    cp "$dir/SKILL.md" "$TARGET/$name/"
    count=$((count + 1))
  fi
done
echo -e "${GREEN}  ✓ $count 个 skill 已安装${NC}"

# ─── 3. 复制 _design / _knowledge / _governance ───
echo -e "${BLUE}[3/5]${NC} 复制设计文档..."
cp -r "$TMP_DIR/_design" . 2>/dev/null && echo -e "${GREEN}  ✓ _design${NC}" || true
cp -r "$TMP_DIR/_knowledge" . 2>/dev/null && echo -e "${GREEN}  ✓ _knowledge${NC}" || true
cp -r "$TMP_DIR/_governance" . 2>/dev/null && echo -e "${GREEN}  ✓ _governance${NC}" || true

# ─── 4. CLAUDE.md ───
echo -e "${BLUE}[4/5]${NC} 检查 CLAUDE.md..."
if [ ! -f "CLAUDE.md" ]; then
  cp "$TMP_DIR/flutter-init/template/_claude_templates/CLAUDE_full.md" CLAUDE.md
  echo -e "${GREEN}  ✓ CLAUDE_full.md 已复制为 CLAUDE.md${NC}"
else
  echo -e "  ⏭ CLAUDE.md 已存在，跳过"
fi

# ─── 5. 全局 flutter-init ───
echo -e "${BLUE}[5/5]${NC} 检查全局 flutter-init..."
GLOBAL_SKILLS="$HOME/.claude/skills"
mkdir -p "$GLOBAL_SKILLS"
if [ ! -e "$GLOBAL_SKILLS/flutter-init" ]; then
  ln -s "$TMP_DIR/flutter-init" "$GLOBAL_SKILLS/flutter-init" 2>/dev/null || {
    mkdir -p "$GLOBAL_SKILLS/flutter-init"
    cp "$TMP_DIR/flutter-init/SKILL.md" "$GLOBAL_SKILLS/flutter-init/"
  }
  echo -e "${GREEN}  ✓ flutter-init 已安装到全局${NC}"
else
  echo -e "  ⏭ flutter-init 已存在"
fi
if [ ! -e "$GLOBAL_SKILLS/flutter-flow-init" ]; then
  mkdir -p "$GLOBAL_SKILLS/flutter-flow-init"
  cp "$TMP_DIR/_orchestration/flutter-flow-init/SKILL.md" "$GLOBAL_SKILLS/flutter-flow-init/"
  echo -e "${GREEN}  ✓ flutter-flow-init 已安装到全局${NC}"
else
  echo -e "  ⏭ flutter-flow-init 已存在"
fi

# ─── 清理 ───
rm -rf "$TMP_DIR"

echo
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  安装完成！${NC}"
echo -e "${GREEN}  - $count 个 skill 在 .claude/skills/${NC}"
echo -e "${GREEN}  - _design + _knowledge + _governance${NC}"
echo -e "${GREEN}  - CLAUDE.md (full 规范)${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo
echo "重新打开 Claude Code 即可使用。"
