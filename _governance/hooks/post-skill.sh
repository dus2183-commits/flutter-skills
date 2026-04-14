#!/bin/bash
# post-skill.sh
# Hook: 会话结束时(Stop)运行,做项目级 cleanup 和 telemetry
#
# 调用方式:
#   "Stop": [{ "command": "bash _governance/hooks/post-skill.sh" }]

set -e

PROJECT_ROOT="${PWD}"
TELEMETRY_DIR="${PROJECT_ROOT}/.telemetry"

# 1. 确保 telemetry 目录存在
mkdir -p "$TELEMETRY_DIR"

# 2. 跑一次 flutter analyze (静默,只记录 error 数到 telemetry)
if command -v flutter &> /dev/null; then
  ERROR_COUNT=$(flutter analyze 2>&1 | grep -c "error" || true)
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "{\"timestamp\":\"$TIMESTAMP\",\"event\":\"session_end\",\"analyze_errors\":$ERROR_COUNT}" >> "${TELEMETRY_DIR}/sessions.jsonl"
fi

# 3. 检查是否有未 commit 的改动 (提醒,不阻断)
if [ -d .git ]; then
  CHANGED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$CHANGED" -gt 0 ]; then
    echo "📝 提示: 当前有 $CHANGED 个文件未 commit"
  fi
fi

exit 0
