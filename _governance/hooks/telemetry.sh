#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Telemetry Hook — 记录所有工具调用
# ────────────────────────────────────────────────────────────────────
#  触发: PostToolUse (任意工具)
#  作用: 记录到 .telemetry/tool_calls.jsonl 供后续分析
# ════════════════════════════════════════════════════════════════════

INPUT=$(cat)

# 提取信息
TOOL=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('tool_name','unknown'))" 2>/dev/null || echo "unknown")

mkdir -p .telemetry
TS=$(date +%s)
DATE=$(date +%Y-%m-%d)

# 按日期分组,每天一个文件
LOG_FILE=".telemetry/tool-calls-${DATE}.jsonl"

# 只记录简要信息(避免大数据量)
echo "{\"ts\":$TS,\"tool\":\"$TOOL\"}" >> "$LOG_FILE"

exit 0
