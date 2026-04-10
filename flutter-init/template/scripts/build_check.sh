#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  编译验证脚本 (分级模式)
# ────────────────────────────────────────────────────────────────────
#  用法:
#    bash scripts/build_check.sh             # 默认 fast: analyze + web (~20s)
#    bash scripts/build_check.sh quick       # 只 analyze (~3s)
#    bash scripts/build_check.sh fast        # analyze + web (~20s)
#    bash scripts/build_check.sh full        # 三端全跑 (~2-5min)
#    bash scripts/build_check.sh android     # 单平台
#    bash scripts/build_check.sh ios         # 单平台
#    bash scripts/build_check.sh web         # 单平台 (~15s)
#
#  耗时参考 (M1 MacBook):
#    quick:    3 秒
#    fast:    20 秒  ← 默认,适合开发时频繁跑
#    web:     15 秒
#    android: 30-60 秒 (首次更慢)
#    ios:     60+ 秒 (要 codesign)
#    full:    2-5 分钟  ← 只在 PR 合并 / 发版前跑
#
#  CI 推荐:
#    PR check:  fast      (快速反馈)
#    Pre-merge: full      (完整验证)
#    Pre-release: full + 真机测
# ════════════════════════════════════════════════════════════════════

set -e
set -o pipefail   # ★ 关键: 让 pipe 中任一命令失败,整个 pipe 失败
                  # 否则 `flutter build | tail` 即使 build 失败也会 exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

if [ ! -d .fvm/flutter_sdk ]; then
  echo "❌ Flutter SDK 未配置,先跑: bash scripts/setup.sh"
  exit 1
fi

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NC='\033[0m'

# ─── 解析参数 ───
TARGET="${1:-fast}"
RUN_ANALYZE=true
RUN_WEB=false
RUN_ANDROID=false
RUN_IOS=false

case "$TARGET" in
  quick)
    # 只 analyze
    ;;
  fast)
    RUN_WEB=true
    ;;
  full|all)
    RUN_WEB=true
    RUN_ANDROID=true
    RUN_IOS=true
    ;;
  web)
    RUN_WEB=true
    ;;
  android)
    RUN_ANDROID=true
    ;;
  ios)
    RUN_IOS=true
    ;;
  *)
    echo -e "${RED}❌ 未知模式: $TARGET${NC}"
    echo "用法: bash scripts/build_check.sh [quick|fast|full|web|android|ios]"
    exit 1
    ;;
esac

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Build Check - 模式: $TARGET${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo

FAILED=()
START_TIME=$(date +%s)

# ═══════════════════════════════════════════════
# Step 1: analyze (必跑,~3s)
# ═══════════════════════════════════════════════
if [ "$RUN_ANALYZE" = true ]; then
  echo -e "${BLUE}[1] flutter analyze${NC} ${GRAY}(~3s)${NC}"
  ANALYZE_START=$(date +%s)
  if ! fvm flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings 2>&1 | tail -2; then
    echo -e "${RED}❌ analyze 有 ERROR${NC}"
    exit 1
  fi
  ANALYZE_DURATION=$(($(date +%s) - ANALYZE_START))
  echo -e "${GREEN}✓ analyze 通过${NC} ${GRAY}(${ANALYZE_DURATION}s)${NC}"
  echo
fi

# ═══════════════════════════════════════════════
# Step 2: web (~15s)
# ═══════════════════════════════════════════════
if [ "$RUN_WEB" = true ]; then
  echo -e "${BLUE}[2] flutter build web${NC} ${GRAY}(~15s, 首次 ~50s)${NC}"
  WEB_START=$(date +%s)
  if fvm flutter build web --no-source-maps 2>&1 | tail -3; then
    WEB_DURATION=$(($(date +%s) - WEB_START))
    echo -e "${GREEN}✓ Web 通过${NC} ${GRAY}(${WEB_DURATION}s)${NC}"
  else
    echo -e "${RED}✗ Web 失败${NC}"
    FAILED+=("web")
  fi
  echo
fi

# ═══════════════════════════════════════════════
# Step 3: android (~30-60s)
# ═══════════════════════════════════════════════
if [ "$RUN_ANDROID" = true ]; then
  echo -e "${BLUE}[3] flutter build apk --debug${NC} ${GRAY}(~30-60s)${NC}"
  if [ ! -d "android" ]; then
    echo -e "${YELLOW}⊘ android/ 目录不存在,跳过${NC}"
  else
    ANDROID_START=$(date +%s)
    if fvm flutter build apk --debug --target-platform=android-arm64 2>&1 | tail -5; then
      ANDROID_DURATION=$(($(date +%s) - ANDROID_START))
      echo -e "${GREEN}✓ Android 通过${NC} ${GRAY}(${ANDROID_DURATION}s)${NC}"
    else
      echo -e "${RED}✗ Android 失败${NC}"
      FAILED+=("android")
    fi
  fi
  echo
fi

# ═══════════════════════════════════════════════
# Step 4: iOS (~60+s, 仅 macOS)
# ═══════════════════════════════════════════════
if [ "$RUN_IOS" = true ]; then
  echo -e "${BLUE}[4] flutter build ios --no-codesign${NC} ${GRAY}(~60s+)${NC}"
  if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${YELLOW}⊘ iOS 跳过 (非 macOS)${NC}"
  elif [ ! -d "ios" ]; then
    echo -e "${YELLOW}⊘ ios/ 目录不存在,跳过${NC}"
  else
    IOS_START=$(date +%s)
    if fvm flutter build ios --no-codesign --debug 2>&1 | tail -5; then
      IOS_DURATION=$(($(date +%s) - IOS_START))
      echo -e "${GREEN}✓ iOS 通过${NC} ${GRAY}(${IOS_DURATION}s)${NC}"
    else
      echo -e "${RED}✗ iOS 失败${NC}"
      FAILED+=("ios")
    fi
  fi
  echo
fi

# ═══════════════════════════════════════════════
# 总结
# ═══════════════════════════════════════════════
TOTAL_DURATION=$(($(date +%s) - START_TIME))
echo -e "${BLUE}════════════════════════════════════════════${NC}"
if [ ${#FAILED[@]} -eq 0 ]; then
  echo -e "${GREEN}✅ 全部通过${NC} ${GRAY}(总耗时 ${TOTAL_DURATION}s)${NC}"
  exit 0
else
  echo -e "${RED}❌ 失败平台: ${FAILED[*]}${NC} ${GRAY}(总耗时 ${TOTAL_DURATION}s)${NC}"
  exit 1
fi
