---
name: flutter-manifest-init
description: 生成批量开发清单模板。用户说"生成清单模板"、"新建 manifest"、"批量开发模板"、"准备批量任务"时触发。自动递增版本号,从 _knowledge/context-templates/manifest.template.yaml 拷贝骨架到 docs/manifests/manifest-v{N}.yaml,用户填完后用 flutter-flow-feature 批量生成代码。
type: skill
stage: 0
model: haiku
priority: P0
version: 1.0.0
owner: @tg
category: scaffold
---

# 清单模版生成 (flutter-manifest-init)

## 1. 触发场景

- "生成 manifest 模版" / "生成清单模板"
- "新建批量开发清单"
- "准备批量任务"
- "我要批量做几个模块"
- "clear 前一个 manifest,新做一批"

**反例(不要用这个 skill)**:
- "生成 model" → `flutter-model-gen`
- "生成接口" → `flutter-api-gen`
- "做一个登录模块(单个)" → `flutter-flow-feature`(自然语言模式)

## 2. 前置必读

- `_knowledge/context-templates/manifest.template.yaml` — 模版源文件
- `docs/_context/api-global.yaml` — 项目级 API 配置(如不存在提示先跑 `flutter-init`)

## 3. 输入

- 无强制输入,可选:
  - `modules_count`: 预计模块数(默认 1,决定骨架里留几个空 module 块)
  - `modules_hint`: 模块名建议(如 `["auth", "post", "user"]`),会预填 `name` 字段

## 4. 执行步骤

1. **检查前置:** `docs/_context/api-global.yaml` 存在吗?不存在 → 提示用户先跑 `flutter-init` 或手动拷 `_knowledge/context-templates/api-global.template.yaml` 过去。
2. **确定下一个版本号:**
   ```bash
   ls docs/manifests/manifest-v*.yaml 2>/dev/null | grep -oE 'v[0-9]+' | sort -V | tail -1
   ```
   没有 → `version = 1`,否则 +1。
3. **读模版:** `_knowledge/context-templates/manifest.template.yaml`
4. **删掉 3 个示例模块,保留骨架注释。** 按 `modules_count` 生成 N 个空 module 块:
   ```yaml
   modules:
     - name: {modules_hint[0] or "TODO_module_name"}
       chinese: TODO
       priority: P0
       routes:
         - path: /TODO
           type: standalone
           parent: null
           position_note: "TODO"
       pages:
         - name: TODO
           spec_only: true
       endpoints: []
       manual_assets: []
   ```
5. **更新 frontmatter:**
   - `version: {N}`
   - `created_at: {today}`
   - `generated_code_version: v{N}`
6. **写入:** `docs/manifests/manifest-v{N}.yaml`
7. **输出给用户:**
   ```
   ✅ 已生成 docs/manifests/manifest-v{N}.yaml

   下一步:
   1. 打开文件填字段(重点:routes / pages / endpoints 的 req_json/resp_json)
   2. 接口 JSON 直接从 Postman/Swagger 复制即可
   3. 手工切图填到 manual_assets(不用改名字,我们按规范自动改)
   4. 填完跑: /flutter-flow-feature manifest:docs/manifests/manifest-v{N}.yaml

   回退: /flutter-rollback v{N} 可回到生成前状态
   ```

## 5. 输出产物

    docs/manifests/
    └── manifest-v{N}.yaml        ← 本 skill 产出

历史版本保留,不删不覆盖。

## 6. 常见错误

- ❌ 覆盖已存在的 manifest — 版本号必须递增,不得覆盖
- ❌ 不读 `api-global.yaml` 前置 — 会导致 flow-feature 没全局配置可继承
- ❌ 示例模块原样留着没删 — 会让用户误以为 auth/post/about 是真要做的

## 7. 退出条件

- ✅ `docs/manifests/manifest-v{N}.yaml` 存在且 `version = N`
- ✅ 骨架里 `modules[]` 数量 = 用户指定(或默认 1)
- ✅ 用户收到下一步指引
