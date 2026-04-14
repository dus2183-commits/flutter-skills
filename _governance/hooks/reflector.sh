#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Reflector Hook — 写文件后静态检查内容质量
# ────────────────────────────────────────────────────────────────────
#  触发: PostToolUse (Write / Edit)
#  作用: 按文件类型跑规则检查,不合格 stderr 输出警告
#
#  检查规则:
#    spec.md:        7 段 + 异常 ≥3
#    plan.md:        任务依赖 + mock 先行
#    api.md:         Mock Key + 错误码段位
#    *.model.dart:   freezed + part + fromJson
#    *_repository.dart: extends GetxService + mockKey + 不 catch + 不 import app_exception
#    *_binding.dart: tearoff
#    *_page.dart:    GetView + 不 withOpacity + ListView.builder + EasyRefresh
#    *_controller.dart: refresh @override + AppException 不 new
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

# 跳过生成的文件
if file_path.endswith((".freezed.dart", ".g.dart", ".config.dart")):
    sys.exit(0)

try:
    with open(file_path, encoding="utf-8") as f:
        content = f.read()
except:
    sys.exit(0)

warnings = []

# ─── spec.md ────────────────────────────────
if re.search(r"docs/specs/[^/]+\.md$", file_path):
    sections = [f"## {i}." for i in range(1, 8)]
    missing = [s for s in sections if s not in content]
    if missing:
        warnings.append(f"spec 缺段: {missing}")

    ex_section = re.search(r"## 6\.[^#]+", content)
    if ex_section:
        bullets = re.findall(r"^[-*]\s+", ex_section.group(0), re.MULTILINE)
        if len(bullets) < 3:
            warnings.append(f"异常场景只有 {len(bullets)} 条,要求 ≥ 3 条")

# ─── plan.md ────────────────────────────────
elif re.search(r"docs/plans/[^/]+\.md$", file_path):
    if "依赖" not in content and "dependency" not in content.lower():
        warnings.append("plan 缺少任务依赖图")
    if "mock" not in content.lower():
        warnings.append("plan 缺少 mock 先行标记")

# ─── api.md ─────────────────────────────────
elif re.search(r"docs/api/[^/]+\.md$", file_path):
    if "Mock Key" not in content and "mockKey" not in content:
        warnings.append("api 契约缺少 Mock Key 字段")
    if not re.search(r"2\d{4,5}", content):
        warnings.append("api 契约似乎没有错误码段位 (2xxxxx 格式)")

# ─── *.model.dart ───────────────────────────
elif file_path.endswith(".model.dart"):
    if "@freezed" not in content:
        warnings.append("model 必须用 @freezed")
    if "part " not in content:
        warnings.append("model 缺少 part 声明")
    if "fromJson" not in content:
        warnings.append("model 缺少 fromJson 工厂")

# ─── *_repository.dart ──────────────────────
elif file_path.endswith("_repository.dart") and "binding" not in file_path:
    if "extends GetxService" not in content:
        warnings.append("Repository 必须 extends GetxService")
    if "Get.find" not in content:
        warnings.append("Repository 必须用 Get.find<ApiClient>()")
    if "mockKey" not in content:
        warnings.append("Repository 方法必须传 mockKey 参数")
    if re.search(r"try\s*\{[^}]*await\s+_api\.", content, re.DOTALL):
        warnings.append("Repository 不应 catch 异常,让 controller 处理")
    if "app_exception" in content:
        warnings.append("Repository 不应 import app_exception (unused_import)")
    if re.search(r"path:\s*['\"]/api/", content):
        warnings.append("Repository path 不应带 /api 前缀 (baseUrl 已含)")

# ─── *_binding.dart ─────────────────────────
elif file_path.endswith("_binding.dart"):
    if re.search(r"lazyPut\s*[<(][^)]*\(\s*\)\s*=>", content):
        warnings.append("Binding 应该用 tearoff (Xxx.new),不是 () => Xxx()")

# ─── *_page.dart ────────────────────────────
elif file_path.endswith("_page.dart"):
    if "GetView<" not in content and "StatefulWidget" not in content:
        warnings.append("页面应该 extends GetView<Controller>")
    if ".withOpacity(" in content:
        warnings.append("withOpacity 已 deprecated (Flutter 3.27),用 withValues(alpha: x)")
    if re.search(r"ListView\s*\(", content) and ".builder" not in content:
        warnings.append("长列表应该用 ListView.builder")
    if "RefreshIndicator" in content and "EasyRefresh" not in content:
        warnings.append("推荐用 EasyRefresh 替代 RefreshIndicator (下拉+上拉)")

# ─── *_controller.dart ──────────────────────
elif file_path.endswith("_controller.dart"):
    if re.search(r"\n\s+Future<void>\s+refresh\(\)", content):
        if not re.search(r"@override\s+Future<void>\s+refresh\(\)", content):
            warnings.append("refresh() 必须加 @override (GetxController 有同名方法)")
    if re.search(r"AppException\(\s*message:", content):
        warnings.append("AppException 是 sealed class 不能 new,用 UnknownException(message:, cause:, stackTrace:)")
    if ".withOpacity(" in content:
        warnings.append("withOpacity 已 deprecated,用 withValues(alpha: x)")

# 输出警告
if warnings:
    print("", file=sys.stderr)
    print(f"📋 Reflector: {os.path.basename(file_path)} 有 {len(warnings)} 个问题", file=sys.stderr)
    for w in warnings:
        print(f"   ⚠️  {w}", file=sys.stderr)
    print("", file=sys.stderr)
PYEOF
