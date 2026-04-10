---
name: flutter-release
description: 构建 release 包。bump version,跑 changelog,build apk/ipa/web,输出产物路径。 不自动 git tag / push / upload。
type: skill
stage: 6
model: sonnet
priority: P2
version: 1.0.0
owner: @lead
category: mutator
---

# 发版构建 (flutter-release)

## 1. 触发场景
- "发版" / "build release"
- "打 release 包"
- "构建 production"
- release workflow 内调用

## 2. 前置必读
- `pubspec.yaml` (当前版本)
- `docs/_context/decisions.md` (检查是否有未实施决策)

## 3. 输入

**可选(全可省略,有默认):**
- `version` (semver) — 目标版本,默认 patch++
- `target_platforms` (list) — 默认 [android, ios, web]
- `build_mode` — release / profile,默认 release
- `skip_tests` (bool) — 是否跳过测试,默认 false

## 4. 工作流程

**Step 1 — 预检查**
- bash: `git status --porcelain` (必须 clean)
- bash: `flutter analyze` (必须 0 error)
- bash: `flutter test` (除非 skip)
- 任一失败 → ASK_USER

**Step 2 — 当前版本**
- 读 pubspec.yaml 拿当前版本
- 计算下一个版本 (默认 patch++)
- 显示给用户确认

**Step 3 — Bump version**
- 修改 pubspec.yaml: `version: x.y.z+build`
- 同步修改 lib/main.dart 中的 title (如有版本号)

**Step 4 — 生成 changelog**
- 调用 flutter-changelog 或自己跑 git log
- 写入 CHANGELOG.md (追加新版本段)

**Step 5 — 用户确认**
- 显示版本 + changelog
- ASK_USER "确认构建?"

**Step 6 — 三端构建**

```bash
# Android
flutter build apk --release
flutter build appbundle --release  # 给 Play Store

# iOS (仅 macOS)
flutter build ipa --release  # 需 codesign

# Web
flutter build web --release --tree-shake-icons
```

各平台串行执行,失败一个继续下一个。

**Step 7 — 验证产物**
- 检查产物文件存在
- 检查产物大小合理 (apk < 100MB,ipa < 200MB,web < 50MB)
- 列出产物路径

**Step 8 — 输出总结**
告诉用户:
- 版本号
- 产物路径
- 大小
- 手动后续步骤 (git tag / 上传 store)

## 5. 输出产物

```
build/
├── app/
│   └── outputs/
│       ├── flutter-apk/app-release.apk
│       └── bundle/release/app-release.aab
├── ios/
│   └── ipa/Runner.ipa
└── web/
    └── (整个目录)

修改的文件:
- pubspec.yaml (version)
- CHANGELOG.md (新版本段)
```

## 6. 命令模板

```bash
#!/bin/bash
set -e

VERSION="${1:-auto}"

# 1. Pre-check
git diff --quiet || { echo "❌ git not clean"; exit 1; }
flutter analyze --no-pub || exit 1
flutter test --no-pub || exit 1

# 2. Bump version
if [ "$VERSION" == "auto" ]; then
  CURRENT=$(grep '^version:' pubspec.yaml | cut -d' ' -f2)
  # parse and increment patch
  ...
fi
sed -i.bak "s/^version: .*/version: $VERSION/" pubspec.yaml

# 3. Build
flutter build apk --release
flutter build appbundle --release
flutter build web --release

# Optional iOS (skip on non-macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
  flutter build ipa --release
fi

# 4. Report
echo "✅ Built v$VERSION"
ls -lh build/app/outputs/flutter-apk/app-release.apk
ls -lh build/app/outputs/bundle/release/app-release.aab
[ -f build/ios/ipa/Runner.ipa ] && ls -lh build/ios/ipa/Runner.ipa
du -sh build/web
```

## 7. 不做什么

- ❌ **不自动 `git tag`** (用户手动决定)
- ❌ **不自动 `git push`** (避免误发布)
- ❌ **不上传到 Play Store / App Store** (用户手动)
- ❌ **不上传到静态站点** (web)
- ❌ 不修改 .env (生产 key 由 CI 注入)
- ❌ 不跳过测试 (除非显式 skip_tests)
- ❌ 不在 git 不干净时构建

## 8. 自检 Checklist

- [ ] git 状态 clean
- [ ] flutter analyze 0 error
- [ ] flutter test pass (或显式 skip)
- [ ] 版本号符合 semver
- [ ] CHANGELOG.md 已追加
- [ ] 三端产物都存在 (或显式 skip 某平台)
- [ ] 产物大小合理

## 9. 失败处理

**ASK_USER 时机:**
- git 不 clean
- 测试失败 (是否 skip 继续)
- 某平台构建失败 (是否跳过)
- 产物大小异常 (>2x 上次)

**STOP 时机:**
- pub get 失败
- 三端全部构建失败

**ROLLBACK:**
- 构建失败 → revert pubspec.yaml 的 version 改动
- 不删除 build/ 目录 (用户可能要看错误)

## 10. 联动

**成功后:**
> "v{version} 构建完成!
>   产物:
>     - apk: {path} ({size})
>     - aab: {path} ({size})
>     - ipa: {path} ({size})
>     - web: {path} ({size})
>   
>   ⚠️ 手动后续:
>     1. git tag v{version}
>     2. 上传到 Play Store / App Store
>     3. 部署 web/ 到 CDN"

**失败后:**
> "构建失败在 {platform},详情见 build/{platform}/output.log"

**上游:** flutter-flow-release / 用户直接触发
**下游:** (手动 git tag + upload)
