# Reflector 详细设计

> Reflector 是 L6 Orchestration 层的"质量检查员"。每个 worker skill 完成后,Reflector 二次评估 artifact 是否合格。
>
> **整个 multi-agent 系统的灵魂。** Conductor 会调,Reflector 才是质量保证。

---

## 1. Reflector 是什么

```
worker skill 跑完
   │
   ▼
产出 artifact (markdown / dart 代码 / json)
   │
   ▼
┌─────────────────────────┐
│      Reflector           │
│                         │
│  1. 读 artifact          │
│  2. 对照 expectation     │
│  3. 返回 4 种结果之一    │
│     ├─ PASS              │
│     ├─ RETRY             │
│     ├─ ASK_USER          │
│     └─ ABORT             │
└─────────────────────────┘
   │
   ▼
Conductor 据此决定下一步
```

**核心价值：** 把"质量判断"从 worker 中剥离。worker 只管生成,Reflector 管对错。

---

## 2. 为什么需要 Reflector(不能让 worker 自己 check)

| 让 worker 自己 check | 用 Reflector |
|---|---|
| worker 既是运动员又是裁判 | 职责分离 |
| worker 容易"自满"(认为自己写得好) | Reflector 视角更冷静 |
| worker 用同一个 prompt 评估,容易盲区 | Reflector 用不同 prompt |
| worker 改动 self-check 逻辑要改 SKILL.md | Reflector 集中改 |
| 难以横向比较多个 worker 输出 | Reflector 标准化 |

**类比：** Code review 不能让作者本人做,要别人 review。Reflector = 别人。

---

## 3. Reflector 的 4 种返回值

### 3.1 PASS
**含义：** artifact 合格,继续下一步。

**Conductor 行为：** state 转到下一个。

**示例：** spec 文档 7 段齐全 + 字段命名合规 + 异常场景 ≥3 → PASS。

---

### 3.2 RETRY
**含义：** artifact 有问题,但可以让 worker 重试。

**Conductor 行为：** retry_count++,若未超上限,重新调用 worker(带上 reflector 的反馈)。

**示例：** 生成的 dart 代码缺少 import → RETRY 让 worker 补上。

**Retry 上限：**
- spec/plan 类 artifact: 2 次
- 代码类 artifact: 1 次
- 检查类 artifact: 不重试

---

### 3.3 ASK_USER
**含义：** 检测到需要人工决策的歧义。

**Conductor 行为：** 暂停 workflow,弹问题给用户。

**示例：**
- spec 中有 2 个可能的字段命名,选哪个？
- model 字段类型推断有歧义(int 还是 long？)
- 检测到将覆盖现有大量代码,确认吗？

---

### 3.4 ABORT
**含义：** 致命错误,无法恢复。

**Conductor 行为：** 写 ABORT checkpoint,终止 workflow,通知用户。

**示例：**
- 上游 artifact 不存在或损坏
- bash 命令返回致命错误码
- worker 重试达到上限仍失败

---

## 4. Reflector 的 3 种策略(按 artifact 类型)

### 4.1 Schema-based Reflection (最可靠)
**适用：** 结构化 artifact (spec/plan/api/review.md)

**原理：** artifact 必须符合预定义 schema(段数/字段/格式),否则失败。

**实现：**
```python
def reflect_schema(artifact_path: str, schema: dict) -> Result:
    content = read(artifact_path)
    
    # 1. 检查 frontmatter 字段全
    fm = parse_frontmatter(content)
    for field in schema['required_frontmatter']:
        if field not in fm:
            return RETRY(f"Missing frontmatter: {field}")
    
    # 2. 检查段数
    sections = parse_sections(content)
    if len(sections) < schema['min_sections']:
        return RETRY(f"Need {schema['min_sections']} sections, got {len(sections)}")
    
    # 3. 检查具体段内容
    for section_name, requirements in schema['sections'].items():
        section = find_section(sections, section_name)
        if requirements.get('min_items') and count_items(section) < requirements['min_items']:
            return RETRY(f"Section {section_name} need {requirements['min_items']} items")
    
    return PASS
```

**优点：** 确定性强,无 AI 主观性。
**缺点：** 只能检查格式,不能检查内容质量。

---

### 4.2 Rule-based Reflection (代码 lint)
**适用：** dart 代码文件

**原理：** 跑工具 + 字符串匹配,机械检查。

