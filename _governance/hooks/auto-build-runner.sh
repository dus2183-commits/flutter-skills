#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Auto Build Runner Hook — 写 .model.dart 后自动跑 build_runner
# ────────────────────────────────────────────────────────────────────
#  触发: PostToolUse (Write / Edit)
#  作用: freezed/json_serializable 文件改了自动生成 .freezed.dart
#  防抖: 用 lock 文件避免短时间内重复跑
# ════════════════════════════════════════════════════════════════════

INPUT=$(cat)
FILE=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

# 只关心 .model.dart 文件
if [[ ! "$FILE" =~ \.model\.dart$ ]]; then
  exit 0
fi

# 跳过生成的文件
case "$FILE" in
  *.freezed.dart|*.g.dart)
    exit 0
    ;;
esac

# 防抖: 10 秒内只跑一次(多个 model 同时写时合并一次 build)
LOCK_FILE=".flow_checkpoint/.build_runner.lock"
NOW=$(date +%s)

if [ -f "$LOCK_FILE" ]; then
  LAST=$(cat "$LOCK_FILE" 2>/dev/null || echo "0")
  DIFF=$((NOW - LAST))
  if [ "$DIFF" -lt 10 ]; then
    exit 0
  fi
fi

mkdir -p .flow_checkpoint
echo "$NOW" > "$LOCK_FILE"

# 后台跑 build_runner (不阻塞 Claude)
if command -v fvm &> /dev/null; then
  (fvm dart run build_runner build --delete-conflicting-outputs > .flow_checkpoint/build_runner.log 2>&1 &)
  echo "🔨 build_runner 后台运行中..." >&2
fi

exit 0
