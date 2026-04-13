---
name: flutter-i18n-gen
description: 扫描代码中的硬编码中文字符串,自动提取为 .tr key + 生成翻译文件。用户说"国际化"、"提取中文"、"i18n"时触发。替换硬编码为 'module.key'.tr。
type: skill
stage: 5
model: sonnet
priority: P1
version: 1.0.0
owner: @lead
category: transformer
---

# 国际化提取 (flutter-i18n-gen)

## 1. 触发场景

- "把这个模块国际化" / "提取中文字符串"
- "i18n 这个页面"
- "把硬编码中文改成 .tr"
- page-gen / widget-gen 生成代码后自动建议
- flutter-review 发现硬编码中文后建议

**反例:**
- "翻译成英文" → 人工翻译,本 skill 只提取 key
- "改 i18n 配置" → flutter-context-update

## 2. 前置必读

- `docs/_context/conventions.md` (i18n key 命名规范: `{module}.{key}` snake_case)
- `lib/app/locales/` (已有翻译文件结构)
- 目标文件 (要扫描的代码)

## 3. 输入

**必填:**
- `source` — 文件路径 / 目录路径 / 代码片段

**可选:**
- `module_name` — 未提供时从文件路径推断
- `dry_run` (bool, default true) — 先列出清单再替换

## 4. 工作流程

**Step 1 — 读 context + 现有翻译**
读取 `lib/app/locales/` 下已有的 key,避免重复。

**Step 2 — 扫描硬编码中文**
正则匹配: `Text('中文')` / `'中文'` / `"中文"` (排除注释和 import)

提取清单:
```
文件: announce_list_page.dart
  L12: Text('公告列表')     → 'announce.listTitle'.tr
  L35: Text('暂无公告')     → 'announce.empty'.tr
  L48: '下拉刷新'           → 'common.pullToRefresh'.tr
```

**Step 3 — 生成 key (命名规则)**
- 模块级: `{module}.{camelCaseKey}` → `announce.listTitle`
- 通用级: `common.{key}` → `common.pullToRefresh` / `common.noMore`
- 含变量: `.trParams({'count': '$count'})`,不要字符串拼接

**Step 4 — Dry-run (AskUser)**
列出所有替换清单 + 将生成的翻译 key。用户确认后执行。

**Step 5 — 替换代码 + 生成翻译文件**
- 替换源文件中的硬编码 → `.tr` / `.trParams`
- 在 `lib/app/locales/zh_cn/{module}.dart` 追加 key
- 如果 en_us 文件存在,追加空 key (标 TODO)

**Step 6 — 自检**

## 5. 输出产物

```
修改的文件:
- lib/features/{module}/presentation/pages/**/*.dart  (替换硬编码)
新增/修改:
- lib/app/locales/zh_cn/{module}.dart  (中文 key-value)
- lib/app/locales/en_us/{module}.dart  (英文 TODO 占位)
```

## 6. 代码模板

**替换前:**
```dart
Text('公告列表'),
AppEmptyView(message: '暂无公告'),
ClassicHeader(dragText: '下拉刷新', armedText: '释放刷新'),
```

**替换后:**
```dart
Text('announce.listTitle'.tr),
AppEmptyView(message: 'announce.empty'.tr),
ClassicHeader(dragText: 'common.pullToRefresh'.tr, armedText: 'common.releaseToRefresh'.tr),
```

**生成的翻译文件:**
```dart
// lib/app/locales/zh_cn/announce.dart
const Map<String, String> announceZhCn = {
  'announce.listTitle': '公告列表',
  'announce.empty': '暂无公告',
};
```

## 7. 不做什么 (Boundary)

- ❌ 不翻译(只提取 key,翻译是人工的事)
- ❌ 不改注释中的中文
- ❌ 不改 mock JSON 中的中文
- ❌ 不改 docs/ 中的中文
- ❌ 不改 pubspec.yaml
- ❌ 不自动 commit

## 8. 自检 Checklist

- [ ] 所有 Text() 中的中文都已替换
- [ ] key 命名符合 `{module}.{camelCaseKey}` 规范
- [ ] 翻译文件已生成
- [ ] 含变量的用 `.trParams`,不是字符串拼接
- [ ] `dart analyze` 0 errors
- [ ] 通用文案(如"下拉刷新")用 `common.` 前缀

## 9. 失败处理

**ASK_USER:** 不确定是通用 key 还是模块 key 时
**STOP:** 目标文件不存在
**ROLLBACK:** 替换出错 → git checkout 恢复

## 10. 联动

**上游:** flutter-page-gen / flutter-widget-gen (生成含硬编码的代码)
**下游:** flutter-review (检查是否还有遗漏)
