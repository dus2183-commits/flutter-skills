---
name: flutter-flow-design
description: 从 Figma 链接 / 截图 / Zeplin 截图生成 Flutter 页面代码的流水线。 用户提供 Figma URL、上传截图、说"按这个图实现"时触发。 调用 figma MCP 或 vision,然后走 page-gen + review。
type: workflow
stage: orchestration
model: opus
priority: P1
version: 1.0.0
owner: @lead
---

# 设计转代码流水线 (flutter-flow-design)

## 1. 触发场景
- "Figma 链接 ..." / "https://figma.com/file/..."
- "按这个截图实现 ..." (附图片)
- "做这个 Zeplin 页面"
- "把这个 UI 转成 Flutter"
- "实现这个设计稿"

## 2. 前置必读
- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `lib/shared/widgets/` (已有公共组件)
- `lib/app/theme/` (已有 theme)

## 3. 输入
- A. Figma URL (会调 figma:figma-implement-design MCP)
- B. 截图文件 (用 Claude vision 分析)
- C. Zeplin URL (让用户截图后走 B)

## 4. 状态机定义

```
states:
  - IDLE
  - IDENTIFY_INPUT          识别输入类型 (A/B/C)
  - CONFIRM_TARGET          确认目标 (页面?组件?路径?)
  - EXTRACT_DESIGN          提取设计信息 (图层/颜色/字体/资源)
  - MAP_THEME               对照已有 theme,标记新增
  - LIST_ASSETS             列出待切图清单
  - GEN_CODE                调用 design-to-code skill
  - PAGE_GEN                调用 page-gen 完善三件套
  - REVIEW                  调用 review
  - DONE
  - ABORT
  - PAUSED

initial: IDLE
final: [DONE, ABORT]
```

## 5. Transition 规则

| 当前 | 事件 | 下个 | 条件 |
|---|---|---|---|
| IDLE | user_prompt | IDENTIFY_INPUT | - |
| IDENTIFY_INPUT | figma_url_detected | EXTRACT_DESIGN | URL 是 figma.com |
| IDENTIFY_INPUT | image_uploaded | EXTRACT_DESIGN | 用 vision |
| IDENTIFY_INPUT | unknown_input | ASK_USER | 不是 URL 也不是图 |
| EXTRACT_DESIGN | design_extracted | CONFIRM_TARGET | - |
| CONFIRM_TARGET | target_confirmed | MAP_THEME | 用户确认目标路径 |
| MAP_THEME | theme_checked | LIST_ASSETS | 标记新增颜色/字号 |
| LIST_ASSETS | assets_listed | GEN_CODE | - |
| GEN_CODE | code_written | I18N_GEN | 代码文件存在 |
| I18N_GEN | i18n_done | PAGE_GEN | 硬编码中文已提取 |
| GEN_CODE | retry | EXTRACT_DESIGN | 提取信息不足 |
| PAGE_GEN | three_files_done | REVIEW | page+controller+binding 全有 |
| REVIEW | review_pass | DONE | 0 个 ❌ |
| REVIEW | review_fail | GEN_CODE | retry < 1 |
| 任何 | user_abort | ABORT | - |

## 6. Worker 调用映射

| State | 调用方式 | Skill / MCP |
|---|---|---|
| EXTRACT_DESIGN (Figma) | sequential | `figma:figma-use` → `figma:figma-implement-design` |
| EXTRACT_DESIGN (截图) | inline | Claude vision (内置) |
| CONFIRM_TARGET | inline | AskUserQuestion |
| MAP_THEME | inline | (读 lib/app/theme/) |
| LIST_ASSETS | inline | (写 assets-needed.md) |
| GEN_CODE | sequential | `flutter-design-to-code` |
| I18N_GEN | sequential | `flutter-i18n-gen` (提取设计稿生成代码中的硬编码中文) |
| PAGE_GEN | sequential | `flutter-page-gen` (补充三件套) |
| REVIEW | sequential | `flutter-review` |

## 7. Reflector 配置

**模型:** sonnet  
**retry 上限:** 1

| State | 检查项 | 失败动作 |
|---|---|---|
| EXTRACT_DESIGN | 提取的 layout 完整 / 颜色字体清单非空 | retry |
| GEN_CODE | 没用原生 Text/Image / 用了 AppXxx 组件 / 三端兼容 | retry |
| PAGE_GEN | 三件套全 / GetView<Controller> / 三态处理 | retry |
| REVIEW | 0 个 ❌ | 不重试,ASK_USER |

## 8. Checkpoint 配置

**位置:** `.flow_checkpoint/design-{target}-{date}/`

**写时机:**
- EXTRACT_DESIGN 后存提取结果(避免重复调 Figma MCP)
- GEN_CODE 后存代码文件路径

**清理:** DONE 后 24h

## 9. 失败处理

**ASK_USER 时机:**
- Figma URL 无法访问 (权限问题)
- 截图模糊无法识别
- 提取的颜色无法对照 theme(用户决定加新色还是用近似)
- 待切图清单中缺关键资源

**降级:**
- Figma MCP 失败 → 引导用户截图后走 vision 路径

## 10. 进度报告

```
🎨 启动 design workflow

[1/9] ✅ IDENTIFY_INPUT   检测到 Figma URL
[2/9] ✅ EXTRACT_DESIGN   通过 figma MCP 提取设计 (8 个 frame)
[3/9] ✅ CONFIRM_TARGET   目标: lib/features/announce/presentation/pages/announce_list_page.dart
[4/9] ⚠️ MAP_THEME        发现 2 个未匹配颜色 (#5856D6, #FF3B30)
[5/9] ⚠️ LIST_ASSETS      待切图 5 个 (写入 assets-needed.md)
[6/9] ⏳ GEN_CODE         生成中...
[7/9] ⏸ PAGE_GEN
[8/9] ⏸ REVIEW
[9/9] ⏸ DONE

⚠️ 警告:
  - 2 个颜色需要补到 lib/app/theme/colors.dart
  - 5 个图片需要从 Figma 切图
```

## 11. 自检 Checklist

- [x] 状态机闭合
- [x] 双输入路径(Figma / vision)
- [x] 降级机制(Figma 失败走 vision)
- [x] 资源清单输出

## 12. 联动

**成功后:**
> "页面已生成! 但需要手动:
>   1. 切图后放到 assets/image/{module}/
>   2. 在 pubspec.yaml 注册 assets
>   3. 补充 theme 中的新颜色
>   4. 跑 flutter pub get"

**失败后:**
> "Figma MCP 调用失败。建议截图后说'按这个截图实现'走 vision 路径"

**Workflow 编排关系:**
- 上游: (用户直接触发)
- 替代: `flutter-flow-feature` (无设计稿时)
- 下游: `flutter-flow-review` (深度评审)
