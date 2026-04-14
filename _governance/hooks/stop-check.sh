#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Stop Check Hook — Claude 结束前跑 analyze + 输出报告
# ────────────────────────────────────────────────────────────────────
#  触发: Stop (Claude 会话结束前)
#  作用: 跑 flutter analyze，如果有 error 提示用户
# ════════════════════════════════════════════════════════════════════

# 只在项目目录执行
if [ ! -f "pubspec.yaml" ]; then
  exit 0
fi

# 跑 analyze
if ! command -v fvm &> /dev/null; then
  exit 0
fi

# 静默跑，只在有 error 时输出
OUTPUT=$(fvm flutter analyze --no-pub 2>&1 || true)
ERROR_COUNT=$(echo "$OUTPUT" | grep -c "error •" || true)
WARNING_COUNT=$(echo "$OUTPUT" | grep -c "warning •" || true)

# 写报告
mkdir -p .flow_checkpoint
DATE=$(date +%Y-%m-%d-%H%M)
REPORT=".flow_checkpoint/stop-check-${DATE}.txt"
echo "$OUTPUT" > "$REPORT"

# 如果有 error，提示
if [ "$ERROR_COUNT" -gt 0 ]; then
  echo "⚠️  flutter analyze 发现 $ERROR_COUNT 个 error (warnings: $WARNING_COUNT)"
  echo "   详情: $REPORT"
  echo "$OUTPUT" | grep "error •" | head -5
fi

exit 0
