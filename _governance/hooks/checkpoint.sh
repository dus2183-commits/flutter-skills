#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Checkpoint Hook — 记录每次 Write/Edit 到 .flow_checkpoint/
# ────────────────────────────────────────────────────────────────────
#  触发: PostToolUse (Write / Edit)
#  作用: 追加一条 transition 记录,失败可查
#
#  输入 (通过 stdin JSON):
#    { tool_name, tool_input: { file_path, ... }, tool_response }
# ════════════════════════════════════════════════════════════════════

set -e

# 读 stdin JSON
INPUT=$(cat)

# 提取字段
TOOL=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('tool_name',''))" 2>/dev/null || echo "unknown")
FILE=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

# 只关注代码/文档类文件
if [[ -z "$FILE" ]]; then
  exit 0
fi

# 只记录项目内的文件（忽略临时/缓存）
case "$FILE" in
  */.dart_tool/*|*/.fvm/*|*/build/*|*/.git/*|*/node_modules/*)
    exit 0
    ;;
esac

# 写 checkpoint
mkdir -p .flow_checkpoint
DATE=$(date +%Y-%m-%d-%H%M)
TS=$(date +%s)
FILENAME=$(basename "$FILE")
EXT="${FILENAME##*.}"

# 按日期分组
CHECKPOINT_FILE=".flow_checkpoint/transitions-${DATE:0:10}.jsonl"

echo "{\"ts\":$TS,\"tool\":\"$TOOL\",\"file\":\"$FILE\",\"ext\":\"$EXT\"}" >> "$CHECKPOINT_FILE"

exit 0
