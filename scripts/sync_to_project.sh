#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Sync flutter-skills → 目标项目
# ────────────────────────────────────────────────────────────────────
#  用法: bash sync_to_project.sh <目标项目路径>
#  示例: bash sync_to_project.sh /Users/tg/Desktop/d/social_app
#
#  做的事:
#   1. 拷 hooks 到 {project}/_governance/hooks/
#   2. 拷 settings.template.json → {project}/.claude/settings.json
#      (已有的话 merge 不覆盖,保留用户自定义的 allow/deny)
#   3. 拷 CLAUDE.md 到 {project}/CLAUDE.md
#   4. 拷所有 SKILL.md 到 {project}/.claude/skills/{name}/
#   5. 拷 _knowledge / _design / _orchestration 等
#
#  不做的事: 不碰 lib/ docs/ test/ — 这些是用户业务代码
# ════════════════════════════════════════════════════════════════════

set -e

SRC="$(cd "$(dirname "$0")/.." && pwd)"
DST="${1:-}"

if [ -z "$DST" ] || [ ! -d "$DST" ]; then
  echo "❌ 用法: bash sync_to_project.sh <目标项目路径>"
  echo "   例: bash sync_to_project.sh /Users/tg/Desktop/d/social_app"
  exit 1
fi

DST=$(cd "$DST" && pwd)

echo "🔄 同步 flutter-skills → $DST"
echo "   源: $SRC"
echo ""

# ─── 1. hooks ────────────────────────────────────────
echo "▶ 同步 hooks..."
mkdir -p "$DST/_governance/hooks"
cp "$SRC/_governance/hooks/"*.sh "$DST/_governance/hooks/"
chmod +x "$DST/_governance/hooks/"*.sh
echo "   ✓ $(ls $DST/_governance/hooks/*.sh | wc -l | tr -d ' ') 个 hook"

# ─── 2. settings.json (merge 模式) ────────────────────
echo "▶ 同步 settings.json..."
mkdir -p "$DST/.claude"
if [ -f "$DST/.claude/settings.json" ]; then
  # 已存在,验证 JSON 合法 + 合并 hooks 段
  /opt/homebrew/bin/python3 <<PYEOF
import json
from pathlib import Path

src_path = Path('$SRC/_governance/settings.template.json')
dst_path = Path('$DST/.claude/settings.json')

src = json.loads(src_path.read_text())
try:
    dst = json.loads(dst_path.read_text())
except json.JSONDecodeError:
    print('   ⚠️  现有 settings.json 损坏,用模版覆盖')
    dst_path.write_text(src_path.read_text())
    exit()

# 合并策略:
# - hooks 全量用模版(最新配置)
# - permissions.allow 合并(保留用户自定义的)
# - permissions.deny 合并,但 curl 从 deny 移除
# - environment / model 保留用户的

dst['hooks'] = src['hooks']

dst.setdefault('permissions', {})
for field in ['allow', 'deny']:
    existing = set(dst['permissions'].get(field, []))
    from_template = set(src.get('permissions', {}).get(field, []))
    merged = sorted(existing | from_template)
    dst['permissions'][field] = merged

# curl 必须在 allow,不在 deny
deny = dst['permissions']['deny']
allow = dst['permissions']['allow']
if 'Bash(curl:*)' in deny:
    deny.remove('Bash(curl:*)')
if 'Bash(curl:*)' not in allow:
    allow.append('Bash(curl:*)')
dst['permissions']['deny'] = sorted(deny)
dst['permissions']['allow'] = sorted(allow)

# model 字段:如果是对象格式(老 bug)→ 修成字符串
if isinstance(dst.get('model'), dict):
    dst['model'] = dst['model'].get('default', 'sonnet')

dst_path.write_text(json.dumps(dst, indent=2, ensure_ascii=False))
print('   ✓ merged (保留你的自定义 permissions)')
PYEOF
else
  cp "$SRC/_governance/settings.template.json" "$DST/.claude/settings.json"
  echo "   ✓ 首次创建"
fi

# ─── 3. CLAUDE.md ────────────────────────────────────
echo "▶ 同步 CLAUDE.md..."
if [ -f "$DST/CLAUDE.md" ]; then
  # 已存在,备份用户自定义的,用新模版
  cp "$DST/CLAUDE.md" "$DST/CLAUDE.md.bak.$(date +%s)"
  cp "$SRC/flutter-init/template/CLAUDE.md" "$DST/CLAUDE.md"
  # 替换占位符为项目名
  project_name=$(basename "$DST")
  project_pascal=$(echo "$project_name" | sed -E 's/(^|_)([a-z])/\U\2/g')
  sed -i '' "s/{{PROJECT_NAME_PASCAL}}/$project_pascal/g" "$DST/CLAUDE.md"
  echo "   ✓ 更新 (旧版备份到 CLAUDE.md.bak.*)"
else
  cp "$SRC/flutter-init/template/CLAUDE.md" "$DST/CLAUDE.md"
  project_name=$(basename "$DST")
  project_pascal=$(echo "$project_name" | sed -E 's/(^|_)([a-z])/\U\2/g')
  sed -i '' "s/{{PROJECT_NAME_PASCAL}}/$project_pascal/g" "$DST/CLAUDE.md"
  echo "   ✓ 首次创建"
fi

# ─── 4. skills ───────────────────────────────────────
echo "▶ 同步 skills..."
mkdir -p "$DST/.claude/skills"
count=0
for skill_dir in "$SRC"/flutter-* "$SRC"/_orchestration/flutter-*; do
  if [ -f "$skill_dir/SKILL.md" ]; then
    name=$(basename "$skill_dir")
    mkdir -p "$DST/.claude/skills/$name"
    # 只拷 SKILL.md 和 README.md,不拷 template/ 等大目录
    cp "$skill_dir/SKILL.md" "$DST/.claude/skills/$name/SKILL.md"
    [ -f "$skill_dir/README.md" ] && cp "$skill_dir/README.md" "$DST/.claude/skills/$name/README.md"
    count=$((count+1))
  fi
done
echo "   ✓ $count 个 skill"

# ─── 5. _knowledge / _design / _governance 等共享文件 ──
echo "▶ 同步 _knowledge / _design..."
for dir in _knowledge _design _governance/checklists; do
  if [ -d "$SRC/$dir" ]; then
    mkdir -p "$DST/$dir"
    cp -r "$SRC/$dir/." "$DST/$dir/"
    echo "   ✓ $dir"
  fi
done

# ─── 6. 验证 ────────────────────────────────────────
echo ""
echo "🔍 验证:"
/opt/homebrew/bin/python3 -c "import json; json.load(open('$DST/.claude/settings.json'))" && echo "   ✓ settings.json 合法"
test -x "$DST/_governance/hooks/router.sh" && echo "   ✓ hooks 可执行"
test -f "$DST/CLAUDE.md" && echo "   ✓ CLAUDE.md 存在"
test -d "$DST/.claude/skills/flutter-flow-feature" && echo "   ✓ flutter-flow-feature skill 在"

echo ""
echo "✅ 同步完成"
echo ""
echo "下一步:"
echo "  1. 如在 Claude Code 会话中,输入 /exit 重开(让它读新 CLAUDE.md + skills)"
echo "  2. 开新会话测试: echo '做一个 X 模块 figma.com/...' 应看到 Router 强制指令"
