---
name: flutter-model-gen
description: |
  JSON 或接口契约 → freezed Dart 实体类。用户说"生成 model"、"JSON 转 Dart"、"根据接口生成实体"或 api-design 完成后触发。
  支持 JSON 字符串、.md 契约文档、curl 命令、URL、多 JSON 合成。自动处理基础类型/可空/嵌套对象/DateTime/snake_case/枚举推断,生成 freezed + json_serializable 模板。
type: skill
stage: 4
model: sonnet
priority: P0
version: 1.0.0
owner: @b
category: generator
---

# 实体生成 (flutter-model-gen)

## 1. 触发场景

- "把这个 JSON 转成 Dart" / "JSON 转实体"
- "生成 XX 模块的 model" / "生成实体类"
- "根据接口文档生成实体"
- "把契约文档转成 freezed 类"
- "这个 URL 的数据转成 model"
- "这个 curl 命令转成 model"

**反例（不要用这个 skill）：**
- "生成接口请求" → `flutter-api-gen`
- "生成页面" → `flutter-page-gen`
- "设计接口契约" → `flutter-api-design`

## 2. 前置必读

- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `docs/_context/decisions.md`
- `docs/_context/glossary.md`
- `docs/api/{module}.md`（如输入为 .md 契约文档）
- `_design/api_client_signature.dart`（PageReq / PageResp 约定）

## 3. 输入

**必填参数：**
- `module_name` (string) — 模块英文名，snake_case
- `source` (string) — 用户输入（JSON 字符串 / .md 文件路径 / curl 命令 / URL）

**可选参数：**
- `force_overwrite` (bool, default false) — 是否覆盖已有 model 文件
- `output_path` (string, default `lib/features/{module}/data/models/`) — 自定义输出目录

**输入分流：**

| 形式 | 识别特征 | 解析方式 |
|---|---|---|
| JSON 字符串 | 包含 `{` 和 `}` 的 JSON | 直接解析，推断字段名、类型、可空性 |
| .md 文件路径 | 以 `/` 或 `./` 开头，或 `.md` 后缀 | Read 文件，提取响应结构中的 JSON |
| curl 命令 | 以 `curl` 开头 | Bash 执行 curl 拿到响应 JSON，再解析响应体推断字段 |
| URL | 以 http/https 开头（非 curl） | WebFetch 抓取，按内容类型分流（JSON 或文档） |
| 多 JSON 合成 | 用户给出多个 JSON 片段 + 模块名 | 字段去重 + 类型合并，合成一个 model |

## 4. 工作流程

**Pipeline:** 任何输入 → 解析 → 推断类型 → 拆嵌套 → dry-run → 生成 freezed 类

**Step 1 — 读 context**
读取段 2 列出的所有前置文件。如输入是 .md，读对应契约文档。

**Step 2 — 解析输入，识别字段**
按段 3 的输入分流规则判断输入形式：
- JSON → 直接解析
- .md → 提取响应结构中的 JSON
- curl → Bash 执行 curl 拿到响应 JSON，再解析响应体
- URL → fetch 后按内容分流
- 多 JSON → 逐个解析，字段去重，类型冲突时取更宽泛类型（如 int vs double → double），仍不确定时 AskUser

归一化为实体字段清单：

    模块名: announce
    实体清单:
      - 实体名: Announce
        字段:
          - {name: id, type: String, required: true, nullable: false}
          - {name: title, type: String, required: true, nullable: false}
          - {name: content, type: String, required: false, nullable: true}
          - {name: isRead, type: bool, required: true, nullable: false, default: false}
          - {name: publishAt, type: DateTime, required: false, nullable: true}

**Step 3 — 推断类型**
按以下规则推断字段类型：

| JSON 值 | Dart 类型 |
|---|---|
| `"xxx"` | String |
| `123` | int |
| `1.5` | double |
| `true` / `false` | bool |
| `"2026-04-10T10:00:00Z"` | DateTime |
| `[...]` 基本类型数组 | List\<T\>（T 为基本类型） |
| `[{...}]` 嵌套对象数组 | List\<T\>（T 为独立实体，取首元素推断，拆文件） |
| `{...}` 嵌套对象 | 独立实体类型 |
| `null` 或缺失 | 标记 nullable |

特殊处理：
- 枚举：从单个 JSON 样本无法检测枚举，跳过。从 .md 契约文档中如果列出了可选值（如 `"active" | "inactive"`），AskUser 确认是否生成枚举
- DateTime 格式：默认假设后端返回 ISO8601 字符串。如果 JSON 样本中日期字段为数字（Unix 时间戳），AskUser 确认格式并添加 `@JsonKey(fromJson: ...)` 转换
- snake_case 字段名：如果 JSON key 为 snake_case（如 `publish_at`），Dart 字段名转为 camelCase（`publishAt`），并添加 `@JsonKey(name: 'publish_at')`。如果项目已在 `build.yaml` 配置全局 `field_rename: snake`，则不需要 `@JsonKey`，以项目配置为准
- 类型不确定时 → AskUser 补全

