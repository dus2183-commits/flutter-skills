#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Reflector Hook — 写文件后静态检查 + 严重问题强制拦截
# ────────────────────────────────────────────────────────────────────
#  触发: PostToolUse (Write / Edit)
#
#  规则:
#    - 致命问题 (BLOCKING) → exit 2 + 详细修复指引 (Claude 会重新尝试)
#    - 警告 (WARNING)      → stderr 输出但不阻断
#
#  致命(必改):
#    *.model.dart: 不是 @freezed / 没 fromJson
#    *_repository.dart: 不 extends GetxService / path 带 /api / 无 mockKey
#    *_binding.dart: 用 lambda 不用 tearoff
# ════════════════════════════════════════════════════════════════════

exec /usr/bin/python3 <<'PYEOF'
import json, os, re, sys

try:
    data = json.load(sys.stdin)
except:
    sys.exit(0)

tool = data.get("tool_name", "")
if tool not in ("Write", "Edit"):
    sys.exit(0)

file_path = data.get("tool_input", {}).get("file_path", "")
if not file_path or not os.path.exists(file_path):
    sys.exit(0)

if file_path.endswith((".freezed.dart", ".g.dart", ".config.dart")):
    sys.exit(0)

try:
    with open(file_path, encoding="utf-8") as f:
        content = f.read()
except:
    sys.exit(0)

blocking = []  # 致命问题,exit 2
warnings = []  # 警告

# ─── spec.md ────────────────────────────────
if re.search(r"docs/specs/[^/]+\.md$", file_path):
    sections = [f"## {i}." for i in range(1, 8)]
    missing = [s for s in sections if s not in content]
    if missing:
        blocking.append(f"spec 缺段 {missing} — 必须补齐 7 段")

    ex_section = re.search(r"## 6\.[^#]+", content)
    if ex_section:
        bullets = re.findall(r"^[-*]\s+", ex_section.group(0), re.MULTILINE)
        if len(bullets) < 3:
            blocking.append(f"异常场景只有 {len(bullets)} 条,必须 ≥ 3 条")

# ─── api.md ─────────────────────────────────
elif re.search(r"docs/api/[^/]+\.md$", file_path):
    if "Mock Key" not in content and "mockKey" not in content:
        blocking.append("api 契约必须有 Mock Key 字段")
    if not re.search(r"2\d{4,5}", content):
        warnings.append("api 契约似乎没有错误码段位")

# ─── plan.md ────────────────────────────────
elif re.search(r"docs/plans/[^/]+\.md$", file_path):
    if "依赖" not in content and "dependency" not in content.lower():
        warnings.append("plan 缺少任务依赖图")
    if "mock" not in content.lower():
        warnings.append("plan 缺少 mock 先行标记")

# ─── *.model.dart 或 含 @freezed 的文件 ──────
elif file_path.endswith(".model.dart") or "@freezed" in content:
    if not file_path.endswith(".model.dart"):
        warnings.append(f"命名不规范: 含 @freezed 的 model 应该叫 *.model.dart (当前: {os.path.basename(file_path)})")
    if "@freezed" not in content:
        blocking.append("model 必须用 @freezed 注解")
    if "part " not in content:
        blocking.append("model 缺少 part 声明 (part '.freezed.dart' + part '.g.dart')")
    if "fromJson" not in content:
        blocking.append("model 缺少 fromJson 工厂构造")

# ─── *_repository.dart ──────────────────────
elif file_path.endswith("_repository.dart") and "binding" not in file_path:
    if "extends GetxService" not in content:
        blocking.append("Repository 必须 extends GetxService")
    if "Get.find" not in content:
        blocking.append("Repository 必须用 Get.find<ApiClient>() 获取实例")
    if "mockKey" not in content:
        blocking.append("Repository 所有方法必须传 mockKey 参数")
    if re.search(r"try\s*\{[^}]*await\s+_api\.", content, re.DOTALL):
        blocking.append("Repository 不应 catch 异常 — 让 controller 上层 catch")
    if "app_exception" in content:
        blocking.append("Repository 不应 import app_exception.dart (会触发 unused_import)")
    if re.search(r"path:\s*['\"]/api/", content):
        blocking.append("Repository path 不应带 /api 前缀 (baseUrl 已含 apiPrefix,重复会 /api/api/ 404)")

# ─── *_binding.dart ─────────────────────────
elif file_path.endswith("_binding.dart"):
    if re.search(r"lazyPut\s*[<(][^)]*\(\s*\)\s*=>", content):
        blocking.append("Binding 必须用 tearoff: Xxx.new,不是 () => Xxx() (会触发 unnecessary_lambdas)")

# ─── *_page.dart ────────────────────────────
elif file_path.endswith("_page.dart"):
    if "GetView<" not in content and "StatefulWidget" not in content:
        blocking.append("页面必须 extends GetView<Controller> 或 StatefulWidget,不能是裸 StatelessWidget")
    if ".withOpacity(" in content:
        blocking.append("withOpacity 已 deprecated (Flutter 3.27),必须用 withValues(alpha: x)")
    if re.search(r"ListView\s*\(", content) and ".builder" not in content:
        blocking.append("长列表必须用 ListView.builder,不能用 ListView(children:)")
    if "RefreshIndicator" in content and "EasyRefresh" not in content:
        warnings.append("推荐用 EasyRefresh 替代 RefreshIndicator (下拉+上拉)")

# ─── *_controller.dart ──────────────────────
elif file_path.endswith("_controller.dart"):
    if re.search(r"\n\s+Future<void>\s+refresh\(\)", content):
        if not re.search(r"@override\s+Future<void>\s+refresh\(\)", content):
            blocking.append("refresh() 方法必须加 @override (GetxController 有同名方法)")
    if re.search(r"AppException\(\s*message:", content):
        blocking.append("AppException 是 sealed class,不能 new,用 UnknownException(message:, cause:, stackTrace:)")
    if ".withOpacity(" in content:
        blocking.append("withOpacity deprecated,用 withValues(alpha: x)")

# ─── 输出 ───────────────────────────────────
has_error = False
if blocking:
    print("", file=sys.stderr)
    print(f"⛔ Reflector 检测到 {len(blocking)} 个致命问题,必须修复:", file=sys.stderr)
    print(f"   文件: {file_path}", file=sys.stderr)
    for b in blocking:
        print(f"   ❌ {b}", file=sys.stderr)
    has_error = True

if warnings:
    print("", file=sys.stderr)
    print(f"📋 Reflector 警告 (非阻断):", file=sys.stderr)
    for w in warnings:
        print(f"   ⚠️  {w}", file=sys.stderr)

if has_error:
    print("", file=sys.stderr)
    print("请修复上述致命问题后重新写入。", file=sys.stderr)
    print("如确认绕过,设 BYPASS_REFLECTOR=1", file=sys.stderr)
    if os.environ.get("BYPASS_REFLECTOR") == "1":
        sys.exit(0)
    sys.exit(2)

sys.exit(0)
PYEOF
