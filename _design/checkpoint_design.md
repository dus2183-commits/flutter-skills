# Checkpoint 机制详细设计

> Checkpoint 让 workflow 可中断、可恢复、可回退。
> 没有 checkpoint,跑到第 8 步失败要从头来,3 人组没人受得了。

---

## 1. Checkpoint 是什么

**定义：** workflow 执行过程中,在每个 state transition 后写入磁盘的"快照",记录:
- 当前状态机位置
- 已完成的 skill 调用
- 已生成的 artifact 路径
- Reflector 决策历史

**核心价值：** workflow 中断后,可以从 checkpoint 恢复,跳过已完成步骤。

---

## 2. Checkpoint 何时需要

### 2.1 失败恢复
```
workflow 跑到第 6 步 (api-gen) 失败
→ 用户排查问题
→ 修复
→ 用户说"继续公告模块"
→ 从 checkpoint 恢复,跳过前 5 步,从 api-gen 重试
```

### 2.2 主动暂停
```
workflow 跑到第 4 步,用户说"先停一下,我开个会"
→ Conductor 写 PAUSED checkpoint
→ 一小时后用户回来说"继续"
→ 从 PAUSED 恢复
```

### 2.3 跨会话延续
```
今天跑了 spec + plan
→ Claude 会话结束(token 用完)
→ 明天用户开新会话说"继续公告模块"
→ Claude 读 checkpoint,知道做到哪
```

### 2.4 调试和审计
```
workflow 失败了
→ 用户说"showLastFailure"
→ Claude 读 checkpoint,告诉用户每一步的输入输出
```

---

## 3. Checkpoint 文件结构

```
.flow_checkpoint/                            ← 在用户项目根目录
└── {workflow_id}/                           ← 每个 workflow 一个目录
    ├── meta.json                            ← 元信息
    ├── state.json                           ← 当前状态机位置
    ├── transitions.jsonl                    ← 所有 state 转换历史
    ├── artifacts.json                       ← 已生成的 artifact 列表
    ├── skill_calls/                         ← 每个 skill 调用的输入输出
    │   ├── 01-flutter-spec.json
    │   ├── 02-flutter-plan.json
    │   ├── 03-flutter-api-design.json
    │   ├── 04-flutter-model-gen.json
    │   ├── 05-flutter-api-gen.json
    │   └── ...
    ├── reflector/                           ← Reflector 决策记录
    │   ├── 01-spec_review.json
    │   ├── 02-plan_review.json
    │   └── ...
    └── error.log                            ← (如有失败) 错误日志
```

### workflow_id 格式
```
{workflow_name}-{module_name}-{YYYY-MM-DD}-{HHMM}
示例: feature-announce-2026-04-10-1430
```

---

## 4. 各文件 schema

### 4.1 `meta.json`
```json
{
  "workflow_id": "feature-announce-2026-04-10-1430",
  "workflow_name": "flutter-flow-feature",
  "module_name": "announce",
  "created_at": "2026-04-10T14:30:00+08:00",
  "updated_at": "2026-04-10T15:12:34+08:00",
  "user_input": "做一个公告模块,有列表和详情",
  "version": "1.0.0"
}
```

### 4.2 `state.json`
```json
{
  "current_state": "GENERATING",
  "previous_state": "DESIGNING",
  "next_expected_state": "BUILD_CHECK",
  "retry_count": 0,
  "started_at": "2026-04-10T14:30:00+08:00",
  "last_transition_at": "2026-04-10T15:00:00+08:00",
  "is_paused": false,
  "pause_reason": null
}
```

### 4.3 `transitions.jsonl` (append-only)
```jsonl
{"ts":"14:30:00","from":"IDLE","to":"SPEC'ING","trigger":"user_prompt"}
{"ts":"14:32:15","from":"SPEC'ING","to":"SPEC_REVIEW","trigger":"spec_written"}
{"ts":"14:32:18","from":"SPEC_REVIEW","to":"PLANNING","trigger":"reflector_pass"}
{"ts":"14:34:42","from":"PLANNING","to":"PLAN_REVIEW","trigger":"plan_written"}
{"ts":"14:34:45","from":"PLAN_REVIEW","to":"DESIGNING","trigger":"reflector_pass"}
{"ts":"15:00:30","from":"DESIGNING","to":"GENERATING","trigger":"all_designed"}
```

