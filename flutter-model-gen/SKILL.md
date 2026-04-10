---
name: flutter-model-gen
description: JSON 或接口契约 → freezed Dart 实体类。用户说"生成 model"、"JSON 转 Dart"、"根据接口生成实体"或 api-design 完成后触发。自动处理基础类型/可空/嵌套对象/DateTime,生成 freezed + json_serializable 模板,可被 build_runner 编译。
type: skill
stage: 4
model: sonnet
priority: P0
version: 1.0.0
owner: @b
category: generator
---

# 实体生成 (flutter-model-gen)

> ⚠️ **博龙的样板 v1** — 基础功能渡已搭好,**你需要扩展的部分在段 11**

---

## 1. 触发场景

- "生成 XX 模块的 model"
- "把这段 JSON 转成 Dart"
- "根据接口契约生成实体"
- api-design 完成后 workflow 自动触发

**反例:**
- "生成接口请求" → `flutter-api-gen`
- "生成页面" → `flutter-page-gen`

---

## 2. 前置必读

- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `docs/api/{module}.md` (上游 artifact,首选)
- `_design/api_client_signature.dart` (PageReq / PageResp 约定)

---

## 3. 输入

**输入分流(3 种):**

A. **接口契约文件** (推荐,完整信息)
   - 路径: `docs/api/{module}.md`
   - 自动提取所有接口的请求/响应字段

B. **裸 JSON 字符串**
   - 用户粘贴一段 JSON
   - 推断字段类型

C. **多个 JSON + 模块名**
   - 用户给多个 JSON 片段
   - 自动 dedupe 字段,合成一个 model

---

## 4. 工作流程

### Step 1 — 读上下文 + 上游 artifact

### Step 2 — 解析输入,提取字段
对每个字段:
- 名称 (camelCase)
- 类型 (string / int / double / bool / DateTime / List<T> / Map / 嵌套类)
- 是否可空 (`?`)

### Step 3 — 类型推断规则
| JSON 值 | Dart 类型 |
|---|---|
| `"abc"` | `String` |
| `123` | `int` |
| `12.5` | `double` |
| `true` | `bool` |
| `null` | 字段加 `?`,类型从其他样本推断 |
| `"2026-04-10T10:00:00Z"` | `DateTime` (用正则识别 ISO) |
| `1696732800` | `int` (时间戳) ⚠️ 但也可能是普通 int,**问用户** |
| `[1, 2]` | `List<int>` |
| `{...}` | 嵌套类 (拆独立文件) |

### Step 4 — 嵌套对象处理 (v1 基础版)
- 检测嵌套对象
- 递归生成独立 .model.dart 文件
- 命名: 父类名 + 字段名 PascalCase (例: `User` 里的 `address` → `UserAddress`)
- ⚠️ **v1 不处理深层嵌套(>2 层),给警告让用户手动**

### Step 5 — 生成 freezed 模板
按段 6 的代码模板,每个实体一个文件。

### Step 6 — 写入文件
- 路径: `lib/features/{module}/data/models/{entity}.model.dart`
- 同时生成同目录下的 placeholder `{entity}.model.freezed.dart` (空文件,提示要跑 build_runner)

### Step 7 — 提示运行 build_runner
```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

### Step 8 — 自检

### Step 9 — 联动
建议下一步用 `flutter-api-gen` 生成 Repository。

---

## 5. 输出产物

```
lib/features/{module}/data/models/
├── {entity1}.model.dart            主 model
├── {entity1}.model.freezed.dart    (build_runner 生成)
├── {entity1}.model.g.dart          (build_runner 生成)
└── {entity2}.model.dart            如有第二个 entity
```

---

## 6. 代码模板 (v1 基础版)

### 6.1 简单 model

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'announce.model.freezed.dart';
part 'announce.model.g.dart';

@freezed
class Announce with _$Announce {
  const factory Announce({
    required String id,
    required String title,
    String? summary,
    String? content,
    required DateTime publishAt,
    @Default(false) bool isRead,
    String? author,
  }) = _Announce;

  factory Announce.fromJson(Map<String, dynamic> json) =>
      _$AnnounceFromJson(json);
}
```

### 6.2 List 字段

```dart
@freezed
class AnnounceListResp with _$AnnounceListResp {
  const factory AnnounceListResp({
    required List<Announce> list,
    required int total,
    required int page,
    required int pageSize,
  }) = _AnnounceListResp;

  factory AnnounceListResp.fromJson(Map<String, dynamic> json) =>
      _$AnnounceListRespFromJson(json);
}
```

### 6.3 嵌套对象 (v1 拆 2 个文件)

`user.model.dart`:
```dart
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String name,
    UserAddress? address,  // 嵌套
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

`user_address.model.dart`:
```dart
@freezed
class UserAddress with _$UserAddress {
  const factory UserAddress({
    required String city,
    required String detail,
  }) = _UserAddress;