**实现：**
```python
def reflect_dart_code(file_path: str) -> Result:
    # 1. dart analyze
    result = bash(f"dart analyze {file_path}")
    if result.exit_code != 0:
        return RETRY(f"dart analyze failed: {result.stderr}")
    
    # 2. 必须 import ApiClient(若是 repository)
    content = read(file_path)
    if 'extends GetxService' in content and 'ApiClient' not in content:
        return RETRY("Repository must use ApiClient")
    
    # 3. 必须 catch AppException
    if 'catch (e)' in content and 'on AppException' not in content:
        return RETRY("Must catch AppException, not raw Exception")
    
    # 4. 不能直接 import 'package:dio/dio.dart' (除非 type 引用)
    if "import 'package:dio/dio.dart'" in content and 'show CancelToken' not in content:
        return RETRY("Should not import dio directly, use ApiClient")
    
    # 5. 列表必须 ListView.builder
    if 'ListView(' in content and 'children:' in content:
        return RETRY("Use ListView.builder for lists")
    
    return PASS
```

**优点：** 快,不耗 token。
**缺点：** 写规则要思考,新规则要更新代码。

---

### 4.3 LLM-based Reflection (内容质量)
**适用：** 需要主观判断的内容(spec 是否完整、review 是否漏检)

**原理：** 调用 sonnet,用专门的 reflector prompt 评估。

**Prompt 模板：**
```
你是 Reflector,负责检查 {artifact_type}。

[artifact 内容]
{artifact_content}

[检查标准]
{checklist}

请逐项检查,返回 JSON:
{
  "result": "PASS" | "RETRY" | "ASK_USER" | "ABORT",
  "passed": [list of passed checks],
  "failed": [list of failed checks],
  "reason": "如失败,具体原因",
  "suggestions": ["建议 1", "建议 2"]
}

注意:
- 严格按 checklist,不要主观发挥
- RETRY 必须给具体修改建议
- ASK_USER 必须给具体问题
- 不要客气,有问题就报
```

**优点：** 能检查内容质量。
**缺点：** 耗 token,不确定性高。

---

## 5. Reflector 调用时机表

| Workflow | State | Artifact | 策略 | 模型 |
|---|---|---|---|---|
| feature | SPEC_REVIEW | docs/specs/{m}.md | Schema + LLM | sonnet |
| feature | PLAN_REVIEW | docs/plans/{m}.md | Schema + LLM | sonnet |
| feature | API_REVIEW | docs/api/{m}.md | Schema | (无 LLM,纯 lint) |
| feature | MODEL_REVIEW | *.model.dart | Rule + dart analyze | (bash) |
| feature | REPO_REVIEW | *_repository.dart | Rule + dart analyze | (bash) |
| feature | PAGE_REVIEW | *_page.dart 三件套 | Rule + dart analyze | (bash) |
| feature | BUILD_REVIEW | (整个项目) | bash: flutter analyze + build | (bash) |
| feature | FINAL_REVIEW | docs/review/{date}.md | Schema | (无 LLM) |
| design | DESIGN_REVIEW | (代码) | Rule | (bash) |

**经济学：** 80% 用 schema/rule(快),20% 用 LLM(质量)。

---

## 6. Reflector 的反馈机制

Reflector 不只返回 PASS/RETRY,还要给"修复建议"。这些建议会被传给 worker 重试。

### 反馈格式

```json
{
  "result": "RETRY",
  "artifact": "docs/specs/announce.md",
  "passed": [
    "段 1: 目标完整",
    "段 2: 页面列表清晰",
    "段 3: 流转图存在"
  ],
  "failed": [
    "段 6: 异常场景只有 1 条,需要 ≥3 条",
    "段 7: 缺少非功能需求"
  ],
  "suggestions": [
    "在段 6 补充: 网络异常 / 权限不足 / 数据为空 三种场景",
    "在段 7 加: 列表分页 / 详情缓存 / 深链接支持"
  ],
  "reason": "Spec 文档不完整,影响后续生成"
}
```

### Worker 重试时的 prompt 注入

```
你刚才生成的 artifact 被 Reflector 拒绝。
原因: {reason}

请修正以下问题:
{failed}

具体建议:
{suggestions}

重新生成 artifact。
```

---

## 7. Reflector 的状态(不要让它无限循环)

```python
class ReflectorState:
    artifact_path: str
    state_name: str
    retry_count: int
    max_retries: int
    history: List[ReflectorResult]  # 所有重试历史
    
    def can_retry(self) -> bool:
        return self.retry_count < self.max_retries
    
    def should_abort(self) -> bool:
        # 如果连续 2 次返回相同的 failed 列表,说明 worker 修不了
        if len(self.history) >= 2:
            last = self.history[-1].failed
            prev = self.history[-2].failed
            if set(last) == set(prev):
                return True
        return False
```

