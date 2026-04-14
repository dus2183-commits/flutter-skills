---
name: flutter-rollback
description: 回退到某个 manifest 版本的代码快照。用户说"回退到 v2"、"撤销上次生成"、"恢复之前的代码"时触发。支持整批回退(所有模块)或单模块回退(如只回 post 模块,保留 auth)。基于 flow-feature 生成前的 .flow_checkpoint/gen-v{N}/ 快照。
type: skill
stage: 9
model: haiku
priority: P1
version: 1.0.0
owner: @tg
category: governance
---

# 代码快照回退 (flutter-rollback)

## 1. 触发场景

- "回退到 v2" / "回到 manifest v1 生成前"
- "撤销上次生成"
- "恢复 post 模块到上一版"
- "生成错了,回去重来"
- "列一下有哪些快照"

**反例(不要用这个 skill)**:
- Git 层面的回退 → 用 git 本身(`git reset` / `git checkout`)
- 单文件撤销 → 用编辑器 Undo 或 git

## 2. 前置必读

- `.flow_checkpoint/gen-v*/` — 快照目录,由 flow-feature 生成前自动创建
- `.flow_checkpoint/manifest.log` — 版本-时间对照表

## 3. 输入

**方式 A:列版本**
```
/flutter-rollback
/flutter-rollback list
```
输出:
```
版本      生成时间           模块
gen-v1   2026-04-14 10:00  auth, post
gen-v2   2026-04-14 15:30  user, comment
gen-v3   2026-04-15 09:00  auth(覆盖 v1 auth)
```

**方式 B:整批回退**
```
/flutter-rollback v2
```
恢复 `.flow_checkpoint/gen-v2/` 快照的**所有**文件(回到 v2 生成前的状态)。

**方式 C:单模块回退**
```
/flutter-rollback v2 post
```
只从 `gen-v2` 快照中恢复 `post` 模块相关文件,其他模块保持现状。

## 4. 快照结构(flow-feature 生成前创建)

    .flow_checkpoint/gen-v{N}/
    ├── snapshot.tar.gz           ← 被本次 manifest 触及的所有文件(生成前状态)
    ├── modules.json              ← 本次生成的模块清单 ["auth", "post"]
    ├── touched_files.txt         ← 本次会新增/修改的文件路径列表
    └── manifest-v{N}.yaml        ← 对应 manifest 副本(便于对照)

**关键原则:** 快照只存**会被覆盖的文件**生成前状态,不拷整个 `lib/`。如果是新增文件(原本不存在),`touched_files.txt` 标记 `[NEW]`,回退时删除即可。

## 5. 执行步骤

### 方式 A — list

1. `ls .flow_checkpoint/gen-v*/` 按版本号排序
2. 每个读 `modules.json` 拿模块清单
3. 读 `manifest.log` 拿时间戳
4. 表格输出

### 方式 B — 整批回退到 v{N}

1. **确认:** AskUserQuestion "将回退到 gen-v{N} 生成前状态,涉及模块 [{modules}],确认?" (不自动执行)
2. **校验快照存在:** `.flow_checkpoint/gen-v{N}/snapshot.tar.gz` 不存在 → 报错
3. **当前状态再快照一份:** 避免用户悔棋
   - `tar czf .flow_checkpoint/pre-rollback-{timestamp}.tar.gz` 保存当前被触及文件
4. **删除 NEW 文件:** 读 `touched_files.txt` 中标 `[NEW]` 的,物理删除
5. **解压快照:** `tar xzf .flow_checkpoint/gen-v{N}/snapshot.tar.gz` 覆盖当前文件
6. **跑验证:**
   - `fvm dart run build_runner build --delete-conflicting-outputs`(有 freezed 时)
   - `fvm flutter analyze` 检查 0 error
7. **写日志:** 追加到 `.flow_checkpoint/rollback.log`
8. **输出:**
   ```
   ✅ 已回退到 gen-v{N} 生成前状态
   涉及模块: auth, post
   恢复文件数: 28
   删除新增文件: 6
   悔棋快照: .flow_checkpoint/pre-rollback-{timestamp}.tar.gz
   (如要撤销本次回退: /flutter-rollback undo)
   ```

### 方式 C — 单模块回退(v{N} 只回 {module})

1. **确认:** AskUserQuestion 同上
2. **从 snapshot.tar.gz 过滤解压**(只解 `{module}` 相关路径):
   ```bash
   tar xzf .flow_checkpoint/gen-v{N}/snapshot.tar.gz \
     --wildcards \
       "lib/features/{module}/*" \
       "docs/specs/{module}.md" \
       "docs/plans/{module}.md" \
       "docs/api/{module}.md" \
       "mock/{module}/*" \
       "test/features/{module}/*"
   ```
3. **删除本模块 NEW 文件:** 从 `touched_files.txt` 筛 `[NEW]` + 路径含 `{module}`,物理删除
4. **不改路由表:** `lib/app/routes/app_pages.dart` 会手动提示用户检查(因为可能其他模块后加了路由)
5. **跑验证 + 日志** 同方式 B

### 方式 D — undo(撤销上次 rollback)

1. 从 `.flow_checkpoint/rollback.log` 拿最近一次 `pre-rollback-{timestamp}.tar.gz`
2. 解压覆盖

## 6. 常见错误

- ❌ 快照不存在(用户手动删了 .flow_checkpoint)— 提示用户用 git 回退
- ❌ 单模块回退但 `routes` 表里这个模块已被其他模块引用 — 提示冲突,让用户手动解
- ❌ 回退后 freezed 文件没重生成 — 强制跑一次 build_runner
- ❌ 回退跨 N 个版本(v5 → v1)— 只认最近一次快照,中间版本不追

## 7. 退出条件

- ✅ 目标文件恢复到快照状态
- ✅ NEW 文件已清除
- ✅ `fvm flutter analyze` 0 error
- ✅ 日志写入 `.flow_checkpoint/rollback.log`
- ✅ 用户收到清单 + 悔棋路径
