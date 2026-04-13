---
name: flutter-error-code-gen
description: 从 docs/api/*.md 提取错误码表,生成 Dart enum 常量类。用户说"生成错误码"、"错误码常量"时触发。避免 controller 里硬编码 magic number。
type: skill
stage: 5
model: haiku
priority: P2
version: 1.0.0
owner: @lead
category: generator
---

# 错误码生成 (flutter-error-code-gen)

## 1. 触发场景

- "生成错误码常量" / "把错误码提取成 enum"
- "不想在代码里写 21001"
- "错误码 enum"
- api-design 完成后建议

**反例:**
- "设计错误码" → flutter-api-design (在契约文档里定义)
- "处理异常" → controller catch AppException

## 2. 前置必读

- `docs/api/{module}.md` (错误码表)
- `docs/api/*.md` (所有模块的错误码,防冲突)
- `lib/core/error/` (已有错误体系)

## 3. 输入

**必填:**
- `module_name` — 模块名 (或 "all" 生成所有模块)

## 4. 工作流程

**Step 1 — 读契约文档,提取错误码表**

从 `docs/api/{module}.md` 的"错误码表"段提取:
```
| 201001 | 参数错误 |
| 201002 | 公告不存在 |
| 201003 | 已读过 |
```

**Step 2 — 生成 Dart 常量类**

**Step 3 — 自检**

## 5. 输出产物

```
lib/features/{module}/data/error_codes/{module}_error_codes.dart
```

## 6. 代码模板

```dart
// lib/features/announce/data/error_codes/announce_error_codes.dart

/// 公告模块错误码
///
/// 段位: 201001-201999
/// 来源: docs/api/announce.md
abstract class AnnounceErrorCodes {
  AnnounceErrorCodes._();

  /// 参数错误
  static const int paramInvalid = 201001;

  /// 公告不存在
  static const int notFound = 201002;

  /// 已读过
  static const int alreadyRead = 201003;

  /// 服务异常
  static const int serverError = 201099;
}
```

**使用方式 (在 controller 里):**
```dart
} on BusinessException catch (e) {
  if (e.bizCode == AnnounceErrorCodes.notFound) {
    // 特殊处理: 公告已删除
    Get.back();
    Get.snackbar('提示', '该公告已被删除');
  } else {
    error.value = e;
  }
}
```

**命名规则:**
- 类名: `{Module}ErrorCodes` (PascalCase)
- 常量名: camelCase,从中文说明推断
- 每个常量必须有 `///` 注释

## 7. 不做什么 (Boundary)

- ❌ 不定义错误码 (那是 api-design 的事)
- ❌ 不修改 AppException 体系
- ❌ 不修改 ErrorInterceptor
- ❌ 不修改 controller catch 逻辑 (只生成常量)
- ❌ 不自动 commit

## 8. 自检 Checklist

- [ ] 所有错误码都从 docs/api/{module}.md 提取
- [ ] 常量名不冲突
- [ ] 每个常量有 `///` 注释
- [ ] 类有文件头注释 (段位范围 + 来源)
- [ ] `dart analyze` 0 errors

## 9. 失败处理

**ASK_USER:** 错误码说明太模糊,无法推断常量名
**STOP:** docs/api/{module}.md 不存在或无错误码表
**ROLLBACK:** 删除生成的文件

## 10. 联动

**上游:** flutter-api-design (定义错误码)
**下游:** flutter-review (检查是否用了常量而非 magic number)
