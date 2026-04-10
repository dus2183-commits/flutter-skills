#!/bin/bash
# log_skill_call.sh
# Hook: 记录 skill 调用日志到 .telemetry/calls.jsonl
#
# 调用方式:
#   bash log_skill_call.sh <skill_name> <status> [extra_json]
#
# 示例:
#   bash log_skill_call.sh flutter-spec success
#   bash log_skill_call.sh flutter-api-gen failed '{"error":"missing context"}'

set -e

SKILL_NAME="$1"
STATUS="${2:-unknown}"
EXTRA="${3:-{}}"

if [ -z "$SKILL_NAME" ]; then
  echo "Usage: log_skill_call.sh <skill_name> <status> [extra_json]" >&2
  exit 1
fi

# 项目根目录 (假设当前目录或 PWD)
PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
TELEMETRY_DIR="${PROJECT_ROOT}/.telemetry"

# 确保目录存在
mkdir -p "$TELEMETRY_DIR"

# 时间戳 (ISO 8601, UTC)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 当前 git commit (如有)
GIT_COMMIT=""
if [ -d "${PROJECT_ROOT}/.git" ]; then
  GIT_COMMIT=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "")
fi

# 写入 jsonl
LOG_FILE="${TELEMETRY_DIR}/calls.jsonl"
cat >> "$LOG_FILE" <<EOF
{"timestamp":"$TIMESTAMP","skill":"$SKILL_NAME","status":"$STATUS","git_commit":"$GIT_COMMIT","extra":$EXTRA}
EOF

exit 0
