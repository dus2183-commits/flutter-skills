---
name: flutter-migrate
description: 模块重命名/移动/删除 — 批量改 import、路由、binding、mock 路径。用户说"重命名模块"、"移动页面"、"删除模块"时触发。安全重构,不留断引用。
type: skill
stage: 5
model: sonnet
priority: P1
version: 1.0.0
owner: @lead
category: mutator
---

# 模块迁移 (flutter-migrate)

## 1. 触发场景

- "把 announce 模块改名成 notification"
- "删除 XX 模块"
- "把这个页面从 A 模块移到 B 模块"
- "合并两个模块"

**反例:**
- "重构代码逻辑" → 手动
- "改字段名" → 改 model + build_runner

## 2. 前置必读

- `lib/features/` (模块目录结构)
- `lib/app/routes/app_routes.dart` + `app_pages.dart`
- `pubspec.yaml` (mock assets)
- `docs/api/` + `docs/specs/` + `docs/plans/`

## 3. 输入

**必填:**
- `action` — rename / move / delete
- `source` — 原模块名或文件路径
- `target` — 新名字或目标位置 (delete 时不需要)

## 4. 工作流程

**Step 1 — 扫描影响范围**
列出所有受影响的文件:
- `lib/features/{module}/` 下所有文件
- `lib/app/routes/` 中的路由引用
- `lib/app/locales/` 中的翻译文件
- `mock/{module}/` 中的 mock 数据
- `docs/` 中的文档
- `pubspec.yaml` 中的 mock assets
- `test/` 中的测试文件

**Step 2 — Dry-run (AskUser)**
列出所有将执行的操作 (移动/重命名/删除哪些文件,修改哪些引用)。

**Step 3 — 执行**
按以下顺序:
1. 移动/重命名文件
2. 批量替换 import 路径
3. 更新路由 (app_routes.dart + app_pages.dart)
4. 更新 pubspec.yaml mock 路径
5. 更新 docs 引用
6. 移动/重命名 mock JSON

**Step 4 — 验证**
```bash
fvm flutter analyze --no-pub
```

**Step 5 — 自检**

## 5. 输出产物

无新文件 — 修改现有文件 + 移动/重命名/删除。

## 6. 代码模板

**rename 示例: announce → notification**

影响清单:
```
移动:
  lib/features/announce/ → lib/features/notification/
  mock/announce/ → mock/notification/
  docs/api/announce.md → docs/api/notification.md
  docs/specs/announce.md → docs/specs/notification.md

替换 (全局):
  'announce' → 'notification'  (文件名、类名、路由、import)
  'Announce' → 'Notification'  (PascalCase)
  'ANNOUNCE' → 'NOTIFICATION'  (如有常量)

修改:
  app_routes.dart: Routes.announceList → Routes.notificationList
  app_pages.dart: import 路径 + 类名
  pubspec.yaml: mock/announce/ → mock/notification/
```

## 7. 不做什么 (Boundary)

- ❌ 不改业务逻辑
- ❌ 不改 model 字段名 (那需要 build_runner)
- ❌ 不改后端接口路径 (只改前端引用)
- ❌ 不改 git history
- ❌ 不自动 commit (让用户确认后手动 commit)

## 8. 自检 Checklist

- [ ] `dart analyze` 0 errors
- [ ] `grep -r` 旧名字在 lib/ 下无残留
- [ ] 路由正确 (旧路由已删,新路由已加)
- [ ] mock JSON 已移动
- [ ] pubspec.yaml mock 路径已更新
- [ ] docs 引用已更新

## 9. 失败处理

**ASK_USER:** 发现跨模块依赖时 (A 模块 import 了 B 模块的 model)
**STOP:** 目标名字已存在
**ROLLBACK:** `git checkout .` 恢复所有改动

## 10. 联动

**上游:** 用户手动触发
**下游:** flutter-review (检查迁移后代码规范)
