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

export PYTHONUTF8=1 PYTHONIOENCODING=utf-8 LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export HOOK_INPUT="$(cat)"
exec /usr/bin/python3 <<'PYEOF'
import json, os, re, sys

try:
    data = json.loads(os.environ.get("HOOK_INPUT", "{}"))
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

# ─── 全局:任何 .dart 文件都不许出现 figma MCP URL ──
if file_path.endswith(".dart") and re.search(r"figma\.com/api/mcp/asset", content):
    blocking.append("禁止在 Dart 代码里写 figma.com/api/mcp/asset URL (7 天过期),必须 curl 下载到 assets/image/3.0x/{module}/ 后改 Image.asset")

# ─── 全局:.dart 文件常见坑预防(post-figma checklist 自动化) ──
if file_path.endswith(".dart"):
    # 坑 1: Matrix4.scale(x, y, z) 3 参数未实现
    if re.search(r"Matrix4\.scale\s*\([^)]*,[^)]*,[^)]*\)", content):
        blocking.append("Matrix4.scale(x,y,z) 3 参数版 vector_math 未实现,用 Transform.flip / Transform.rotate / Matrix4.diagonal3Values 替代")
    # 坑 6: withOpacity deprecated (Flutter 3.27+)
    if ".withOpacity(" in content:
        blocking.append("withOpacity deprecated (Flutter 3.27+),必须用 withValues(alpha: x)")
    # 坑 5: Image.asset 加载 .svg(扩展名错配)
    if re.search(r"Image\.asset\s*\(\s*['\"][^'\"]+\.svg['\"]", content):
        blocking.append("Image.asset 不支持 .svg,改用 SvgPicture.asset(import package:flutter_svg/flutter_svg.dart)")
    # 坑 5 反向: SvgPicture.asset 加载 .png(扩展名错配)
    if re.search(r"SvgPicture\.asset\s*\(\s*['\"][^'\"]+\.(png|jpg|jpeg|webp|gif)['\"]", content):
        blocking.append("SvgPicture.asset 不支持 .png/.jpg,改用 Image.asset")

# ─── 全局:.svg 文件不许含 CSS var() ──
if file_path.endswith(".svg") and re.search(r"\bvar\s*\(\s*--", content):
    blocking.append("SVG 含 CSS var() 变量,flutter_svg 不支持,必须替换为字面量颜色(如 fill=\"#FFFFFF\")")

# ─── 全局:spec.md 不许写"CDN 过期"后门话术 ──
if file_path.endswith(".md") and "docs/specs/" in file_path:
    if re.search(r"(CDN.*过期|7 天.*替换|MCP.*URL.*有效期|之后替换为本地)", content):
        blocking.append("spec 不许写'CDN 过期后再替换本地'的后门话术,必须写'page-gen 阶段切图必须下载到本地,禁止 CDN URL 中间态'")

