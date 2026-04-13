---
name: flutter-changelog
description: 从 git log 生成 CHANGELOG.md。用户说"生成 changelog"、"更新变更日志"时触发。按 Conventional Commits 解析,输出 Keep a Changelog 格式。
type: skill
stage: 6
model: haiku
priority: P1
version: 1.0.0
owner: @b
category: transformer
---

# 变更日志生成 (flutter-changelog)

## 1. 触发场景

- "生成 changelog" / "更新变更日志"
- "generate changelog"
- "写 changelog"
- flutter-release Step 4 自动调用

## 2. 前置必读

- `docs/_context/conventions.md`

> 本 skill 仅解析 git log，不涉及代码生成，无需 tech-stack / glossary 等文件。

## 3. 输入

**必填参数：**
- `version` (string) — 新版本号，SemVer 格式（如 `1.2.0`）

**可选参数：**
- `tag_from` (string, default: 自动检测上一个 tag) — 起始 tag
- `output_path` (string, default: `CHANGELOG.md`) — 输出文件路径

## 4. 工作流程

**Pipeline:** 读 context → 获取 git log → 解析分类 → dry-run → 写入 → 自检

**Step 1 — 读 context**
读取段 2 列出的前置文件。

**Step 2 — 获取 git log 范围**

```bash
# 获取上一个 tag
git describe --tags --abbrev=0

# 获取 commit 列表（排除 merge commit）
git log {tag}..HEAD --no-merges --format="%H|%s"
```

如果没有 tag → AskUser 是否用首次 commit 作为起点。

**Step 3 — 解析分类**

按段 6 的映射表，对每条 commit message：
1. 匹配 `type(scope): description` 或 `type: description` 格式
2. 提取 type 和 description（去掉前缀，只保留描述内容）
3. 按 type 归入对应 CHANGELOG 分类
4. `chore` / `ci` / `test` / `style` / `build` 类型跳过
5. 不符合规范的 commit 归入 Other
6. `!` 后缀（如 `feat!:`）归入 Breaking Changes；commit body 中的 `BREAKING CHANGE` footer 不检测（仅解析 subject line）

**Step 4 — Dry-run (AskUser)**
展示将写入的 changelog 内容。

使用 AskUserQuestion 提供三个选项：
1. **确认生成** — 进入 Step 5
2. **不要生成** — stop
3. **补充修改** — 用户修改后重新 dry-run

**Step 5 — 写入 CHANGELOG.md**
- 如果文件不存在，先创建并写入 `# Changelog\n\n`
- 新版本段插入到 `# Changelog` 标题之后、旧版本之前
- 保留所有历史版本内容

**Step 6 — 自检**
跑段 8 checklist，逐项验证。

## 5. 输出产物

    CHANGELOG.md   — 追加新版本段到顶部

## 6. 文档模板

**Conventional Commits → Keep a Changelog 映射：**

| commit 前缀 | CHANGELOG 分类 |
|---|---|
| `feat:` / `feat(xxx):` | Added |
| `fix:` / `fix(xxx):` | Fixed |
| `docs:` / `docs(xxx):` | Documentation |
| `refactor:` / `perf:` | Changed |
| `BREAKING CHANGE` / `feat!:` / `fix!:` | Breaking Changes |
| `chore:` / `ci:` / `test:` / `style:` / `build:` | 跳过 |
| 不符合规范的 commit | Other |

**输出示例：**

`````markdown
## [1.2.0] - 2026-04-11

### Breaking Changes
- 移除旧版消息推送接口

### Added
- 新增消息列表分页加载
- 新增公告已读标记功能

### Fixed
- 修复网络超时未正确捕获的问题

### Changed
- 重构消息 Repository 依赖注入方式

### Documentation
- 更新 API 接口契约文档
`````

**格式规则：**
- 版本标题格式: `## [{version}] - {YYYY-MM-DD}`
- 分类标题格式: `### {Category}`
- 条目格式: `- {description}`（去掉 commit 前缀，首字母保持原样）
- 分类顺序: Breaking Changes → Added → Fixed → Changed → Documentation → Other
- 空分类不输出
- 日期取当天（`date +%Y-%m-%d`）

## 7. 不做什么

- ❌ 不自动 git commit / tag / push
- ❌ 不修改 pubspec.yaml 版本号（那是 flutter-release 的事）
- ❌ 不处理 merge commit（`--no-merges`）
- ❌ 不翻译 commit message（原文保留）
- ❌ 不生成完整历史（只生成 tag..HEAD 范围）
- ❌ 不覆盖已有 CHANGELOG.md 内容（只追加）

## 8. 自检 Checklist

- [ ] 版本号符合 SemVer（`x.y.z`）
- [ ] 日期格式 YYYY-MM-DD
- [ ] 至少有一个分类非空（否则无意义）
- [ ] 新版本段插入位置正确（`# Changelog` 之后、旧版本之前）
- [ ] 没有重复的版本号（与已有版本不冲突）
- [ ] 跳过了 chore/ci/test/style/build 类型的 commit
- [ ] 条目不以 `feat:` / `fix:` 等 Conventional Commits type 前缀开头

## 9. 失败处理

**何时 ask user：**
- 无 git tag 时（询问是否用首次 commit 作为起点）
- commit 全部被跳过时（无有效内容可写入）
- 检测到版本号与已有 CHANGELOG 中的版本重复时

**何时 stop：**
- 不在 git 仓库中
- git log 命令失败
- version 参数不符合 SemVer

**何时 rollback：**
- 写入中失败 → 恢复 CHANGELOG.md 原内容

## 10. 联动

**成功后建议：**
> "CHANGELOG.md 已更新 v{version}。请检查内容，确认后可 git commit。"

**失败后回退：**
> "生成失败。请确认当前在 git 仓库中且有可用的 tag。"

**上游：** flutter-release（Step 4 调用）/ 用户直接触发
**下游：** 无（手动 git commit）