### 4.4 `artifacts.json`
```json
{
  "specs": ["docs/specs/announce.md"],
  "plans": ["docs/plans/announce.md"],
  "api": ["docs/api/announce.md"],
  "code": [
    "lib/features/announce/data/models/announce.model.dart",
    "lib/features/announce/data/repositories/announce_repository.dart"
  ],
  "mock": [
    "mock/announce/list.json",
    "mock/announce/detail.json",
    "mock/announce/markRead.json"
  ],
  "review": []
}
```

### 4.5 `skill_calls/05-flutter-api-gen.json`
```json
{
  "skill": "flutter-api-gen",
  "called_at": "2026-04-10T14:55:00+08:00",
  "completed_at": "2026-04-10T14:58:30+08:00",
  "duration_ms": 210000,
  "status": "success",
  "input": {
    "module": "announce",
    "spec_path": "docs/specs/announce.md",
    "api_path": "docs/api/announce.md"
  },
  "output_files": [
    "lib/features/announce/data/repositories/announce_repository.dart",
    "lib/features/announce/data/repositories/announce_repository.binding.dart"
  ],
  "tokens_used": 4500,
  "model": "sonnet"
}
```

### 4.6 `reflector/04-model_review.json`
```json
{
  "state": "MODEL_REVIEW",
  "artifact": "lib/features/announce/data/models/announce.model.dart",
  "checked_at": "2026-04-10T14:50:00+08:00",
  "strategy": "rule + dart_analyze",
  "result": "PASS",
  "passed": [
    "dart analyze 0 errors",
    "freezed model 模板正确",
    "import 完整",
    "DateTime 字段用 ISO8601"
  ],
  "failed": [],
  "retry_count": 0
}
```

---

## 5. Checkpoint 读写时机

### 5.1 写时机(Conductor 触发)

| 触发点 | 写入 |
|---|---|
| workflow 启动 | meta.json + state.json (initial) |
| state transition 前 | transitions.jsonl 追加 |
| state transition 后 | state.json (更新) |
| skill 调用前 | (无) |
| skill 调用后 | skill_calls/{N}-{name}.json |
| reflector 后 | reflector/{N}-{state}.json |
| artifact 写入后 | artifacts.json (更新) |
| 用户暂停 | state.json (is_paused=true) |
| 致命失败 | error.log (写入) + state.json (状态=ABORT) |

### 5.2 读时机

| 触发短语 | 读取动作 |
|---|---|
| "继续 XX 模块" | 找最近 checkpoint(模糊匹配 module_name) → 读所有文件 |
| "恢复上次工作" | 找最近未完成 checkpoint |
| "查看 XX 模块进度" | 读 transitions.jsonl + state.json |
| "重做 XX 步骤" | 读 checkpoint,从指定 state 重新开始 |

---

## 6. 恢复逻辑详解

```python
def resume_workflow(user_request: str) -> WorkflowExecution:
    # 1. 模糊匹配 checkpoint
    candidates = find_checkpoints(user_request)
    if not candidates:
        ask_user("找不到匹配的 checkpoint,是否重新开始?")
    
    if len(candidates) > 1:
        # 多个候选,让用户选
        ask_user(f"找到 {len(candidates)} 个 checkpoint,选哪个?", candidates)
    
    checkpoint = candidates[0]
    
    # 2. 读所有文件
    meta = read_json(f"{checkpoint}/meta.json")
    state = read_json(f"{checkpoint}/state.json")
    artifacts = read_json(f"{checkpoint}/artifacts.json")
    transitions = read_jsonl(f"{checkpoint}/transitions.jsonl")
    
    # 3. 健康检查
    if state.is_paused:
        # 从 PAUSED 恢复
        resume_from(state.current_state)
    elif state.current_state == "ABORT":
        ask_user("上次 workflow 已 ABORT,是否重新开始?")
    elif state.current_state == "DONE":
        ask_user("上次 workflow 已完成,是否重新跑?")
    else:
        # 从中断点恢复
        ask_user(f"上次跑到 {state.current_state} (重试 {state.retry_count} 次),从这里继续?")
    
    # 4. 验证 artifact 仍存在
    for artifact_list in artifacts.values():
        for artifact in artifact_list:
            if not file_exists(artifact):
                ask_user(f"Artifact {artifact} 已删除,是否重新生成?")
    
    # 5. 恢复执行
    return WorkflowExecution(
        workflow=load_workflow(meta.workflow_name),
        initial_state=state.current_state,
        context={"meta": meta, "artifacts": artifacts}
    )
```