  factory UserAddress.fromJson(Map<String, dynamic> json) =>
      _$UserAddressFromJson(json);
}
```

---

## 7. 不做什么

- ❌ 不自动跑 build_runner (用户控制时机)
- ❌ 不修改 pubspec.yaml (freezed 已在依赖)
- ❌ 不生成自定义 fromJson 逻辑 (交给 json_serializable)
- ❌ 不修改已有 model (除非用户明确要 update)
- ❌ 不删除文件
- ❌ 不在 model 内写业务方法 (model 是数据,不是行为)
- ❌ 不处理 union types (v1 暂不支持,见段 11)

---

## 8. 自检 Checklist

- [ ] 所有字段有类型 (无 dynamic / Object)
- [ ] nullable 标注正确 (用 `?`)
- [ ] 嵌套对象拆独立文件
- [ ] DateTime 字段用 ISO 解析,不是 `String`
- [ ] 文件名 snake_case,类名 PascalCase
- [ ] freezed 模板包含 `part` 声明
- [ ] `factory fromJson` 返回类型正确
- [ ] List 字段用 `List<T>` 不用 `List`
- [ ] 必填字段标 `required`,可空字段标 `?`

---

## 9. 失败处理

**ASK_USER 时机:**
- JSON 字段类型推断不出 (string vs int)
- 时间格式不明 (ISO vs timestamp)
- 嵌套深度 > 2,让用户决定是否拆
- 字段名与 Dart 关键字冲突 (如 `class` → `clazz`?)

**STOP 时机:**
- JSON 解析失败 (非法格式)
- 上游 docs/api/{m}.md 不存在
- lib/features/{module}/ 目录不存在(应先 init)

**ROLLBACK:**
- 自检失败时删除新增的 .model.dart 文件

---

## 10. 联动

**成功后建议:**
> "Model 生成完成: lib/features/{m}/data/models/
>   - {N} 个实体类
>   - 必须运行: fvm dart run build_runner build --delete-conflicting-outputs
>
> 下一步: 用 flutter-api-gen 生成 Repository"

**失败后建议:**
> "Model 生成失败,详情见 docs/_failures/{date}.md
> 检查 docs/api/{m}.md 字段类型是否完整"

**上游:** flutter-api-design
**下游:** flutter-api-gen

---

## 11. 🚧 给博龙: 扩展路线图

**v1 (渡已写) — 基础够用,可立即开工:**
- ✅ 简单类型推断 (string/int/bool/double/DateTime/List)
- ✅ 可空字段 (`?`)
- ✅ 嵌套对象拆文件 (≤ 2 层)
- ✅ freezed + json_serializable 模板
- ✅ List<T> 类型

**v2 (你应该加) — 第二周做:**
- ⏳ **枚举推断** — 检测固定字符串值集合 (如 `"status": "active|inactive"`),生成 `enum` + `@JsonValue`
- ⏳ **深层嵌套** (> 2 层) — 自动递归不需要警告
- ⏳ **时间戳支持** — 用户选 ISO 还是 unix timestamp,生成对应 `@JsonKey(fromJson:..., toJson:...)`
- ⏳ **从多个 JSON 样本合成** (输入 C 路径) — 字段去重 + 类型合并
- ⏳ **驼峰/下划线自动转换** — 后端 `snake_case` ↔ Dart `camelCase` (`@JsonKey(name: 'snake_case')`)
- ⏳ **字段说明注释** — 从 docs/api/{m}.md 的"说明"列提取,加 `///` doc

**v3 (可选高级) — 后续迭代:**
- 💡 **Union types / sealed class** — 处理 `type: A | B | C` 的多态结构
- 💡 **Generic model** — `Resp<T>` 这种泛型包装
- 💡 **Validation 注解** — 加 `@JsonKey(required: true)` 等
- 💡 **toString / hashCode 自定义** — 覆盖 freezed 默认
- 💡 **builder 模式** — 复杂构造场景
- 💡 **跨模块共享 model** — 抽到 `lib/shared/models/`
- 💡 **Mock data 自动生成** — 根据 model 生成符合类型的 mock(配合 mock 拦截器)

**完全不要做的:**
- ❌ 不要在 model 里加业务方法 (违反"model 是数据"原则)
- ❌ 不要硬编码字段值 (生成时才知道)
- ❌ 不要自动跑 build_runner (用户决定时机)
- ❌ 不要支持非 freezed 的 model (项目锁定 freezed)

---

## 给博龙的具体提示

1. **你接手 v1 后,先跑一次端到端:**
   ```
   照着段 6 给一段 JSON,看 SKILL.md 跑出来的代码能不能 build_runner 通过
   ```

2. **v2 优先级:** 枚举推断 > 时间戳 > snake_case 转换 > 深层嵌套 > 多 JSON 合成

3. **测试 fixture:** 在 `tests/fixtures/flutter-model-gen/` 准备 5 个真实 JSON 样本(从 yc141 拿),作为回归测试

4. **改 SKILL.md 后,version 字段递增:** v1.0.0 → v1.1.0 (加新功能) / v2.0.0 (破坏性变更)
