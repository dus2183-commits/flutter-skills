#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  替换 template 占位符
# ────────────────────────────────────────────────────────────────────
#  用途: flutter-init skill 复制 template 后,运行此脚本替换 {{...}}
#       占位符为真实值。
#
#  用法:
#    bash scripts/replace_placeholders.sh \
#      --project-name=my_app \
#      --project-name-pascal=MyApp \
#      --package-name=com.example.myapp \
#      --tab1=首页 \
#      --tab2=分类 \
#      --tab3=发现 \
#      --tab4=消息 \
#      --tab5=我的 \
#      --lead-name=渡 \
#      --created-date=2026-04-10
#
#  也支持环境变量:
#    PROJECT_NAME=my_app PROJECT_NAME_PASCAL=MyApp ... \
#      bash scripts/replace_placeholders.sh
# ════════════════════════════════════════════════════════════════════

set -e

# ─── 解析参数 ───
for arg in "$@"; do
  case "$arg" in
    --project-name=*) PROJECT_NAME="${arg#*=}" ;;
    --project-name-pascal=*) PROJECT_NAME_PASCAL="${arg#*=}" ;;
    --package-name=*) PACKAGE_NAME="${arg#*=}" ;;
    --tab1=*) TAB_1_NAME="${arg#*=}" ;;
    --tab2=*) TAB_2_NAME="${arg#*=}" ;;
    --tab3=*) TAB_3_NAME="${arg#*=}" ;;
    --tab4=*) TAB_4_NAME="${arg#*=}" ;;
    --tab5=*) TAB_5_NAME="${arg#*=}" ;;
    --lead-name=*) LEAD_NAME="${arg#*=}" ;;
    --created-date=*) CREATED_DATE="${arg#*=}" ;;
    *)
      echo "未知参数: $arg" >&2
      exit 1
      ;;
  esac
done

# ─── 默认值 ───
PROJECT_NAME="${PROJECT_NAME:-my_app}"
PROJECT_NAME_PASCAL="${PROJECT_NAME_PASCAL:-MyApp}"
PACKAGE_NAME="${PACKAGE_NAME:-com.example.myapp}"
TAB_1_NAME="${TAB_1_NAME:-首页}"
TAB_2_NAME="${TAB_2_NAME:-分类}"
TAB_3_NAME="${TAB_3_NAME:-发现}"
TAB_4_NAME="${TAB_4_NAME:-消息}"
TAB_5_NAME="${TAB_5_NAME:-我的}"
LEAD_NAME="${LEAD_NAME:-渡}"
CREATED_DATE="${CREATED_DATE:-$(date +%Y-%m-%d)}"

# ─── 切到项目根 ───
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔧 替换占位符${NC}"
echo "  PROJECT_NAME        = $PROJECT_NAME"
echo "  PROJECT_NAME_PASCAL = $PROJECT_NAME_PASCAL"
echo "  PACKAGE_NAME        = $PACKAGE_NAME"
echo "  TAB_1..5            = $TAB_1_NAME / $TAB_2_NAME / $TAB_3_NAME / $TAB_4_NAME / $TAB_5_NAME"
echo "  LEAD_NAME           = $LEAD_NAME"
echo "  CREATED_DATE        = $CREATED_DATE"
echo

# ─── 找出所有需要替换的文件 ───
FILES=$(find . -type f \( \
  -name "*.dart" -o \
  -name "*.yaml" -o \
  -name "*.md" -o \
  -name "*.json" \
  \) \
  -not -path './.fvm/*' \
  -not -path './.dart_tool/*' \
  -not -path './build/*' \
  -not -path './android/*' \
  -not -path './ios/*' \
  -not -path './macos/*' \
  -not -path './linux/*' \
  -not -path './windows/*' \
  -not -path './web/js/*')

# ─── 跨平台 sed (macOS 用 sed -i '',Linux 用 sed -i) ───
if [[ "$OSTYPE" == "darwin"* ]]; then
  SED_INPLACE=("sed" "-i" "")
else
  SED_INPLACE=("sed" "-i")
fi

# ─── 批量替换 ───
COUNT=0
for f in $FILES; do
  if grep -q '{{[A-Z0-9_]*}}' "$f" 2>/dev/null; then
    "${SED_INPLACE[@]}" \
      -e "s|{{PROJECT_NAME_PASCAL}}|$PROJECT_NAME_PASCAL|g" \
      -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
      -e "s|{{PACKAGE_NAME}}|$PACKAGE_NAME|g" \
      -e "s|{{TAB_1_NAME}}|$TAB_1_NAME|g" \
      -e "s|{{TAB_2_NAME}}|$TAB_2_NAME|g" \
      -e "s|{{TAB_3_NAME}}|$TAB_3_NAME|g" \
      -e "s|{{TAB_4_NAME}}|$TAB_4_NAME|g" \
      -e "s|{{TAB_5_NAME}}|$TAB_5_NAME|g" \
      -e "s|{{LEAD_NAME}}|$LEAD_NAME|g" \
      -e "s|{{CREATED_DATE}}|$CREATED_DATE|g" \
      "$f"
    COUNT=$((COUNT + 1))
  fi
done

echo -e "${GREEN}✓ 已替换 $COUNT 个文件${NC}"

# ─── 验证: 不该有遗留 ───
LEFTOVER=$(grep -rln '{{[A-Z0-9_]*}}' \
  --include="*.dart" --include="*.yaml" --include="*.md" --include="*.json" \
  --exclude-dir=.fvm --exclude-dir=build --exclude-dir=.dart_tool \
  --exclude-dir=android --exclude-dir=ios \
  . 2>/dev/null || true)

if [ -n "$LEFTOVER" ]; then
  echo -e "${YELLOW}⚠️  以下文件仍有占位符:${NC}"
  echo "$LEFTOVER"
  exit 1
fi

echo -e "${GREEN}✓ 所有占位符已替换完成${NC}"