---

## 7. Checkpoint 清理策略

不能让 checkpoint 无限增长。

| 策略 | 何时执行 |
|---|---|
| 完成后 24h 自动删除 | 每次启动 workflow 时扫描 |
| ABORT 后 7 天保留 | 便于排查 |
| 手动 `cleanup-checkpoints` | 用户主动 |
| 大小超 100MB | 强制清理最旧 |

---

## 8. Checkpoint 与 git 的关系

**Checkpoint 不入 git。** 加入 `.gitignore`:
```
.flow_checkpoint/
.flow_log/
docs/_failures/
.telemetry/
```

**为什么不入 git：**
- Checkpoint 是临时状态,不是项目历史
- 多人协作时会冲突
- 体积可能很大

**入 git 的：**
- `docs/specs/`, `docs/plans/`, `docs/api/`, `docs/review/` (artifact 本身)
- `docs/_context/` (上下文)
- 生成的代码

---

## 9. 失败恢复的 4 种模式

### 模式 A: 软失败 — 单步重试
```
api-gen 失败 → reflector RETRY → 重试 1 次成功 → 继续
(checkpoint 不写新条目,只更新 retry_count)
```

### 模式 B: 硬失败 — 用户介入
```
api-gen 重试 2 次仍失败 → reflector ABORT 
→ 写 error.log 
→ 暂停 workflow 
→ 通知用户
→ 用户修复 docs/api/announce.md 
→ 用户说"继续"
→ 从 api-gen 重新开始
```

### 模式 C: 回退到上游
```
review 阶段发现 model 有严重问题 
→ Conductor 决定回退到 GENERATING 阶段
→ 删除 model 相关文件
→ 重新调用 model-gen
→ 流程继续
```

### 模式 D: 部分接受,部分重做
```
8 个 worker 跑完,review 报告 6 个通过 + 2 个有问题
→ 用户决定: 通过的保留,问题的重做
→ Conductor 只对 2 个有问题的重新调用 worker
```

---

## 10. Checkpoint 在 SKILL.md 中的声明

每个 workflow SKILL.md 的第 8 段(Checkpoint 配置):

```markdown
## 8. Checkpoint 配置

**位置:** `.flow_checkpoint/{workflow_id}/`

**写入时机:**
- 启动: meta.json + initial state.json
- transition: transitions.jsonl 追加 + state.json 更新
- skill 完成: skill_calls/{N}-{name}.json
- reflector 完成: reflector/{N}-{state}.json
- artifact 写入: artifacts.json 更新
- 失败: error.log

**恢复触发:** 用户说"继续 {module_name}" 或 "恢复 workflow"

**清理:** 完成后 24h / ABORT 后 7 天
```

---

## 11. 给你(组长)的实现建议

**M3 阶段实现优先级:**

### 阶段 1 (M3 第一天): 最小可用版
- 只写 `meta.json` + `state.json` + `artifacts.json`
- 不做 transitions/skill_calls/reflector 历史
- 只支持"恢复"不支持"回退"

### 阶段 2 (M3 第二天): 完善
- 加 transitions.jsonl
- 加 skill_calls/
- 支持失败恢复

### 阶段 3 (M3 第三天): 高级
- 加 reflector/
- 支持回退到任意 state
- 支持多 checkpoint 选择

**最重要的提示:**
- Checkpoint 文件要小,只存元信息,不存大量代码内容
- 每次写入要原子(temp 文件 + rename),避免半写状态
- 恢复前必须验证 artifact 仍存在(用户可能手动删了)
