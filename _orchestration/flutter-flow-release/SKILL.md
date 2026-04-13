---
name: flutter-flow-release
description: 发版流水线。用户说"发版"、"build release"、"打 release 包"时触发。 bump version → changelog → 三端 build → 输出产物路径。
type: workflow
stage: orchestration
model: opus
priority: P2
version: 1.0.0
owner: @lead
---

# 发版流水线 (flutter-flow-release)

## 1. 触发场景
- "发版" / "发布 v1.0.0"
- "build release"
- "打 release 包"
- "构建 production"

## 2. 前置必读
- `docs/_context/decisions.md` (检查是否有未实施的决策)
- `pubspec.yaml` (当前版本号)

## 3. 输入
- `version` (string, semver) — 目标版本号(可省略,默认 patch++)
- `release_notes` (string) — 发版说明(可省略,自动从 git log 生成)
- `target_platforms` (list) — 默认全平台

## 4. 状态机定义

```
states:
  - IDLE
  - PRE_CHECK             预检查 (git clean / 测试通过 / lint pass)
  - BUMP_VERSION          升版本号 (pubspec.yaml)
  - GENERATE_CHANGELOG    生成 CHANGELOG.md
  - USER_CONFIRM          展示 changelog 让用户确认
  - BUILD_ANDROID         build apk + appbundle
  - BUILD_IOS             build ipa
  - BUILD_WEB             build web
  - VERIFY_OUTPUTS        验证产物存在 + 大小合理
  - DONE
  - ABORT
  - PAUSED

initial: IDLE
final: [DONE, ABORT]
```

## 5. Transition 规则

| 当前 | 事件 | 下个 | 条件 |
|---|---|---|---|
| IDLE | user_prompt | PRE_CHECK | - |
| PRE_CHECK | all_pass | BUMP_VERSION | git clean + analyze 0 + test pass |
| PRE_CHECK | failed | ABORT | 任一不过 |
| BUMP_VERSION | version_bumped | GENERATE_CHANGELOG | pubspec.yaml 已改 |
| GENERATE_CHANGELOG | changelog_done | USER_CONFIRM | CHANGELOG.md 已写 |
| USER_CONFIRM | confirmed | BUILD_ANDROID | - |
| USER_CONFIRM | rejected | ABORT | 用户不确认 |
| BUILD_ANDROID | apk_done | BUILD_IOS | apk 文件存在 |
| BUILD_ANDROID | failed | ASK_USER | - |
| BUILD_IOS | ipa_done | BUILD_WEB | ipa 存在(或 macOS 可跳过) |
| BUILD_IOS | failed | BUILD_WEB | iOS 失败可跳过 |
| BUILD_WEB | web_done | VERIFY_OUTPUTS | build/web 存在 |
| VERIFY_OUTPUTS | all_ok | DONE | - |
| 任何 | user_abort | ABORT | - |

## 6. Worker 调用映射

| State | 调用方式 | Skill / Bash |
|---|---|---|
| PRE_CHECK | bash + conditional | `git status` + `flutter analyze` + `flutter test`; 如果 test/ 下无测试文件 → 调 `flutter-test-gen` 先生成 |
| BUMP_VERSION | sequential | `flutter-release` (内部 bump) |
| GENERATE_CHANGELOG | sequential | `flutter-changelog` |
| USER_CONFIRM | inline | AskUserQuestion |
| BUILD_ANDROID | bash | `flutter build apk --release && flutter build appbundle --release` |
| BUILD_IOS | bash | `flutter build ipa --release` (需 codesign) |
| BUILD_WEB | bash | `flutter build web --release` |
| VERIFY_OUTPUTS | bash | `ls build/` + 大小检查 |

**注意:** BUILD_ANDROID / BUILD_IOS / BUILD_WEB 顺序执行,不并行(避免资源争抢)。

## 7. Reflector 配置

**模型:** sonnet  
**retry 上限:** 0 (发版不重试,失败手动)

| State | 检查项 |
|---|---|
| PRE_CHECK | git clean / 0 lint error / 0 test fail |
| BUMP_VERSION | pubspec.yaml 版本号已改 |
| GENERATE_CHANGELOG | CHANGELOG.md 含本次改动条目 |
| BUILD_* | 产物文件存在且 > 1MB |
| VERIFY_OUTPUTS | apk < 100MB / ipa < 200MB / web < 50MB |

## 8. Checkpoint 配置

**位置:** `.flow_checkpoint/release-v{version}-{date}/`

**写时机:** 每个 BUILD_* 后写产物路径
**清理:** DONE 后 30 天 (发版记录有审计价值)

## 9. 失败处理

**ASK_USER 时机:**
- PRE_CHECK 失败 (git 不干净 / lint error / test fail)
- BUILD_ANDROID 失败 (常是依赖问题)
- BUILD_IOS 失败 (常是 codesign 问题)
- BUILD_WEB 失败 (常是 dart:io 引用)

**STOP 时机:**
- 用户拒绝 changelog
- 致命错误

**注意:** **不要**自动 git tag / git push,这些必须用户手动做(避免误发布)。

## 10. 进度报告

```
🚀 启动 release workflow

[1/9] ✅ PRE_CHECK         git clean / lint 0 / test 32 pass
[2/9] ✅ BUMP_VERSION      1.0.0 → 1.0.1
[3/9] ✅ GENERATE_CHANGELOG 自动从 git log 生成 5 条
[4/9] ✅ USER_CONFIRM      用户确认 changelog
[5/9] ⏳ BUILD_ANDROID     building apk + aab ...
       ✅ apk 24.3 MB (build/app/outputs/flutter-apk/app-release.apk)
       ✅ aab 22.1 MB (build/app/outputs/bundle/release/app-release.aab)
[6/9] ⏳ BUILD_IOS         building ipa ... (skip on non-macOS)
[7/9] ⏳ BUILD_WEB         building web ...
       ✅ web 8.7 MB (build/web/)
[8/9] ✅ VERIFY_OUTPUTS    所有产物 OK
[9/9] ✅ DONE

📦 发版产物:
   - build/app/outputs/flutter-apk/app-release.apk (24.3 MB)
   - build/app/outputs/bundle/release/app-release.aab (22.1 MB)
   - build/web/ (8.7 MB)

⚠️ 手动后续:
   1. git tag v1.0.1
   2. 上传到 Play Store / App Store / 静态站点
   3. 推送 changelog 给用户
```

## 11. 自检 Checklist

- [x] PRE_CHECK 严格(失败立即 abort)
- [x] 不自动 git push / git tag
- [x] 不自动上传到 store
- [x] 三端独立构建(失败一个不影响其他)
- [x] checkpoint 长保留(审计)

## 12. 联动

**成功后:**
> "发版完成! 产物在 build/。
>   下一步(手动):
>   1. git tag v{version}
>   2. 上传到 Store
>   3. 通知团队"

**失败后:**
> "发版中断在 {state},checkpoint 已保存。
> 修复后说'重新发版 v{version}'"

**Workflow 编排关系:**
- 上游: review workflow (评审通过后)
- 下游: (手动 git tag + push + upload)
