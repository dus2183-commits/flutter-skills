#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  从 GitHub 安装 flutter-skills 到当前项目
# ════════════════════════════════════════════════════════════════════

set -e

REPO="https://github.com/dus2183-commits/flutter-skills.git"
TMP_DIR="/tmp/flutter-skills-install-$$"

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
echo -e "${BLUE}${BOLD}║     Flutter Skills — 安装到项目                  ║${NC}"
echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo

# ═══════════════════════════════════════════════════
# Step 1: Clone
# ═══════════════════════════════════════════════════
echo -e "${BLUE}[1/5]${NC} 从 GitHub 克隆仓库..."
if ! git clone --depth 1 "$REPO" "$TMP_DIR" 2>/dev/null; then
  echo
  echo -e "${BG_RED}${BOLD}                                                        ${NC}"
  echo -e "${BG_RED}${BOLD}   ❌ 克隆失败！无法连接 GitHub                         ${NC}"
  echo -e "${BG_RED}${BOLD}                                                        ${NC}"
  echo
  echo -e "${RED}  可能原因:${NC}"
  echo -e "${RED}  1. 网络不通 — 检查代理/VPN${NC}"
  echo -e "${RED}  2. 仓库地址错误 — $REPO${NC}"
  echo -e "${RED}  3. 没有访问权限 — 检查 SSH key 或 token${NC}"
  echo
  echo -e "${RED}${BOLD}  ⛔ 安装中止。skill 未安装,项目无法正常使用 flutter-skills 工作流。${NC}"
  echo -e "${RED}  修复网络后重新运行本脚本。${NC}"
  echo
  exit 1
fi
echo -e "${GREEN}  ✓ 克隆完成${NC}"

# ═══════════════════════════════════════════════════
# Step 2: 复制 SKILL.md
# ═══════════════════════════════════════════════════
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

if [ "$count" -lt 10 ]; then
  echo -e "${BG_RED}${BOLD}  ❌ 只安装了 $count 个 skill,数量异常！仓库可能不完整。${NC}"
  rm -rf "$TMP_DIR"
  exit 1
fi
echo -e "${GREEN}  ✓ $count 个 skill 已安装${NC}"

# ═══════════════════════════════════════════════════
# Step 3: 复制 _design / _knowledge / _governance
# ═══════════════════════════════════════════════════
echo -e "${BLUE}[3/5]${NC} 复制设计文档..."
cp -r "$TMP_DIR/_design" . 2>/dev/null && echo -e "${GREEN}  ✓ _design${NC}" || echo -e "${YELLOW}  ⚠ _design 复制失败${NC}"
cp -r "$TMP_DIR/_knowledge" . 2>/dev/null && echo -e "${GREEN}  ✓ _knowledge${NC}" || echo -e "${YELLOW}  ⚠ _knowledge 复制失败${NC}"
cp -r "$TMP_DIR/_governance" . 2>/dev/null && echo -e "${GREEN}  ✓ _governance${NC}" || echo -e "${YELLOW}  ⚠ _governance 复制失败${NC}"

# ═══════════════════════════════════════════════════
# Step 4: CLAUDE.md
# ═══════════════════════════════════════════════════
echo -e "${BLUE}[4/5]${NC} 检查 CLAUDE.md..."
if [ ! -f "CLAUDE.md" ]; then
  cp "$TMP_DIR/flutter-init/template/_claude_templates/CLAUDE_full.md" CLAUDE.md 2>/dev/null
  echo -e "${GREEN}  ✓ CLAUDE_full.md → CLAUDE.md${NC}"
elif ! grep -q "最高优先级规则" CLAUDE.md 2>/dev/null; then
  echo -e "${YELLOW}  ⚠ CLAUDE.md 已存在但缺少流水线铁律${NC}"
  echo -e "${YELLOW}    建议手动合并: cp $TMP_DIR/flutter-init/template/_claude_templates/CLAUDE_full.md ./CLAUDE.md${NC}"
else
  echo -e "  ⏭ CLAUDE.md 已存在且含铁律,跳过"
fi

