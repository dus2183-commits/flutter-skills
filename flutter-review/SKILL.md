---
name: flutter-review
description: 代码评审。对照项目规范(GetX/性能/安全/国际化/多平台)逐项检查,输出结构化报告。用户说"评审这个代码"、"review 这个页面"、"检查有没有问题"、"帮我看看代码"、"code review"、"代码 review"、"审一下"、"看下规范"时触发。
type: skill
stage: 5
model: opus
priority: P0
version: 1.0.0
owner: @c
category: validator
---

# 代码评审 (flutter-review)

## 1. 触发场景
- "帮我 review 这个代码"
- "这个页面写法有没有问题"
- "这个 controller 规范吗"
- "检查一下代码质量"
- "按照规范评审这个模块"

## 2. 前置必读
- `docs/_context/conventions.md`
- `_governance/checklists/getx-usage.md`
- `_governance/checklists/performance.md`
- `_governance/checklists/security.md`
- `_governance/checklists/multi-platform.md`
- `_governance/checklists/i18n.md`
- `_knowledge/artifact-templates/review.template.md`
- `_design/app_exception.dart`

## 3. 输入

**必填:**
- 一段代码片段、或一个模块目录结构说明

**可选:**
- `scope`: 评审范围 (全检查 / 快速检查)
- `format`: 输出格式 (详细报告 / 简要列表)

## 4. 工作流程

**Step 1 — 读取代码/结构**
如果是代码片段，直接解析。
如果是目录结构描述，要求用户补充代码。

**Step 2 — 逐项对照 5 大 checklist**

5 个检查维度:
1. **GetX 规范** (`getx-usage.md`)
2. **性能规范** (`performance.md`)
3. **安全规范** (`security.md`)
4. **多平台规范** (`multi-platform.md`)
5. **国际化规范** (`i18n.md`)

每个维度检查 7-10 条规则。

**Step 3 — 分类记录问题**

对每个问题标记严重度:
- 🔴 **Critical** — 功能错误或违反架构（必须改）
- 🟠 **Warning** — 性能/安全/规范问题（应该改）
- 🟡 **Info** — 建议优化项（可选改）

**Step 4 — 生成结构化报告**

见下方段 6。

**Step 5 — 提供修改建议**

对每个问题，给出:
- 为什么有问题
- 具体改法（代码示例）
- 参考规范（checklist 哪一条）

## 5. 输出产物

生成评审报告，通常存放在 `docs/reviews/{module_name}_{date}.md`。

**文件命名:** `{module_name}_review_{YYYY-MM-DD}.md`。

## 6. 模板示例 — 评审报告格式

```markdown
---
artifact_type: review
reviewed_item: lib/features/announcement/
created: 2026-04-10
created_by: flutter-review
---

# 代码评审报告 · Announcement 模块

## 1. 总体评分

| 项目 | 评分 | 备注 |
|------|------|------|
| GetX 规范 | ⭐⭐⭐⭐ | 架构清晰，但有 1 个小问题 |
| 性能 | ⭐⭐⭐ | 需要优化列表渲染 |
| 安全 | ⭐⭐⭐⭐⭐ | 未发现问题 |
| 多平台 | ⭐⭐⭐⭐⭐ | 未发现问题 |
| 国际化 | ⭐⭐⭐ | 硬编码文本 2 处 |
| **总评** | **19/25** | 质量良好，需要小改 |

---

## 2. GetX 规范检查

**检查清单来源:** `_governance/checklists/getx-usage.md`

### ✅ 通过项

- [x] Controller 继承自 `GetxController`
- [x] View 继承 `GetView<AnnouncementController>`
- [x] 响应式变量使用 `.obs`
- [x] Binding 使用 `Get.lazyPut`
- [x] `onClose()` 中正确释放资源

### 🔴 严重问题

**问题 1: Controller 中直接操作 UI**

```dart
// ❌ 错误做法
void handleError() {
  Get.snackbar('Error', 'Failed to load');  // ← 不能在 controller 里调这个
  Get.off(LoginPage());
}
```

**改法:**
```dart
// ✅ 正确做法
// 在 Controller 中设置状态
hasError.value = true;
errorMessage.value = 'Failed to load';

// 在 View 中监听并显示
Obx(() => announcements.isEmpty && hasError.value
  ? ErrorWidget(
      message: errorMessage.value,
      onRetry: () => controller.reload(),
    )
  : ...
)
```

**参考:** `getx-usage.md` 第 3 条 "Controller 只负责业务逻辑"

---

### 🟠 警告

**问题 2: Obx 包裹范围太大**

```dart
// ⚠️ 不够优化
Obx(() => Scaffold(
  appBar: AppBar(...),
  body: ListView(...),  // ← 整个 body 都会重绘
))
```

**改法:**
```dart
// ✅ 更好的做法
Scaffold(
  appBar: AppBar(...),
  body: Obx(() => announcements.isEmpty
    ? EmptyWidget()
    : ListView.builder(...)
  ),
)
```

**参考:** `getx-usage.md` 第 5 条 "Obx 只包裹需要响应的部分"

---

## 3. 性能检查

**检查清单来源:** `_governance/checklists/performance.md`

### 🔴 严重问题

**问题 3: ListView 没有使用 `.builder`**

```dart
// ❌ 错误：全量渲染所有项
ListView(
  children: announcements.map((a) => AnnouncementCard($a)).toList(),
)
```

**改法:**
```dart
// ✅ 正确：增量渲染
ListView.builder(
  itemCount: announcements.length,
  itemBuilder: (ctx, idx) => AnnouncementCard(announcements[idx]),
)
```

**影响:** 列表超过 100 条时明显卡顿。

**参考:** `performance.md` 第 2 条 "大列表必须用 `.builder`"

---

### 🟠 警告

**问题 4: build() 中创建持久对象**

```dart
// ⚠️ 每次 rebuild 都创建新对象，浪费内存
@override
Widget build(BuildContext context) {
  final textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
  return Text('Title', style: textStyle);
}
```

**改法:**
```dart
// ✅ 提取为常量或字段
static const _titleStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

