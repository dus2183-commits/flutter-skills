#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Auto Format Hook — Write/Edit dart 文件后自动 format
# ────────────────────────────────────────────────────────────────────
#  触发: PostToolUse (Write / Edit)
#  作用: 自动跑 dart format，保证代码格式统一
# ════════════════════════════════════════════════════════════════════

set -e

INPUT=$(cat)
FILE=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

# 只处理 dart 文件
if [[ ! "$FILE" =~ \.dart$ ]]; then
  exit 0
fi

# 跳过生成的文件
case "$FILE" in
  *.freezed.dart|*.g.dart|*.config.dart|*.gr.dart)
    exit 0
    ;;
esac

# 跑 format (静默)
if command -v fvm &> /dev/null; then
  fvm dart format "$FILE" > /dev/null 2>&1 || true
elif command -v dart &> /dev/null; then
  dart format "$FILE" > /dev/null 2>&1 || true
fi

exit 0
