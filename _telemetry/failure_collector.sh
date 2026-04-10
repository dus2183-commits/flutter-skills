#!/bin/bash
# failure_collector.sh
# 失败时收集错误信息写到 docs/_failures/{date}.md
#
# 调用方式:
#   bash failure_collector.sh <skill_name> <error_message> [stack_trace]

set -e

SKILL_NAME="$1"
ERROR_MSG="$2"
STACK="${3:-(no stack)}"

if [ -z "$SKILL_NAME" ] || [ -z "$ERROR_MSG" ]; then
  echo "Usage: failure_collector.sh <skill_name> <error_message> [stack_trace]" >&2
  exit 1
fi

PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
FAILURES_DIR="${PROJECT_ROOT}/docs/_failures"
mkdir -p "$FAILURES_DIR"

DATE=$(date -u +%Y-%m-%d)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
FAILURE_FILE="${FAILURES_DIR}/${DATE}.md"

# 如果是新文件,写 header
if [ ! -f "$FAILURE_FILE" ]; then
  cat > "$FAILURE_FILE" <<EOF
---
artifact_type: failure_log
date: $DATE
---

# 失败日志 - $DATE

EOF
fi

# 追加失败条目
cat >> "$FAILURE_FILE" <<EOF

---

## $TIMESTAMP - $SKILL_NAME

**错误:**
\`\`\`
$ERROR_MSG
\`\`\`

**堆栈:**
\`\`\`
$STACK
\`\`\`

**项目状态:**
- git commit: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
- branch: $(git branch --show-current 2>/dev/null || echo "unknown")

EOF

# 同时写到 telemetry
TELEMETRY_DIR="${PROJECT_ROOT}/.telemetry"
mkdir -p "$TELEMETRY_DIR"
echo "{\"timestamp\":\"$TIMESTAMP\",\"skill\":\"$SKILL_NAME\",\"error\":\"$ERROR_MSG\"}" >> "${TELEMETRY_DIR}/failures.jsonl"

exit 0