@override
Widget build(BuildContext context) {
  return Text('Title', style: _titleStyle);
}
```

**参考:** `performance.md` 第 7 条 "避免在 build() 中创建对象"

---

## 4. 安全检查

**检查清单来源:** `_governance/checklists/security.md`

### ✅ 通过项

- [x] 没有硬编码 API 密钥或 Token
- [x] 网络请求使用 https
- [x] 用户输入经过基本校验

---

## 5. 多平台检查

**检查清单来源:** `_governance/checklists/multi-platform.md`

### ✅ 通过项

- [x] 没有使用 Android/iOS 专有 API
- [x] 布局使用 responsive (MediaQuery / LayoutBuilder)
- [x] 支持 RTL 布局（如果需要）

---

## 6. 国际化检查

**检查清单来源:** `_governance/checklists/i18n.md`

### 🟠 警告

**问题 5: 硬编码文本 2 处**

```dart
// ❌ 硬编码中文
Text('公告列表'),
Text('暂无数据'),
```

**改法:**
```dart
// ✅ 使用 GetX i18n
Text('announcement_list'.tr),
Text('no_data'.tr),
```

**文件:** `lib/` 下新建或编辑 `translations/zh_CN.json`:
```json
{
  "announcement_list": "公告列表",
  "no_data": "暂无数据"
}
```

**参考:** `i18n.md` 第 2 条 "所有用户可见的文本必须国际化"

---

## 7. 其他建议

### 异常处理

确保使用项目定义的 `AppException`:

```dart
import 'package:app/core/error/app_exception.dart';

try {
  final data = await repository.fetch();
  announcements.value = data;
} on DioException catch (e) {
  final appError = AppException.fromDioException(e);
  errorMessage.value = appError.message;
}
```

**参考:** `_design/app_exception.dart`

---

## 8. 改进优先级

| 优先级 | 问题 | 处理时间 |
|--------|------|---------|
| 🔴 P0 | 问题 1 (Controller 操作 UI) | 立即改 |
| 🔴 P0 | 问题 3 (ListView builder) | 立即改 |
| 🟠 P1 | 问题 2 (Obx 包裹) | 本周内改 |
| 🟠 P1 | 问题 4 (build 创建对象) | 本周内改 |
| 🟡 P2 | 问题 5 (硬编码文本) | 近期改 |

---

## 9. 下一步

1. 修改代码解决 5 个问题
2. 修改后再 review 一遍
3. 通过 health-check 验证整体质量

```

## 7. 不做什么

- ❌ 不修改代码 (只检查和建议)
- ❌ 不生成新功能建议 (只检查已有规范)
- ❌ 不评审测试代码 (除非用户指定)
- ❌ 不改设计 (只改规范问题)
- ❌ 不做 commit

> ⚠️ **高频错误警告 — 评审时必须额外检查这些已知坑:**
> - `withOpacity()` 已 deprecated (Flutter 3.27) → 改 `withValues(alpha: 0.15)`
> - Repository 不应 import `app_exception.dart` (unused_import)
> - Binding 必须用 tearoff `Repository.new`,不能 `() => Repository()` (unnecessary_lambdas)
> - Controller 的 `refresh()` 必须加 `@override` (GetxController 有同名方法)
> - fire-and-forget Future 必须 `unawaited()` 包装 + `import 'dart:async'`
> - path 不带 `/api` 前缀 (baseUrl 已含 apiPrefix,重复会 /api/api/ 404)
> - pubspec.yaml mock assets 必须显式注册子目录 (Flutter 不递归)
> - `AppException` 是 sealed class,不能直接 new,用具体子类如 `UnknownException`
> - 浮出父容器用 `Stack + clipBehavior: Clip.none`,不用 Transform
> - 列表必须用 `EasyRefresh` 不是 `RefreshIndicator`
> - mockKey 必须传

## 8. 自检 Checklist

- [ ] 5 大检查清单都对照过
- [ ] 高频错误警告中的 11 条都检查了
- [ ] 每个问题都分了严重度 (🔴🟠🟡)
- [ ] 每个问题都给了代码示例
- [ ] 引用了对应的 checklist 文件
- [ ] 给出了改进优先级

## 9. 失败处理

**代码过于复杂无法全量检查时:**
> ASK_USER "代码量较大 (>500 行)，建议分模块评审。现在 review {模块 1}，其他部分后续处理？"

**代码格式混乱无法解析时:**
> "代码格式有问题，建议先跑 `flutter-lint-fix` 格式化后再 review。"

## 10. 联动

**成功后:**
> "✅ 代码评审完成。
> - 发现 5 个问题 (🔴2 / 🟠2 / 🟡1)
> - 需要立即改: 问题 1, 3
> - 修改后建议再 review 一次"

**上游:**
- flutter-page-gen / flutter-widget-gen / flutter-design-to-code (生成的代码)

**下游:**
- flutter-lint-fix (修复代码风格)
- flutter-health-check (项目体检)
