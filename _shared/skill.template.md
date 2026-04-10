# SKILL.md 标准 10 段格式（L4 Worker Skill）

> 所有 L4 worker skill 的 SKILL.md 必须遵循此格式。
> Workflow (L5/L6) 用 `workflow.template.md` 12 段格式,不在此列。

---

## Frontmatter 字段

```yaml
---
name: flutter-xxx              # 必填,kebab-case,与目录名一致
description: |                  # 必填,一句话,Claude 据此自动触发
  用户说"做 XX"或"生成 XX"时触发。
  本 skill 的功能是 ...。
type: skill                     # 必填,固定值 "skill"
stage: 0|1|2|3|4|5|6           # 必填,所属流水线阶段
model: opus|sonnet|haiku        # 必填,执行模型
priority: P0|P1|P2              # 必填,优先级
version: 1.0.0                  # 必填,SemVer
owner: @lead|@b|@c              # 必填,负责人
category: |                     # 必填,6 选 1
  designer|generator|bridge|validator|mutator|transformer
---
```

**Stage 含义：**
- 0 = Foundation (init / context-update / health-check)
- 1 = Spec (spec)
- 2 = Plan (plan)
- 3 = Design (api-design / theme-design)
- 4 = Generate (model-gen / api-gen / page-gen / widget-gen / design-to-code)
- 5 = Verify (review / test-gen / lint-fix)
- 6 = Deliver (api-doc / changelog / release)

**Category 含义：**
- `designer` — 生成结构化设计文档（spec/plan/api-design）
- `generator` — 生成新代码文件
- `bridge` — 调用外部系统（Figma MCP）
- `validator` — 检查不修改（review/health-check）
- `mutator` — 修改现有文件（context-update/lint-fix）
- `transformer` — 格式转换（api-doc/changelog）

---

## 正文 10 段

### 段 1: 触发场景

列出 **3-5 个** 用户可能说的触发短语。让 Claude 能精准识别。

```markdown
## 1. 触发场景

- "做一个 XX 模块" / "实现 XX 功能"
- "生成 XX 接口" / "把这个 JSON 转成实体"
- "评审一下 XX" / "检查 XX 代码"
```

**写作要点：**
- 用真实用户语言,不要写太正式
- 包含中英文混合的可能（因为开发者会用）
- 不要太宽泛（"做事情"），也不要太窄（具体函数名）

---

### 段 2: 前置必读

列出本 skill 调用前必须读的文件。Claude 会先 Read 这些再开工。

```markdown
## 2. 前置必读

- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `docs/_context/decisions.md`
- (上游 artifact,如 `docs/specs/{module}.md`)
```

**写作要点：**
- 总是包含 4 个 context pack 文件
- 如果依赖上游 artifact,明确写路径模板
- 不要列太多（>10 个会浪费 token）

---

### 段 3: 输入

明确这个 skill 接受什么参数。

```markdown
## 3. 输入

**必填参数：**
- `module_name` (string) — 模块英文名,snake_case
- `spec_path` (path) — 上游 spec 文件路径

**可选参数：**
- `force_overwrite` (bool, default false) — 是否覆盖已有文件

**输入分流：**
- 如果输入是 JSON 字符串 → 走路径 A
- 如果输入是 .md 文件路径 → 走路径 B
- 如果输入是 URL → 走路径 C
```

---

### 段 4: 工作流程

按 Step 列出每一步具体动作。这是 SKILL.md 的核心。

```markdown
## 4. 工作流程

**Step 1 — 读取上下文**
读取段 2 列出的所有前置文件。

**Step 2 — 确认参数**
和用户确认 `module_name` 等关键参数。
如果模糊,用 AskUserQuestion。

**Step 3 — Dry-run**
列出将创建/修改的文件,让用户确认。

**Step 4 — 执行**
按确认结果生成文件。

**Step 5 — 自检**
跑段 8 的 checklist。

**Step 6 — 输出总结**
告诉用户做了什么 + 下一步建议。
```

**写作要点：**
- Step 数量控制在 4-8 之间
- 每步描述清晰,不要含糊
- 标注哪步会 ask user,哪步会调 tool
- 危险操作前必有 dry-run 步骤

---

### 段 5: 输出产物

明确生成什么文件,在哪。

```markdown
## 5. 输出产物

```
lib/features/{module}/
├── data/
│   ├── models/
│   │   └── {entity}.model.dart
│   └── repositories/
│       └── {module}_repository.dart
└── presentation/
    └── pages/
        └── {page}_page.dart
```

或:

| 文件 | 说明 |
|---|---|
| `docs/specs/{module}.md` | 需求文档 |
| `mock/{module}/list.json` | mock 数据 |
```

---

### 段 6: 代码模板 / 文档模板

**最关键的一段。** 给出真实可复用的代码或文档模板。B/C 看完能直接照抄。

```markdown
## 6. 代码模板

```dart
// {module}_repository.dart
class XxxRepository extends GetxService {
  final ApiClient _api = Get.find();
  
  Future<List<Xxx>> getList() async {
    try {
      return await _api.getList<Xxx>(
        path: '/api/xxx/list',
        pageReq: PageReq(),
        mockKey: 'xxx/list',
        fromJson: Xxx.fromJson,
      );
    } on AppException catch (e) {
      // ...
    }
  }
}
```
```

**写作要点：**
- 必须可运行（不能伪代码）
- 必须用项目约定的 API（ApiClient 而非 Dio）
- 必须包含错误处理
- 必须包含 import（让用户知道引哪些包）

