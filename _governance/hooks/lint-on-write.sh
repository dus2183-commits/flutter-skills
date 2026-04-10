#!/bin/bash
# lint-on-write.sh
# Hook: 写入或编辑 .dart 文件后自动跑 dart format
#
# 调用方式 (在 .claude/settings.json 中):
#   "PostToolUse": [
#     { "matcher": "Write|Edit", "command": "bash _governance/hooks/lint-on-write.sh \"$CLAUDE_TOOL_FILE_PATH\"" }
#   ]

set -e

FILE_PATH="$1"

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 只处理 .dart 文件
if [[ "$FILE_PATH" != *.dart ]]; then
  exit 0
fi

# 跳过 generated 文件
if [[ "$FILE_PATH" == *.g.dart ]] || [[ "$FILE_PATH" == *.freezed.dart ]]; then
  exit 0
fi

# 检查文件存在
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# 跑 dart format (静默)
if command -v dart &> /dev/null; then
  dart format "$FILE_PATH" > /dev/null 2>&1 || true
fi

exit 0
