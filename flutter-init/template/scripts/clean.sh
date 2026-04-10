#!/usr/bin/env bash
# 清理构建产物 + pub cache
#
# 用法:
#   bash scripts/clean.sh           # 清 build/ + dart_tool
#   bash scripts/clean.sh --all     # 清所有 + .fvm

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

CLEAN_ALL=false
[ "$1" = "--all" ] && CLEAN_ALL=true

echo "🧹 清理 build/"
rm -rf build/

echo "🧹 清理 .dart_tool/"
rm -rf .dart_tool/

echo "🧹 清理 generated 文件"
find lib -name '*.g.dart' -delete 2>/dev/null || true
find lib -name '*.freezed.dart' -delete 2>/dev/null || true

if [ "$CLEAN_ALL" = "true" ]; then
  echo "🧹 清理 .fvm/flutter_sdk (软链接)"
  rm -f .fvm/flutter_sdk
  echo "🧹 清理 pubspec.lock"
  rm -f pubspec.lock
  echo
  echo "完全清理完成,需要重新跑: bash scripts/setup.sh"
else
  echo
  echo "清理完成。重新生成: fvm flutter pub get && fvm dart run build_runner build"
fi
