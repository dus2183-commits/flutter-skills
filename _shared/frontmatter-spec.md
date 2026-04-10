# SKILL.md Frontmatter 字段规范

> 所有 SKILL.md 都必须有 frontmatter (yaml,用 `---` 分隔)。
> 字段必须严格按下面的规范填写,Claude 据此识别和触发 skill。

---

## 字段总览

```yaml
---
name:          # 必填,kebab-case
description:   # 必填,精确描述触发场景
type:          # 必填,skill 或 workflow
stage:         # 必填,0-6 或 orchestration
model:         # 必填,opus|sonnet|haiku
priority:      # 必填,P0|P1|P2
version:       # 必填,SemVer
owner:         # 必填,@username
category:      # type=skill 时必填,6 选 1
---
```

---

## 字段详解

### name (必填)

- **类型:** string
- **格式:** kebab-case (`flutter-xxx`)
- **规则:**
  - 必须以 `flutter-` 开头
  - 必须与目录名一致
  - 不超过 30 字符
  - 不允许下划线、空格、大写

**正确示例:**
```yaml
name: flutter-spec
name: flutter-flow-feature
name: flutter-design-to-code
```

**错误示例:**
```yaml
name: flutter_spec          # ❌ 用了下划线
name: FlutterSpec           # ❌ 大写
name: spec                  # ❌ 没有 flutter- 前缀
name: flutter-very-long-skill-name-that-exceeds-thirty   # ❌ 太长
```

---

### description (必填) ★ 最关键字段

- **类型:** string (可多行 yaml `|`)
- **作用:** Claude 据此判断是否触发 skill,**模糊则 miss**
- **写法:**
  - 第一句: 用户会说的触发短语
  - 第二句: skill 做什么
  - (可选) 第三句: 什么场景下用

**正确示例:**
```yaml
description: |
  把 JSON 样本或接口契约转成 freezed Dart 实体类。
  用户说"JSON 转实体"、"生成 model"、"根据接口文档生成实体"时触发。
  自动处理嵌套对象、可空字段、枚举、DateTime。
```

**错误示例:**
```yaml
description: 这是一个生成代码的 skill         # ❌ 太宽泛,会与其他 gen skill 冲突
description: model gen                       # ❌ 太短,Claude 无法判断
description: 我能做很多事,包括 ...            # ❌ 第一人称 + 无关信息
```

**写作技巧:**
1. 包含 3-5 个用户可能说的触发短语
2. 中英文混合 (开发者会用)
3. 不要用"AI"、"智能"、"高效"这类无信息词
4. 不要 > 200 字 (节约 token)

---

### type (必填)

- **类型:** enum
- **取值:** `skill` | `workflow`
- **规则:**
  - L4 worker = `skill`
  - L5/L6 编排器 = `workflow`

```yaml
type: skill           # 大多数 SKILL.md
type: workflow        # 6 个 flutter-flow-* 用这个
```

---

### stage (必填)

- **类型:** int 或 string
- **取值:**
  - 0 = Foundation (init / context-update / health-check)
  - 1 = Spec (spec)
  - 2 = Plan (plan)
  - 3 = Design (api-design / theme-design)
  - 4 = Generate (model-gen / api-gen / page-gen / widget-gen / design-to-code)
  - 5 = Verify (review / test-gen / lint-fix)
  - 6 = Deliver (api-doc / changelog / release)
  - `orchestration` = workflow 用这个

```yaml
stage: 4                # L4 skill
stage: orchestration    # L5/L6 workflow
```

---

### model (必填)

- **类型:** enum
- **取值:** `opus` | `sonnet` | `haiku`
- **选择策略:**

| 模型 | 用 | 例子 |
|---|---|---|
| **opus** | 复杂推理 / 评审 / 编排 | spec / plan / review / 所有 workflow |
| **sonnet** | 代码生成 / 文档 | api-design / model-gen / api-gen / page-gen |
| **haiku** | 格式化 / 简单检查 | lint-fix / health-check / changelog |

**成本意识:** 能用 haiku 别用 sonnet,能用 sonnet 别用 opus。

```yaml
model: sonnet
```

---

### priority (必填)

