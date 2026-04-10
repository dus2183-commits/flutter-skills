#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Flutter Skills - 一键 setup 脚本
# ────────────────────────────────────────────────────────────────────
#  作用:
#    1. 装 fvm (如未装)
#    2. 下载并锁定 Flutter 3.27.2 到 .fvm/flutter_sdk
#    3. flutter pub get
#    4. dart run build_runner build (如有 freezed)
#    5. 提示后续步骤
#
#  用法:
#    bash scripts/setup.sh
#
#  之后启动:
#    fvm flutter run --dart-define=USE_MOCK=true   (mock 模式)
#    fvm flutter run                                (真实接口)
#
#  支持系统: macOS / Linux / WSL
# ════════════════════════════════════════════════════════════════════

set -e

# ─── 配置 ───
FLUTTER_VERSION="3.27.2"

# ─── 国内镜像加速 (Flutter / Pub) ───
# 如果你在中国大陆,这两个 mirror 让首次下载快 5-10 倍
# 国外用户可以注释掉这两行
export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}"

# ─── 颜色 ───
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 切到项目根
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Flutter Skills Setup                              ║${NC}"
echo -e "${BLUE}║   Flutter Version: ${FLUTTER_VERSION}                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo

# ════════════════════════════════════════════════════════════════════
# Step 1: 检查并安装 fvm
# ════════════════════════════════════════════════════════════════════
echo -e "${BLUE}[1/5]${NC} 检查 fvm..."

# 函数: 真实运行 fvm 检查健康度
# 返回: 0=健康, 1=未装, 2=装了但坏了
check_fvm_health() {
  if ! command -v fvm > /dev/null 2>&1; then
    return 1
  fi
  local output
  output=$(fvm --version 2>&1)
  if echo "$output" | grep -qiE "(can't load kernel|invalid kernel|exception|^err :)"; then
    return 2
  fi
  return 0
}

set +e
check_fvm_health
fvm_status=$?
set -e

if [ $fvm_status -eq 1 ]; then
  echo -e "${YELLOW}  fvm 未安装,正在安装...${NC}"
  if command -v brew &> /dev/null; then
    brew tap leoafarias/fvm 2>/dev/null || true
    brew install fvm
  elif command -v dart &> /dev/null; then
    dart pub global activate fvm
  else
    echo -e "${RED}  ❌ 错误: 需要 brew 或 dart 才能安装 fvm${NC}"
    echo "  手动安装: brew tap leoafarias/fvm && brew install fvm"
    exit 1
  fi
elif [ $fvm_status -eq 2 ]; then
  echo -e "${RED}  ❌ fvm 已安装但坏了 (与当前 Dart 版本不兼容)${NC}"
  echo
  echo "  错误信息:"
  fvm --version 2>&1 | head -3 | sed 's/^/    /'
  echo
  echo -e "  ${YELLOW}修复方法 (推荐用 brew 重装):${NC}"
  echo "    brew uninstall fvm 2>/dev/null"
  echo "    dart pub global deactivate fvm 2>/dev/null"
  echo "    brew tap leoafarias/fvm"
  echo "    brew install fvm"
  echo
  echo "  或者重装 dart pub 版:"
  echo "    dart pub global deactivate fvm"
  echo "    dart pub global activate fvm"
  echo
  echo "  修复后重新跑: bash scripts/setup.sh"
  exit 1
fi

# 二次检查
set +e
check_fvm_health
recheck=$?
set -e
if [ $recheck -ne 0 ]; then
  echo -e "${RED}  ❌ fvm 安装后仍然不可用${NC}"
  exit 1
fi

FVM_VERSION=$(fvm --version 2>&1 | head -1)
echo -e "${GREEN}  ✓ fvm 已就绪 (${FVM_VERSION})${NC}"
echo

# ════════════════════════════════════════════════════════════════════
# Step 2: 检查 .fvmrc
# ════════════════════════════════════════════════════════════════════
echo -e "${BLUE}[2/5]${NC} 检查 .fvmrc..."

