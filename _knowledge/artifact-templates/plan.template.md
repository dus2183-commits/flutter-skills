---
artifact_type: plan
module: {{module_name}}
version: 1
created: {{YYYY-MM-DD}}
created_by: flutter-plan
author: {{author}}
parent_artifact: docs/specs/{{YYYYMMDD}}-{{author}}-{{需求名}}.md
status: draft
owner: @{{owner}}
---

# {{module_chinese_name}} - 实施计划

> 本文档由 `flutter-plan` 从 spec 自动拆解生成。
> 文件命名: `{YYYYMMDD}-{作者名}-{需求名}.md`
> 下游: `docs/api/{{module_name}}.md`(由 flutter-api-design 生成)

---

## 任务清单

按 6 类拆分。每个任务对应 1 个 worker skill 调用。

### A. 接口契约设计 (使用 flutter-api-design)

- [ ] **A1**. 设计 {{N}} 个接口契约
  - 工作量: S
  - 输出: `docs/api/{{module_name}}.md` + mock JSON 草稿

---

### B. 主题/颜色补充 (使用 flutter-theme-design)

- [ ] **B1**. 检查是否需要新颜色/字号
  - 工作量: S
  - 输出: 更新 `lib/app/theme/colors.dart` 或 `text_styles.dart`
  - 可跳过(若无新颜色)

---

### C. Model 生成 (使用 flutter-model-gen)

- 依赖: A1 完成
- [ ] **C1**. {{Entity1}} 实体
  - 工作量: S
  - 输出: `lib/features/{{module}}/data/models/{{entity1}}.model.dart`
- [ ] **C2**. {{Entity2}} 实体(如有)
  - 工作量: S
- [ ] **C3**. 列表请求/响应 DTO

---

### D. Repository 生成 (使用 flutter-api-gen)

- 依赖: A1, C1, C2 完成
- [ ] **D1**. {{Module}}Repository ({{N}} 个方法)
  - 工作量: M
  - 输出: 
    - `lib/features/{{module}}/data/repositories/{{module}}_repository.dart`
    - `lib/features/{{module}}/data/repositories/{{module}}_repository.binding.dart`
- [ ] **D2**. Mock JSON 数据
  - 工作量: S
  - 输出: `mock/{{module}}/*.json`

---

### E. 页面生成 (使用 flutter-page-gen)

- 依赖: D1 完成 (Mock 模式可立即开始)
- [ ] **E1**. {{Page1}}Page (列表类型)
  - 工作量: M
  - 输出:
    - `lib/features/{{module}}/presentation/pages/{{page1}}/{{page1}}_page.dart`
    - `lib/features/{{module}}/presentation/pages/{{page1}}/{{page1}}_controller.dart`
    - `lib/features/{{module}}/presentation/pages/{{page1}}/{{page1}}_binding.dart`
- [ ] **E2**. {{Page2}}Page (详情类型)
  - 工作量: M
- [ ] **E3**. 路由注册
  - 工作量: S
  - 输出: 修改 `lib/app/routes/app_routes.dart` + `app_pages.dart`

---

### F. 公共组件提取 (使用 flutter-widget-gen)

- 依赖: E 完成后可识别
- [ ] **F1**. {{Widget1}} (如需复用)
  - 工作量: S
  - 输出: `lib/shared/widgets/` 或 `lib/features/{{module}}/presentation/widgets/`
- 通常 F 类任务可省略

---

### G. 评审 (使用 flutter-review)

- 依赖: 所有上述任务完成
- [ ] **G1**. 整体评审
  - 工作量: S
  - 输出: `docs/review/{{YYYY-MM-DD}}-{{module}}.md`

---

## 依赖图

```
A1 ──┬─→ C1 ──┐
     ├─→ C2 ──┼─→ D1 ──┬─→ E1 ─┐
     └─→ C3 ──┘    D2  ├─→ E2 ─┤
                       └─→ E3 ─┴─→ G1
B1 ─────────────────────────────┘
```

(标 mock 先行点: D2 完成后 E1/E2 可立即开始,无需等真实接口)

---

## Mock 先行说明

D2 (Mock JSON) 完成后,前端可以立即开始 E 系列页面开发,
无需等待后端真实接口就绪。

切换:
- 开发期: `flutter run --dart-define=USE_MOCK=true`
- 联调期: `flutter run --dart-define=USE_MOCK=false`

---

## 工作量汇总

| 类别 | 任务数 | 估计工作量 |
|---|---|---|
| A 接口契约 | 1 | S (~30min) |
| B 主题 | 0-1 | S |
| C Model | 2-4 | S each |
| D Repository | 2 | M (~1h) |
| E 页面 | 2-4 | M each |
| F 组件 | 0-1 | S |
| G 评审 | 1 | S |
| **合计** | **8-13** | **半天-1 天** |

---

## Quality Gate G2 自检

- [ ] 所有任务有 [ ] checkbox
- [ ] 依赖关系明确
- [ ] 标注 mock 先行点
- [ ] 每个任务工作量 ≤ M
- [ ] 总任务数 ≤ 15(过多说明 spec 拆分太细)
