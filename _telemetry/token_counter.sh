#!/bin/bash
# token_counter.sh
# 记录 token 用量到 .telemetry/tokens.jsonl
#
# 调用方式:
#   bash token_counter.sh <skill_name> <input_tokens> <output_tokens> <model>
#
# 示例:
#   bash token_counter.sh flutter-spec 1500 800 opus

set -e

SKILL_NAME="$1"
INPUT_TOKENS="${2:-0}"
OUTPUT_TOKENS="${3:-0}"
MODEL="${4:-unknown}"

if [ -z "$SKILL_NAME" ]; then
  echo "Usage: token_counter.sh <skill_name> <input_tokens> <output_tokens> <model>" >&2
  exit 1
fi

PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
TELEMETRY_DIR="${PROJECT_ROOT}/.telemetry"
mkdir -p "$TELEMETRY_DIR"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS))

# 简单成本估算 (USD per 1M tokens, 2026 价格)
case "$MODEL" in
  opus)
    INPUT_COST=$(awk "BEGIN {printf \"%.6f\", $INPUT_TOKENS * 15 / 1000000}")
    OUTPUT_COST=$(awk "BEGIN {printf \"%.6f\", $OUTPUT_TOKENS * 75 / 1000000}")
    ;;
  sonnet)
    INPUT_COST=$(awk "BEGIN {printf \"%.6f\", $INPUT_TOKENS * 3 / 1000000}")
    OUTPUT_COST=$(awk "BEGIN {printf \"%.6f\", $OUTPUT_TOKENS * 15 / 1000000}")
    ;;
  haiku)
    INPUT_COST=$(awk "BEGIN {printf \"%.6f\", $INPUT_TOKENS * 1 / 1000000}")
    OUTPUT_COST=$(awk "BEGIN {printf \"%.6f\", $OUTPUT_TOKENS * 5 / 1000000}")
    ;;
  *)
    INPUT_COST=0
    OUTPUT_COST=0
    ;;
esac

TOTAL_COST=$(awk "BEGIN {printf \"%.6f\", $INPUT_COST + $OUTPUT_COST}")

LOG_FILE="${TELEMETRY_DIR}/tokens.jsonl"
cat >> "$LOG_FILE" <<EOF
{"timestamp":"$TIMESTAMP","skill":"$SKILL_NAME","model":"$MODEL","input_tokens":$INPUT_TOKENS,"output_tokens":$OUTPUT_TOKENS,"total_tokens":$TOTAL_TOKENS,"cost_usd":$TOTAL_COST}
EOF

exit 0
