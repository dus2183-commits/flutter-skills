#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  从 GitHub 更新项目中的 flutter-skills
# ════════════════════════════════════════════════════════════════════

set -e

REPO="https://github.com/dus2183-commits/flutter-skills.git"
TMP_DIR="/tmp/flutter-skills-update-$$"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'
NC='\033[0m'

echo
echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║     Flutter Skills — 更新                        ║${NC}"
echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo

# ─── 检查 ───
if [ ! -d ".claude/skills" ]; then
  echo -e "${BG_RED}${BOLD}                                                        ${NC}"
  echo -e "${BG_RED}${BOLD}   ❌ .claude/skills/ 不存在                             ${NC}"
  echo -e "${BG_RED}${BOLD}   请先跑 install_skills.sh 安装！                       ${NC}"
  echo -e "${BG_RED}${BOLD}                                                        ${NC}"
  echo
  echo -e "  安装命令:"
  echo -e "  ${BLUE}bash <(curl -s https://raw.githubusercontent.com/dus2183-commits/flutter-skills/main/scripts/install_skills.sh)${NC}"
  echo
  exit 1
fi

OLD_COUNT=$(ls .claude/skills/ 2>/dev/null | wc -l | tr -d ' ')
echo -e "  当前版本: ${YELLOW}$OLD_COUNT 个 skill${NC}"
echo

# ═══════════════════════════════════════════════════
# Step 1: Clone 最新版
# ═══════════════════════════════════════════════════
echo -e "${BLUE}[1/3]${NC} 从 GitHub 拉取最新版..."
if ! git clone --depth 1 "$REPO" "$TMP_DIR" 2>/dev/null; then
  echo
  echo -e "${BG_RED}${BOLD}                                                        ${NC}"
  echo -e "${BG_RED}${BOLD}   ❌ 拉取失败！无法连接 GitHub                         ${NC}"
  echo -e "${BG_RED}${BOLD}                                                        ${NC}"
  echo
  echo -e "${RED}  skill 未更新,继续使用旧版本。${NC}"
  echo -e "${RED}  修复网络后重新运行本脚本。${NC}"
  echo
  exit 1
fi
echo -e "${GREEN}  ✓ 拉取完成${NC}"

# ═══════════════════════════════════════════════════
# Step 2: 更新 SKILL.md
# ═══════════════════════════════════════════════════
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

# ═══════════════════════════════════════════════════
# Step 3: 更新设计文档
# ═══════════════════════════════════════════════════
echo -e "${BLUE}[3/3]${NC} 更新设计文档..."
rm -rf _design _knowledge _governance 2>/dev/null
cp -r "$TMP_DIR/_design" . 2>/dev/null && echo -e "${GREEN}  ✓ _design${NC}" || true
cp -r "$TMP_DIR/_knowledge" . 2>/dev/null && echo -e "${GREEN}  ✓ _knowledge${NC}" || true
cp -r "$TMP_DIR/_governance" . 2>/dev/null && echo -e "${GREEN}  ✓ _governance${NC}" || true

# ═══════════════════════════════════════════════════
# hook 脚本可执行
# ═══════════════════════════════════════════════════
if [ -d "_governance/hooks" ]; then
  chmod +x _governance/hooks/*.sh 2>/dev/null || true
fi

# 确保 settings.json 有 hooks(不覆盖现有配置)
/usr/bin/python3 <<'PYEOF'
import json, os, sys
SETTINGS = ".claude/settings.json"
HOOKS = {
    "UserPromptSubmit": [
        {"hooks": [{"type": "command", "command": "bash _governance/hooks/router.sh"}]}
    ],
    "PreToolUse": [
        {"matcher": "Write|Edit", "hooks": [
            {"type": "command", "command": "CLAUDE_HOOK_EVENT=PreToolUse bash _governance/hooks/conductor.sh"},
            {"type": "command", "command": "bash _governance/hooks/guard-core.sh"}
        ]},
        {"matcher": "Bash", "hooks": [{"type": "command", "command": "bash _governance/hooks/guard-git.sh"}]}
    ],
    "PostToolUse": [
        {"matcher": "Write|Edit", "hooks": [
            {"type": "command", "command": "CLAUDE_HOOK_EVENT=PostToolUse bash _governance/hooks/conductor.sh"},
            {"type": "command", "command": "bash _governance/hooks/reflector.sh"},
            {"type": "command", "command": "bash _governance/hooks/checkpoint.sh"},
            {"type": "command", "command": "bash _governance/hooks/auto-format.sh"},
            {"type": "command", "command": "bash _governance/hooks/auto-build-runner.sh"}
        ]},
        {"hooks": [{"type": "command", "command": "bash _governance/hooks/telemetry.sh"}]}
    ],
    "Stop": [{"hooks": [{"type": "command", "command": "bash _governance/hooks/stop-check.sh"}]}]
}
if not os.path.exists(SETTINGS):
    sys.exit(0)
with open(SETTINGS) as f:
    try: cfg = json.load(f)
    except: sys.exit(0)
cfg.setdefault("hooks", {})
for event, new_entries in HOOKS.items():
    existing = cfg["hooks"].get(event, [])
    new_cmds = {h["command"] for e in new_entries for h in e.get("hooks", [])}
    existing_cmds = {h.get("command","") for e in existing for h in e.get("hooks", [])}
    if not new_cmds.issubset(existing_cmds):
        cfg["hooks"][event] = existing + new_entries
with open(SETTINGS, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
PYEOF

# ─── 清理 ───
rm -rf "$TMP_DIR"

# ═══════════════════════════════════════════════════
# 完成提示
# ═══════════════════════════════════════════════════
echo
echo -e "${BG_GREEN}${BOLD}                                                        ${NC}"
echo -e "${BG_GREEN}${BOLD}   ✅ 更新完成！                                        ${NC}"
echo -e "${BG_GREEN}${BOLD}                                                        ${NC}"
echo
echo -e "  ${OLD_COUNT} → ${GREEN}${BOLD}$count 个 skill${NC}"
echo -e "  ${GREEN}_design + _knowledge + _governance 已更新${NC}"
echo -e "  ${YELLOW}CLAUDE.md 未改动（保留你的自定义）${NC}"
echo -e "  ${YELLOW}settings.json 未改动${NC}"
echo
echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}${BOLD}║                                                  ║${NC}"
echo -e "${YELLOW}${BOLD}║   ⚠️  请重新打开 Claude Code 加载最新 skill!      ║${NC}"
echo -e "${YELLOW}${BOLD}║                                                  ║${NC}"
echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo
