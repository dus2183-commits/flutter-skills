#!/usr/bin/env bash
# 启动开发环境 (默认 Mock 模式)
#
# 用法:
#   bash scripts/run.sh                    # mock 模式 + 自动选设备
#   bash scripts/run.sh -d chrome          # mock 模式 + chrome
#   bash scripts/run.sh --no-mock          # 真实接口
#   bash scripts/run.sh --no-mock -d ios   # 真实 + iOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# 检查 fvm 装好
if ! command -v fvm &> /dev/null; then
  echo "❌ fvm 未安装,先跑: bash scripts/setup.sh"
  exit 1
fi

if [ ! -d .fvm/flutter_sdk ]; then
  echo "❌ Flutter SDK 未配置,先跑: bash scripts/setup.sh"
  exit 1
fi

# 解析参数
MOCK_FLAG="--dart-define=USE_MOCK=true"
EXTRA_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --no-mock)
      MOCK_FLAG=""
      ;;
    *)
      EXTRA_ARGS+=("$arg")
      ;;
  esac
done

if [ -n "$MOCK_FLAG" ]; then
  echo "🚀 启动 (Mock 模式)"
else
  echo "🚀 启动 (真实接口模式)"
fi

fvm flutter run $MOCK_FLAG "${EXTRA_ARGS[@]}"
