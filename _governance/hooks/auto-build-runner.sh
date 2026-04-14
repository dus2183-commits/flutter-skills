#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Auto Build Runner Hook — 写任何含 @freezed/@JsonSerializable 的文件后自动跑
# ────────────────────────────────────────────────────────────────────
#  触发: PostToolUse (Write / Edit)
#
#  策略:
#    - 文件名是 *.model.dart → 必跑
#    - 文件内容含 @freezed 或 @JsonSerializable → 必跑（就算命名不规范）
#    - 防抖 10 秒,多个文件同时写合并一次 build
# ════════════════════════════════════════════════════════════════════

INPUT=$(cat)
FILE=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

if [[ -z "$FILE" ]] || [[ ! -f "$FILE" ]]; then
  exit 0
fi

# 跳过生成的文件
case "$FILE" in
  *.freezed.dart|*.g.dart|*.config.dart)
    exit 0
    ;;
esac

# 只关心 dart 文件
[[ ! "$FILE" =~ \.dart$ ]] && exit 0

# 判断: 命名含 .model.dart 或 内容含 @freezed / @JsonSerializable
should_build=false
if [[ "$FILE" =~ \.model\.dart$ ]]; then
  should_build=true
elif grep -qE "@freezed|@JsonSerializable" "$FILE" 2>/dev/null; then
  should_build=true
  # 对不规范命名提示一下
  echo "⚠️  auto-build-runner: $FILE 含 @freezed 但未按 *.model.dart 命名规范" >&2
fi

[ "$should_build" = "false" ] && exit 0

# 防抖
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

# 后台跑 build_runner
if command -v fvm &> /dev/null; then
  (fvm dart run build_runner build --delete-conflicting-outputs > .flow_checkpoint/build_runner.log 2>&1 &)
  echo "🔨 build_runner 后台运行中（包含 $FILE）..." >&2
fi

exit 0