# ═══════════════════════════════════════════════════
# Step 4.5: 合并 hooks 到 settings.json
# ═══════════════════════════════════════════════════
echo -e "${BLUE}[4.5/5]${NC} 配置 hooks..."
if [ -d "_governance/hooks" ]; then
  chmod +x _governance/hooks/*.sh 2>/dev/null || true
fi

mkdir -p .claude

/usr/bin/python3 <<'PYEOF'
import json
import os
import sys

SETTINGS = ".claude/settings.json"

HOOKS_TO_ADD = {
    "UserPromptSubmit": [
        {"hooks": [{"type": "command", "command": "bash _governance/hooks/router.sh"}]}
    ],
    "PreToolUse": [
        {
            "matcher": "Write|Edit",
            "hooks": [
                {"type": "command", "command": "CLAUDE_HOOK_EVENT=PreToolUse bash _governance/hooks/conductor.sh"},
                {"type": "command", "command": "bash _governance/hooks/guard-core.sh"}
            ]
        },
        {
            "matcher": "Bash",
            "hooks": [
                {"type": "command", "command": "bash _governance/hooks/guard-git.sh"}
            ]
        }
    ],
    "PostToolUse": [
        {
            "matcher": "Write|Edit",
            "hooks": [
                {"type": "command", "command": "CLAUDE_HOOK_EVENT=PostToolUse bash _governance/hooks/conductor.sh"},
                {"type": "command", "command": "bash _governance/hooks/reflector.sh"},
                {"type": "command", "command": "bash _governance/hooks/checkpoint.sh"},
                {"type": "command", "command": "bash _governance/hooks/auto-format.sh"},
                {"type": "command", "command": "bash _governance/hooks/auto-build-runner.sh"}
            ]
        },
        {
            "hooks": [
                {"type": "command", "command": "bash _governance/hooks/telemetry.sh"}
            ]
        }
    ],
    "Stop": [
        {"hooks": [
            {"type": "command", "command": "bash _governance/hooks/conductor-stop.sh"},
            {"type": "command", "command": "bash _governance/hooks/memory.sh"},
            {"type": "command", "command": "bash _governance/hooks/stop-check.sh"}
        ]}
    ]
}

# 读现有 settings.json(如存在)
if os.path.exists(SETTINGS):
    with open(SETTINGS) as f:
        try:
            cfg = json.load(f)
        except json.JSONDecodeError:
            print("  ⚠ settings.json 格式错误,跳过 hook 合并")
            sys.exit(0)
else:
    cfg = {}

# 合并 hooks(保留已有的其他 hook)
cfg.setdefault("hooks", {})

for event, new_entries in HOOKS_TO_ADD.items():
    existing = cfg["hooks"].get(event, [])

    # 检查是否已经装过我们的 hook(靠命令字符串去重)
    new_cmds = set()
    for entry in new_entries:
        for h in entry.get("hooks", []):
            new_cmds.add(h["command"])

    existing_cmds = set()
    for entry in existing:
        for h in entry.get("hooks", []):
            existing_cmds.add(h.get("command", ""))

    # 如果已经有这些命令,跳过
    if new_cmds.issubset(existing_cmds):
        continue

    # 追加(不覆盖)
    cfg["hooks"][event] = existing + new_entries

# 写回
with open(SETTINGS, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print("  ✓ hooks 已合并到 .claude/settings.json")
PYEOF

# ═══════════════════════════════════════════════════
# Step 5: 全局 flutter-init
# ═══════════════════════════════════════════════════
echo -e "${BLUE}[5/5]${NC} 检查全局 flutter-init..."
GLOBAL_SKILLS="$HOME/.claude/skills"
mkdir -p "$GLOBAL_SKILLS"
for name in flutter-init flutter-flow-init; do
  if [ ! -e "$GLOBAL_SKILLS/$name" ]; then
    src_dir="$TMP_DIR/$name"
    [ "$name" = "flutter-flow-init" ] && src_dir="$TMP_DIR/_orchestration/$name"
    if [ -f "$src_dir/SKILL.md" ]; then
      mkdir -p "$GLOBAL_SKILLS/$name"
      cp "$src_dir/SKILL.md" "$GLOBAL_SKILLS/$name/"
      echo -e "${GREEN}  ✓ $name → 全局${NC}"
    fi
  else
    echo -e "  ⏭ $name 已存在"
  fi
done

# ═══════════════════════════════════════════════════
# 清理
# ═══════════════════════════════════════════════════
rm -rf "$TMP_DIR"

# ═══════════════════════════════════════════════════
# 完成提示 — 大字醒目
# ═══════════════════════════════════════════════════
echo
echo
echo -e "${BG_GREEN}${BOLD}                                                        ${NC}"
echo -e "${BG_GREEN}${BOLD}   ✅ 安装完成！                                        ${NC}"
echo -e "${BG_GREEN}${BOLD}                                                        ${NC}"
echo
echo -e "  ${GREEN}${BOLD}$count 个 skill${NC} 已安装到 .claude/skills/"
echo -e "  ${GREEN}${BOLD}_design + _knowledge + _governance${NC} 已复制"
echo -e "  ${GREEN}${BOLD}CLAUDE.md${NC} 已就绪"
echo
echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}${BOLD}║                                                  ║${NC}"
echo -e "${YELLOW}${BOLD}║   ⚠️  请关闭当前 Claude Code 窗口,               ║${NC}"
echo -e "${YELLOW}${BOLD}║      重新在本项目目录下打开 Claude Code!          ║${NC}"
echo -e "${YELLOW}${BOLD}║                                                  ║${NC}"
echo -e "${YELLOW}${BOLD}║   cd $(pwd)${NC}"
echo -e "${YELLOW}${BOLD}║   claude                                         ║${NC}"
echo -e "${YELLOW}${BOLD}║                                                  ║${NC}"
echo -e "${YELLOW}${BOLD}║   然后说: \"做一个 XX 模块\"                       ║${NC}"
echo -e "${YELLOW}${BOLD}║                                                  ║${NC}"
echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo

# 主动退出当前 Claude Code 会话
echo -e "${BLUE}3 秒后自动退出...${NC}"
sleep 3
exit 0