**关键：** 同样的失败不要无限重试,2 次相同失败 → ABORT 让用户介入。

---

## 8. Reflector 实现的 5 个原则

1. **Reflector 自己不修改 artifact** — 只读不写
2. **Reflector 用比 worker 弱的模型** — sonnet 检查 sonnet 生成,opus 给 conductor 用
3. **Reflector 反馈必须可执行** — "代码不优雅"是垃圾,"段 6 缺 3 条异常场景"才有用
4. **Reflector 必须能处理 retry 循环** — 连续相同失败 → ABORT
5. **Reflector 的 checklist 写在 SKILL.md** — 不要硬编码到 reflector 代码

---

## 9. Reflector 在 SKILL.md 中的声明位置

每个 workflow SKILL.md 的第 7 段(Reflector 配置)声明:

```markdown
## 7. Reflector 配置

**全局设置:**
- 模型: sonnet
- retry 上限: 2
- 触发时机: 每个 worker 完成后

**State 检查标准:**

| State | 策略 | 检查项 |
|---|---|---|
| SPEC_REVIEW | Schema + LLM | 7 段全 / 字段命名 / 异常 ≥3 / 接口 ≥1 |
| PLAN_REVIEW | Schema | 任务有依赖图 / mock 标注 / 任务粒度 |
| API_REVIEW | Schema | mock key / 类型 / 错误码 |
| MODEL_REVIEW | Rule + bash | dart analyze / freezed 模板正确 |
| ... | | |
```

---

## 10. 待你实现的 Reflector 库

```
lib/_reflector/                  ← 不在 template/ 里,在 skill 仓库
├── reflector.dart               主入口
├── strategies/
│   ├── schema_strategy.dart     L1 schema 检查
│   ├── rule_strategy.dart       L2 rule 检查
│   └── llm_strategy.dart        L3 LLM 检查
├── checklists/                  各种 checklist 定义
│   ├── spec_checklist.md
│   ├── plan_checklist.md
│   └── ...
└── prompts/
    └── llm_reflector_prompt.md  共享的 LLM reflector prompt
```

**实现注意：**
- Reflector 是 skill 仓库的内部组件,不是用户项目的代码
- 调用时 Conductor 指定 strategy 和 checklist
- 历史记录写到 checkpoint,可追溯

---

## 11. 完整调用链路示例

```
1. Conductor: state = SPEC'ING
2. Conductor: dispatch(flutter-spec, input=user_msg)
3. flutter-spec: 写入 docs/specs/announce.md
4. Conductor: state = SPEC_REVIEW
5. Conductor: reflect(docs/specs/announce.md, spec_checklist, sonnet)
6. Reflector: 读 artifact,跑 schema check + LLM check
7. Reflector 返回: RETRY,失败原因 = "异常场景只有 1 条"
8. Conductor: retry_count = 1 < max_retries
9. Conductor: dispatch(flutter-spec, input=user_msg, feedback=Reflector 反馈)
10. flutter-spec: 修正,补充异常场景,重写 artifact
11. Conductor: state = SPEC_REVIEW
12. Conductor: reflect(docs/specs/announce.md, ..., sonnet)
13. Reflector 返回: PASS
14. Conductor: state = PLANNING
... (继续)
```

---

## 12. 给你(组长)的实现建议

**M3 阶段(写 6 个 workflow 时)的实现优先级：**

1. **先实现 SchemaStrategy**(最简单,纯 markdown 解析)
2. **然后 RuleStrategy**(调 dart analyze + 字符串匹配)
3. **最后 LLMStrategy**(token 贵,先 mock 一个,真实 LLM 后期接)

**第一版可以这样：**
```python
def reflect(artifact_path, checklist):
    if checklist.has_schema:
        result = schema_check(artifact_path, checklist.schema)
        if result.failed: return result
    if checklist.has_rules:
        result = rule_check(artifact_path, checklist.rules)
        if result.failed: return result
    if checklist.has_llm:
        # 第一版 mock,直接返回 PASS
        # 真实版调 sonnet
        return PASS  # TODO: 接 LLM
    return PASS
```

**Reflector 第一版可以"宽松"** —— 漏检不致命,误报才是灾难。先求不阻塞 workflow,后期再加严。