---

### 段 7: 不做什么 (Boundary)

明确这个 skill **不做** 什么,避免 Claude 越界。

```markdown
## 7. 不做什么

- ❌ 不会自动 git commit（用户决定何时 commit）
- ❌ 不会修改未涉及的文件（不重构现有代码）
- ❌ 不会跨模块改动（只改 lib/features/{module}/）
- ❌ 不会自动发布 npm/pub（不上传任何资源）
- ❌ 不会改 .env / .git / pubspec.yaml（除非明确要求）
```

**写作要点：**
- 至少 3 条
- 越具体越好
- 防御性写,不要怕"显得啰嗦"

---

### 段 8: 自检 Checklist (Quality Gate)

skill 完成前必须自检的项目。失败则 stop 或 ask user。

```markdown
## 8. 自检 Checklist

- [ ] 所有生成的 .dart 文件能 `dart analyze` 通过
- [ ] 文件路径符合 conventions.md 目录约定
- [ ] 类命名 PascalCase,文件名 snake_case
- [ ] 调用了 ApiClient,没有直接 new Dio()
- [ ] 错误处理用了 AppException,没有 throw String
- [ ] 列表用了 ListView.builder,不是 ListView(children:)
- [ ] 没有硬编码中文字符串(用 .tr)
```

**写作要点：**
- 4-8 条
- 每条都可机器验证（不要"代码优雅"这种）
- 失败应该是确定性的（不靠 AI 主观判断）

---

### 段 9: 失败处理

定义失败时的行为。

```markdown
## 9. 失败处理

**何时 ask user：**
- 输入参数模糊或缺失
- 检测到将覆盖已有文件
- 上游 artifact 不存在或格式不对

**何时 stop：**
- bash 命令返回非 0
- self-check 有任何 ❌
- 文件系统错误

**何时 rollback：**
- 写入过程中失败 → `git stash`(如有 git)
- self-check 失败 → 删除本次新增的文件
```

---

### 段 10: 联动

成功后建议下一个 skill,失败时提示如何回退。

```markdown
## 10. 联动

**成功后建议：**
> "Model 生成完成。建议下一步用 `flutter-api-gen` 生成 Repository。"

**失败后回退：**
> "解析失败。请检查输入 JSON 格式,或回到 `flutter-api-design` 重新设计契约。"

**上游：** flutter-api-design
**下游：** flutter-api-gen
```

---

## 完整示例（缩略版）

```markdown
---
name: flutter-model-gen
description: 把 JSON 样本或接口契约转成 freezed Dart 实体类。触发: "JSON 转实体" / "生成 model"。
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
- "把这个 JSON 转成 Dart"
- "生成 XX 模块的 model"
- "根据接口文档生成实体"

## 2. 前置必读
- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `docs/api/{module}.md` (如有)

## 3. 输入
**必填:**
- `module_name` (string)
- `source` — JSON 字符串 / .md 路径 / URL

**输入分流:**
- JSON → 直接解析
- .md → 提取接口契约
- URL → fetch + 解析

## 4. 工作流程
**Step 1** — 读 context
**Step 2** — 解析输入,识别字段
**Step 3** — 推断类型(可空/嵌套/枚举/DateTime)
**Step 4** — 嵌套对象拆文件
**Step 5** — Dry-run 列出将创建的文件
**Step 6** — 用户确认
**Step 7** — 写入 freezed 模板
**Step 8** — 自检
**Step 9** — 提示运行 build_runner

## 5. 输出产物
```
lib/features/{module}/data/models/
├── {entity}.model.dart
└── {entity}.model.freezed.dart  (build_runner 生成)
```

## 6. 代码模板
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '{entity}.model.freezed.dart';
part '{entity}.model.g.dart';

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

## 7. 不做什么
- ❌ 不自动跑 build_runner
- ❌ 不修改 pubspec.yaml
- ❌ 不生成 fromJson 自定义逻辑(交给 json_serializable)

## 8. 自检 Checklist
- [ ] 所有字段有类型
- [ ] nullable 字段正确标 ?
- [ ] 嵌套对象拆文件
- [ ] 文件名 snake_case,类名 PascalCase
- [ ] freezed 模板包含 part 声明
- [ ] DateTime 用 ISO8601 解析

## 9. 失败处理
**ask user:** JSON 解析模糊时(字段类型不确定)
**stop:** JSON 格式非法
**rollback:** 自检失败时删除新增文件

## 10. 联动
**成功后:** 提示 `flutter-api-gen` 生成 Repository
**失败:** 回到 `flutter-api-design` 检查契约
**上游:** flutter-api-design
**下游:** flutter-api-gen
```

---

## 写作 9 条铁律

1. **Description 必须精确** — Claude 靠这个判断要不要触发,模糊则 miss
2. **代码模板必须可运行** — 不允许伪代码
3. **段 7 边界写满** — 防止 skill 越界
4. **段 8 自检可机器验证** — 不要"代码优雅"这种主观项
5. **段 9 失败路径全覆盖** — ask/stop/rollback 三种情况都要写
6. **段 10 上下游明确** — 让 orchestrator 能编排
7. **总长度 200-500 行** — 太短信息不全,太长 token 浪费
8. **示例代码用项目约定 API** — ApiClient 而非 Dio
9. **中文写作专业** — 不要"嗯""的话""感觉"等口语
