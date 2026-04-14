#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Guard Core Hook — 拦截对核心文件的修改
# ────────────────────────────────────────────────────────────────────
#  触发: PreToolUse (Write / Edit)
#  作用: 禁止 Claude 随意改 lib/core/network 等核心基础设施
#
#  允许改的场景:
#    - 用户明确要求(通过环境变量 ALLOW_CORE_EDIT=1)
#    - 新增文件(不是修改已存在的)
#
#  返回:
#    exit 0  → 放行
#    exit 2  → 拦截(Claude Code 会告诉 Claude 该操作被拒绝)
# ════════════════════════════════════════════════════════════════════

INPUT=$(cat)
FILE=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

if [[ -z "$FILE" ]]; then
  exit 0
fi

# 受保护的核心路径
PROTECTED_PATTERNS=(
  "lib/core/network/api_client.dart"
  "lib/core/network/interceptors/encrypt_interceptor.dart"
  "lib/core/network/interceptors/error_interceptor.dart"
  "lib/core/network/interceptors/auth_interceptor.dart"
  "lib/core/network/interceptors/mock_interceptor.dart"
  "lib/core/network/interceptors/sign_interceptor.dart"
  "lib/core/crypto/aes_dynamic.dart"
  "lib/core/crypto/aes_static.dart"
  "lib/core/crypto/aes_util.dart"
  "lib/core/error/app_exception.dart"
  "lib/core/config/app_config.dart"
)

# 如果用户显式允许,放行
if [ "${ALLOW_CORE_EDIT}" = "1" ]; then
  exit 0
fi

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE" == *"$pattern"* ]]; then
    # 检查是不是新建文件(原文件不存在就放行)
    if [ ! -f "$FILE" ]; then
      exit 0
    fi

    echo "⛔ 禁止修改核心基础设施文件: $FILE" >&2
    echo "" >&2
    echo "这是项目共享的核心库,不应随意修改。" >&2
    echo "如果确实需要修改,请:" >&2
    echo "  1. 向用户说明原因和影响" >&2
    echo "  2. 让用户确认后,设置 ALLOW_CORE_EDIT=1 环境变量" >&2
    echo "" >&2
    echo "常见替代方案:" >&2
    echo "  - 业务错误码处理 → 在 controller 层 catch AppException" >&2
    echo "  - Token 注入 → 用 TokenService (core/services/)" >&2
    echo "  - 接口加解密 → 通过 EncryptMode 和 .env.dev 配置" >&2
    exit 2
  fi
done

exit 0