- **类型:** enum
- **取值:** `P0` | `P1` | `P2`
- **含义:**
  - P0 = MVP 必须 (无它系统无法用)
  - P1 = Standard 应该 (无它系统能用但不完整)
  - P2 = Advanced 可选

```yaml
priority: P0
```

---

### version (必填)

- **类型:** SemVer string
- **格式:** `MAJOR.MINOR.PATCH`
- **变更规则:**
  - MAJOR: 破坏性变更 (输入/输出格式变了)
  - MINOR: 新增功能 (向后兼容)
  - PATCH: bug 修复

```yaml
version: 1.0.0
version: 2.1.3
```

---

### owner (必填)

- **类型:** string
- **格式:** `@username`
- **取值:** `@lead` / `@b` / `@c`

```yaml
owner: @lead
```

---

### category (type=skill 时必填)

- **类型:** enum
- **取值:** 6 选 1
  - `designer` — 生成结构化设计文档
  - `generator` — 生成新代码
  - `bridge` — 调外部系统
  - `validator` — 检查不修改
  - `mutator` — 修改现有文件
  - `transformer` — 格式转换

```yaml
category: generator
```

**workflow 不需要这个字段。**

---

## 完整示例

### Skill 示例 (L4)

```yaml
---
name: flutter-model-gen
description: |
  把 JSON 样本或接口契约转成 freezed Dart 实体类。
  用户说"JSON 转实体"、"生成 model"、"根据接口文档生成实体"时触发。
  自动处理嵌套对象、可空字段、枚举、DateTime。
type: skill
stage: 4
model: sonnet
priority: P0
version: 1.0.0
owner: @b
category: generator
---
```

### Workflow 示例 (L5/L6)

```yaml
---
name: flutter-flow-feature
description: |
  Flutter 功能开发主流水线。用户说"做一个 XX 模块"、"实现 XX 功能"、
  "新需求 XX"时触发。自动编排 spec → plan → ... → review 全流程,
  完整产出可运行的 Flutter 模块代码。
type: workflow
stage: orchestration
model: opus
priority: P0
version: 1.0.0
owner: @lead
---
```

---

## description 写作进阶 (避免触发冲突)

### 问题: 多个 skill 描述太相似

```yaml
# ❌ 这两个会打架
description: 生成 Flutter 代码     # flutter-init
description: 生成 Flutter 代码     # flutter-page-gen
```

### 解决: 描述要包含"边界"

```yaml
# ✅ 明确边界
description: |
  初始化新 Flutter 项目脚手架(从 0 开始)。
  仅在空目录或新建项目场景使用。
  
description: |
  在已存在的 Flutter 项目中生成单个页面。
  仅在 docs/specs/ 已有 spec 时使用。
```

### 用"反例"标注

```yaml
description: |
  评审 Flutter 代码。
  触发: "评审"、"检查代码"。
  反例: 不用于生成代码 (用 page-gen) / 不用于初始化 (用 init)。
```

---

## Frontmatter 验证

写完 SKILL.md 后跑这些检查:

1. **格式合法**
   ```bash
   yamllint {SKILL.md 的 frontmatter 部分}
   ```

2. **字段全**
   ```bash
   grep -E "^(name|description|type|stage|model|priority|version|owner):" SKILL.md | wc -l
   # 应该 ≥ 8 (workflow) 或 9 (skill)
   ```

3. **name 与目录一致**
   ```bash
   DIR=$(basename $(dirname SKILL.md))
   NAME=$(grep "^name:" SKILL.md | cut -d' ' -f2)
   [ "$DIR" == "$NAME" ] || echo "❌ name 不匹配目录"
   ```

4. **description 不太短**
   ```bash
   DESC_LEN=$(grep -A 5 "^description:" SKILL.md | wc -c)
   [ "$DESC_LEN" -gt 50 ] || echo "⚠️ description 太短"
   ```

---

## Frontmatter 反模式

| ❌ 反模式 | ✅ 应该 |
|---|---|
| `description: 这是一个 Flutter skill` | 包含具体触发短语和功能 |
| `name: my_skill` | `name: flutter-my-skill` |
| `version: 0.0.1` | 第一版直接 `1.0.0` |
| 没写 owner | 必填 |
| `model: claude-3-opus` | `model: opus` (简称) |
| 用大写 / 中文 / 空格的 name | kebab-case |