if [ ! -f .fvmrc ]; then
  echo -e "${RED}  ❌ .fvmrc 不存在${NC}"
  echo "  请确认你在项目根目录跑这个脚本"
  exit 1
fi

PINNED_VERSION=$(grep -oE '"flutter":\s*"[^"]+"' .fvmrc | sed 's/.*"\([^"]*\)"$/\1/')
if [ "$PINNED_VERSION" != "$FLUTTER_VERSION" ]; then
  echo -e "${YELLOW}  ⚠️  .fvmrc 锁定 $PINNED_VERSION,脚本想用 $FLUTTER_VERSION${NC}"
  echo "  以 .fvmrc 为准: $PINNED_VERSION"
  FLUTTER_VERSION="$PINNED_VERSION"
fi
echo -e "${GREEN}  ✓ .fvmrc OK (Flutter $FLUTTER_VERSION)${NC}"
echo

# ════════════════════════════════════════════════════════════════════
# Step 3: 安装并切换到指定 Flutter 版本
# ════════════════════════════════════════════════════════════════════
echo -e "${BLUE}[3/5]${NC} 安装 Flutter $FLUTTER_VERSION (首次需要 5-10 分钟)..."

# 检查是否已安装
if fvm list 2>&1 | grep -q "$FLUTTER_VERSION"; then
  echo -e "${GREEN}  ✓ Flutter $FLUTTER_VERSION 已安装${NC}"
else
  fvm install "$FLUTTER_VERSION"
fi

# 切换到该版本(创建 .fvm/flutter_sdk 软链接)
echo "  → fvm use $FLUTTER_VERSION"
fvm use "$FLUTTER_VERSION" --force

if [ ! -L .fvm/flutter_sdk ] && [ ! -d .fvm/flutter_sdk ]; then
  echo -e "${RED}  ❌ .fvm/flutter_sdk 创建失败${NC}"
  exit 1
fi
echo -e "${GREEN}  ✓ Flutter SDK 链接到 .fvm/flutter_sdk${NC}"
echo

# ════════════════════════════════════════════════════════════════════
# Step 4: pub get
# ════════════════════════════════════════════════════════════════════
echo -e "${BLUE}[4/5]${NC} flutter pub get..."
fvm flutter pub get
echo -e "${GREEN}  ✓ 依赖装好${NC}"
echo

# ════════════════════════════════════════════════════════════════════
# Step 5: build_runner (如有 freezed)
# ════════════════════════════════════════════════════════════════════
echo -e "${BLUE}[5/5]${NC} build_runner..."

if grep -q "freezed:" pubspec.yaml 2>/dev/null || grep -q "json_serializable:" pubspec.yaml 2>/dev/null; then
  echo "  → dart run build_runner build --delete-conflicting-outputs"
  fvm dart run build_runner build --delete-conflicting-outputs || {
    echo -e "${YELLOW}  ⚠️  build_runner 失败,可能是首次没生成 model 文件,跳过${NC}"
  }
else
  echo -e "${GREEN}  ✓ 无 freezed,跳过${NC}"
fi
echo

# ════════════════════════════════════════════════════════════════════
# 完成
# ════════════════════════════════════════════════════════════════════
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Setup 完成!                                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo
echo "下一步:"
echo
echo -e "  ${BLUE}# Mock 模式 (开发用)${NC}"
echo "  fvm flutter run --dart-define=USE_MOCK=true"
echo
echo -e "  ${BLUE}# 真实接口模式${NC}"
echo "  fvm flutter run"
echo
echo -e "  ${BLUE}# 编译验证 (慢)${NC}"
echo "  bash scripts/build_check.sh"
echo
echo -e "  ${BLUE}# 也可以用快捷脚本${NC}"
echo "  bash scripts/run.sh"
echo
echo -e "${YELLOW}💡 VS Code 用户:${NC} 已配置 .vscode/settings.json,重启编辑器即可"
echo -e "${YELLOW}💡 Android Studio 用户:${NC} Settings → Languages → Flutter → SDK path 设为 .fvm/flutter_sdk"
echo
