#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  从 GitHub 更新项目中的 flutter-skills
# ────────────────────────────────────────────────────────────────────
#  用法: 在项目根目录下跑
#    bash <(curl -s https://raw.githubusercontent.com/dus2183-commits/flutter-skills/main/scripts/update_skills.sh)
#  或:
#    bash path/to/update_skills.sh
#
#  效果:
#    1. 从 GitHub 拉取最新版
#    2. 覆盖 .claude/skills/ 下所有 SKILL.md
#    3. 覆盖 _design + _knowledge + _governance
#    4. 不动 CLAUDE.md (保留你的自定义)
#    5. 不动 .claude/settings.json (保留权限配置)
# ════════════════════════════════════════════════════════════════════

set -e

REPO="https://github.com/dus2183-commits/flutter-skills.git"
TMP_DIR="/tmp/flutter-skills-update-$$"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Flutter Skills — 更新               ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
echo

# ─── 检查 ───
if [ ! -d ".claude/skills" ]; then
  echo -e "${RED}  ❌ .claude/skills/ 不存在，请先跑 install_skills.sh${NC}"
  exit 1
fi

OLD_COUNT=$(ls .claude/skills/ | wc -l | tr -d ' ')
echo -e "  当前: $OLD_COUNT 个 skill"
echo

# ─── 1. Clone 最新版 ───
echo -e "${BLUE}[1/3]${NC} 从 GitHub 拉取最新版..."
git clone --depth 1 "$REPO" "$TMP_DIR" 2>/dev/null
echo -e "${GREEN}  ✓ 拉取完成${NC}"

# ─── 2. 更新 SKILL.md ───
echo -e "${BLUE}[2/3]${NC} 更新 skill..."
TARGET=".claude/skills"

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
echo -e "${GREEN}  ✓ $count 个 skill 已更新${NC}"

# ─── 3. 更新 _design / _knowledge / _governance ───
echo -e "${BLUE}[3/3]${NC} 更新设计文档..."
rm -rf _design _knowledge _governance 2>/dev/null
cp -r "$TMP_DIR/_design" . 2>/dev/null && echo -e "${GREEN}  ✓ _design${NC}" || true
cp -r "$TMP_DIR/_knowledge" . 2>/dev/null && echo -e "${GREEN}  ✓ _knowledge${NC}" || true
cp -r "$TMP_DIR/_governance" . 2>/dev/null && echo -e "${GREEN}  ✓ _governance${NC}" || true

# ─── 清理 ───
rm -rf "$TMP_DIR"

echo
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  更新完成！${NC}"
echo -e "${GREEN}  - $OLD_COUNT → $count 个 skill${NC}"
echo -e "${GREEN}  - _design + _knowledge + _governance 已更新${NC}"
echo -e "${YELLOW}  - CLAUDE.md 未动（保留你的自定义）${NC}"
echo -e "${YELLOW}  - .claude/settings.json 未动${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo
echo "重新打开 Claude Code 即可使用最新 skill。"