# ─── spec.md ────────────────────────────────
if re.search(r"docs/specs/[^/]+\.md$", file_path):
    sections = [f"## {i}." for i in range(1, 8)]
    missing = [s for s in sections if s not in content]
    if missing:
        blocking.append(f"spec 缺段 {missing} — 必须补齐 7 段")

    ex_section = re.search(r"## 6\.[^#]+", content)
    if ex_section:
        body = ex_section.group(0)
        # 支持 3 种格式: bullet(- xxx / * xxx) / table 行(| ... |) / 编号(1. xxx)
        bullets = re.findall(r"^[-*]\s+", body, re.MULTILINE)
        numbered = re.findall(r"^\d+\.\s+", body, re.MULTILINE)
        # table 数据行: 以 | 开头,含多个 |,且不是表头分割线(---)
        table_rows = [
            line for line in body.split("\n")
            if line.strip().startswith("|") and line.count("|") >= 2
            and not re.match(r"^\s*\|[\s\-:]+\|", line)
            and "场景" not in line and "处理" not in line  # 跳过表头
        ]
        count = len(bullets) + len(numbered) + len(table_rows)
        if count < 3:
            blocking.append(f"异常场景只有 {count} 条,必须 ≥ 3 条(支持 bullet/编号/table 三种格式)")

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
elif file_path.endswith(".model.dart") or "@freezed" in content or "@JsonSerializable" in content:
    if not file_path.endswith(".model.dart"):
        blocking.append(f"命名违规: 含 @freezed/@JsonSerializable 的文件必须以 .model.dart 结尾 (当前: {os.path.basename(file_path)}) — 否则 auto-build-runner 不触发,build_runner 不自动跑,part '.freezed.dart' 引用也会错")
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
    # bug #26: ApiClient 契约方法是 postJson / postForm,不是 post
    if re.search(r"_api\.post\s*\(", content):
        blocking.append("ApiClient 没有 .post() 方法,用 .postJson() 或 .postForm() 代替 (契约方法只有: get / postJson / postForm / getList / delete)")

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
    if re.search(r"figma\.com/api/mcp/asset", content):
        blocking.append("禁止在生产代码里写 figma.com/api/mcp/asset URL (7 天过期),必须用 curl 下载到 assets/image/3.0x/{module}/ 后改成 Image.asset")

    # bug #29: Obx(() => ...) 闭包内必须读 .value,否则运行时报 'improper use of Obx'
    for m in re.finditer(r"Obx\s*\(\s*\(\)\s*=>", content):
        start = m.end()
        depth = 1
        end = len(content)
        for i in range(start, len(content)):
            ch = content[i]
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    end = i
                    break
        body = content[start:end]
        # 闭包体内无 .value 且无 .obs 赋值 → 误用(嵌套子 widget 不会触发 Obx 响应)
        if ".value" not in body and ".obs" not in body:
            warnings.append(
                "Obx(() => ...) 闭包内没读响应式变量(.value) — 运行时会报 "
                "'improper use of a GetX'。要么闭包内直接访问 controller.xxx.value,"
                "要么去掉 Obx 改普通 Widget"
            )
            break  # 一个文件报一次够了

# ─── app/tabs.dart 路由页面 import 必须三层嵌套 ──
# bug #27: page-gen 按规范生成 features/{m}/presentation/pages/{page}/{page}.dart
#          tabs.dart 如果引用两层路径 features/{m}/presentation/pages/{page}.dart → 编译错
elif re.search(r"app/tabs\.dart$", file_path):
    wrong = re.findall(r"features/(\w+)/presentation/pages/(\w+_page)\.dart", content)
    if wrong:
        samples = ", ".join([f"{m}/{p}.dart" for m, p in wrong[:3]])
        blocking.append(
            f"tabs.dart 引用了两层路径 ({samples}) — page-gen 规范是三层嵌套: "
            "features/{module}/presentation/pages/{page_name}/{page_name}.dart"
        )

# ─── main.dart / app/app.dart 的 Tab 主壳初始化(#28) ──
# Tab 页不是独立路由,GetPage 的 binding 不会触发 —
# 必须靠 GetMaterialApp 的 initialBinding: 一次性 lazyPut 所有 Tab Controller,
# 否则进 Tab 会报 '"XxxController" not found'
elif re.search(r"(lib/main\.dart|lib/app/app\.dart)$", file_path):
    if "GetMaterialApp" in content and ("tabs.dart" in content or "MainScaffold" in content):
        if "initialBinding" not in content:
            blocking.append(
                "GetMaterialApp 有 Tab 主壳但没设 initialBinding: — "
                "Tab 页 Controller 不会自动注入,运行时会报 '\"XxxController\" not found'。"
                "加 initialBinding: TabsBinding() 并在 Bindings.dependencies() 里为每个 Tab Controller "
                "调 Get.lazyPut<XxxController>(XxxController.new, fenix: true)"
            )

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