**Step 4 — 嵌套对象拆文件**
每个嵌套对象拆为独立 `{entity}.model.dart`，主实体 import 嵌套实体。
- 命名规则：父类名 + 字段名 PascalCase（如 `Post` 里的 `author` → `PostAuthor`）
- 嵌套深度 ≤ 2 层：自动递归处理
- 嵌套深度 > 2 层：AskUser 确认是否继续拆分，避免过度碎片化

**Step 5 — Dry-run (AskUser)**
列出所有将生成的文件路径 + 每个实体的字段摘要。

使用 AskUserQuestion 提供三个选项：
1. **确认生成** — 进入 Step 6
2. **不要生成** — stop，不生成文件
3. **补充其他项** — 回到 Step 3，用户修改后重新 dry-run

**Step 6 — 写入 freezed 模板**
按段 6 的代码模板生成 `.model.dart` 文件。

**Step 7 — 自检**
跑段 8 checklist，逐项验证。

**Step 8 — 提示运行 build_runner**
提示用户执行：
```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

## 5. 输出产物

    {output_path}/                          — 默认 lib/features/{module}/data/models/
    ├── {entity}.model.dart                 — 主实体
    ├── {nested_entity}.model.dart          — 嵌套实体（如有）
    └── ...

输出路径默认 `lib/features/{module}/data/models/`，可通过 `output_path` 自定义。

## 6. 代码模板

以公告模块为例，生成的 freezed 实体类：

```dart
// announce.model.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'announce.model.freezed.dart';
part 'announce.model.g.dart';

@freezed
class Announce with _$Announce {
  const factory Announce({
    required String id,
    required String title,
    String? content,
    @Default(false) bool isRead,
    DateTime? publishAt,
  }) = _Announce;

  factory Announce.fromJson(Map<String, dynamic> json) =>
      _$AnnounceFromJson(json);
}
```

嵌套对象示例（如 Post 中的 author 字段）：

```dart
// post_author.model.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_author.model.freezed.dart';
part 'post_author.model.g.dart';

@freezed
class PostAuthor with _$PostAuthor {
  const factory PostAuthor({
    required String id,
    required String name,
    String? avatar,
  }) = _PostAuthor;

  factory PostAuthor.fromJson(Map<String, dynamic> json) =>
      _$PostAuthorFromJson(json);
}
```

主实体引用嵌套实体：

```dart
// post.model.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'post_author.model.dart';

part 'post.model.freezed.dart';
part 'post.model.g.dart';

@freezed
class Post with _$Post {
  const factory Post({
    required String id,
    required String title,
    required PostAuthor author,
  }) = _Post;

  factory Post.fromJson(Map<String, dynamic> json) =>
      _$PostFromJson(json);
}
```

**模板规则：**
- 必须包含 `part` 声明（`.freezed.dart` + `.g.dart`）
- 必须包含 `fromJson` 工厂构造函数
- required 字段不加 `?`，可空字段加 `?`
- 有默认值的字段用 `@Default(value)`
- 嵌套实体必须 import
- List 字段必须用 `List<T>`，不用裸 `List`

List 响应包装类示例（分页场景，字段名以 `_design/api_client_signature.dart` 中 PageResp 定义为准）：

```dart
// announce_list_resp.model.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'announce.model.dart';

part 'announce_list_resp.model.freezed.dart';
part 'announce_list_resp.model.g.dart';

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

## 7. 不做什么

- ❌ 不自动跑 build_runner
- ❌ 不修改 pubspec.yaml
- ❌ 不生成 fromJson/toJson 自定义逻辑（交给 json_serializable）
- ❌ 不生成 Repository（交给 flutter-api-gen）
- ❌ 不修改已有 model 文件（除非用户明确要求覆盖）
- ❌ 不在 model 内写业务方法（model 是数据，不是行为）
- ❌ 不处理 union types / sealed class（如需要，后续版本支持）

## 8. 自检 Checklist

- [ ] 所有字段有类型（无 dynamic）
- [ ] nullable 字段正确标 `?`
- [ ] 嵌套对象已拆文件
- [ ] 文件名 snake_case，类名 PascalCase
- [ ] freezed 模板包含 part 声明（`.freezed.dart` + `.g.dart`）
- [ ] DateTime 字段类型为 `DateTime` 或 `DateTime?`，非 ISO8601 格式已添加 `@JsonKey`
- [ ] snake_case JSON key 已添加 `@JsonKey(name: ...)` 或项目已配置全局 `field_rename`
- [ ] import 路径正确
- [ ] List 字段用 `List<T>` 不用裸 `List`

## 9. 失败处理

**何时 ask user：**
- 字段类型不确定时
- 检测到将覆盖已有 model 文件时
- 枚举值需要确认时
- 嵌套深度 > 2 层时

**何时 stop：**
- JSON 格式非法
- .md 文件不存在或内容无法解析
- URL 抓取失败

**何时 rollback：**
- 自检失败 → 删除本次新增的文件
- 写入中失败 → 如有 git，`git checkout` 恢复；如无 git，删除不完整文件

## 10. 联动

**成功后建议：**
> "Model 生成完成。建议下一步用 `flutter-api-gen` 生成 Repository。"

**失败后回退：**
> "解析失败。请检查输入格式，或回到 `flutter-api-design` 检查契约。"

**上游：** flutter-api-design
**下游：** flutter-api-gen
