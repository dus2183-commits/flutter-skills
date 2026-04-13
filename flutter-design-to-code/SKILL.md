---
name: flutter-design-to-code
description: Figma/Zeplin 设计稿 → Flutter 代码。通过 MCP 调用设计工具 API 提取样式,生成代码。用户说"根据 Figma 生成页面"、"把这个设计稿变成代码"、"从 Zeplin 切图"时触发。
type: skill
stage: 4
model: opus
priority: P1
version: 1.0.0
owner: @c
category: bridge
---

# 设计稿转代码 (flutter-design-to-code)

## 1. 触发场景
- "根据 Figma 生成页面"
- "这是 Zeplin 的设计稿，帮我转代码"
- "把这个设计稿变成 Flutter 代码"
- "从 Figma 截图生成页面"
- "Figma 链接: https://figma.com/... 转代码"

## 2. 前置必读
- `docs/_context/conventions.md`
- `docs/_context/tech-stack.md`
- `_governance/checklists/getx-usage.md`
- Figma MCP 文档 (`figma:figma-implement-design`)

## 3. 输入

**必填（3 选 1）:**
- **选项 A:** Figma 链接 (https://figma.com/file/...)
- **选项 B:** Zeplin 链接 (https://zeplin.io/...)
- **选项 C:** 设计稿截图（上传图片，用 vision 分析）

**可选:**
- `scope`: 生成范围 (完整页面 / 仅布局 / 仅组件)
- `includeAssets`: 是否生成切图清单 (默认 true)

## 4. 工作流程

**Step 1 — 识别输入类型**

- URL → 类型判断 (Figma / Zeplin / 其他)
- 图片 → 使用 vision 分析

**Step 2 — 调用 MCP 提取设计信息**

对于 Figma:
- 调 `figma:figma-implement-design` MCP
- 提取: 布局结构 / 颜色 / 字体 / 间距 / 组件

对于 Zeplin (或截图):
- 用 Claude vision 分析图片
- 手工提取设计要素

**Step 3 — 设计信息标准化**

提取的内容:
- 页面布局：栅栏系统、分区、堆叠方向
- 颜色：检查是否在 theme 中，新颜色单独列出
- 字体：行高、字重、大小，检查是否在 AppTextStyles 中
- Spacing：padding/margin 尺寸，检查是否在 AppSpacing 中
- 组件：Button / TextField / Card 等，复用项目已有组件

**Step 4 — 对照项目主题**

- 颜色 → 对照 `AppColors`，缺失项列出来
- 字体 → 对照 `AppTextStyles`，缺失项列出来
- Spacing → 对照 `AppSpacing`，缺失项列出来

**Step 5 — 生成 Flutter 代码**

生成结构化的 View 代码（无 Controller，只是 UI）。
使用项目组件：`AppText` / `AppButton` / `AppImage`。

**Step 6 — 输出两个文件**

1. `{page_name}_page_widget.dart` — UI 代码
2. `{page_name}_assets_needed.md` — 切图清单

**Step 7 — 建议后续步骤**

- 用 `flutter-page-gen` 包装成完整页面 (加 Controller/Binding)
- 用 `flutter-theme-design` 更新主题
- 用 `flutter-review` 检查代码规范

## 5. 输出产物

生成 1-2 个文件:
1. `lib/features/{module}/presentation/widgets/{page_name}_widget.dart` — UI Widget 代码
2. `docs/assets-needed/{page_name}_assets.md` — 设计稿切图清单

## 6. 模板示例

### 输入: Figma 链接

```
用户: 根据这个 Figma 生成页面
https://figma.com/file/abc123/announcement-detail?node-id=123

Claude:
1. 调用 figma:figma-implement-design MCP
2. 提取设计信息（见下方输出）
3. 生成代码 + 清单
```

### 输出: UI 代码

```dart
// lib/features/announcement/presentation/widgets/announcement_detail_widget.dart

import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/widgets/app_image.dart';

/// 公告详情页面 - UI 层
///
/// 这是从 Figma 设计稿自动生成的 UI 代码。
/// 后续需要用 flutter-page-gen 包装成完整页面（加 Controller/Binding）。
class AnnouncementDetailUI extends StatelessWidget {
  const AnnouncementDetailUI({
    super.key,
    required this.title,
    required this.category,
    required this.content,
    required this.imageUrl,
    required this.createdAt,
  });

  final String title;
  final String category;
  final String content;
  final String? imageUrl;
  final String createdAt;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: 顶部图片区域 (用 AppImage 组件)
          if (imageUrl != null)
            AppImage(url: imageUrl!, height: 240)
          else
            Container(
              height: 240,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.image_not_supported),
              ),
            ),

          // Section 2: 标题 + 元信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 分类标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(category, style: AppTextStyles.caption),
                ),
                const SizedBox(height: 12),

                // 标题
                Text(title, style: AppTextStyles.heading2),
                const SizedBox(height: 8),

                // 发布时间
                Text(createdAt, style: AppTextStyles.caption),
              ],
            ),
          ),

          // Divider
          const Divider(thickness: 1),

          // Section 3: 正文内容
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(content, style: AppTextStyles.body),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
```

### 输出: 切图清单

```markdown
---
artifact_type: assets_needed
created: 2026-04-10
created_by: flutter-design-to-code
page_name: announcement_detail
---

# 切图清单 · 公告详情页

## 1. 新增配色

这些颜色在 AppColors 中不存在，需要新增：

| 颜色名 | HEX 值 | 用途 |
|--------|--------|------|
| categoryBlueBg | #E8F0FE | 分类标签背景 |
| categoryBlue | #1A73E8 | 分类标签文字 |
| placeholder | #999999 | 次级文字色 |

**处理:** 在 `lib/app/theme/app_colors.dart` 新增这 3 个颜色。

---

## 2. 新增字体规范

这些字体在 AppTextStyles 中不存在，需要新增：

| 字体名 | 大小 | 粗细 | 用途 |
|--------|------|------|------|
| categoryTag | 14 | 500 | 分类标签文字 |
| contentBody | 16 | 400 | 正文内容 |

**处理:** 在 `lib/app/theme/app_text_styles.dart` 新增这 2 个字体规范。

---

## 3. 需要切的图片

| 图片名 | 尺寸 | 格式 | 用途 |
|--------|------|------|------|
| img_announcement_placeholder | 240×240 | png | 无图占位符 |

**处理:**
1. 从 Figma 导出为 `assets/images/img_announcement_placeholder.png`
2. 在 `pubspec.yaml` 的 assets 中注册
3. 在代码中引用: `AssetImage('assets/images/img_announcement_placeholder.png')`

---

## 4. 新增 Spacing

这些 spacing 值在 AppSpacing 中不存在，需要新增：

| spacing 名 | 值 | 用途 |
|-----------|-----|------|
| detailPadding | 16 | 详情页内框距 |

**处理:** 在 `lib/app/theme/app_spacing.dart` 新增。

---

## 5. 检查清单

使用这个清单确认所有新增项都已处理：

- [ ] 3 个新颜色已添加到 AppColors
- [ ] 2 个新字体已添加到 AppTextStyles
- [ ] 1 个占位图已切出并注册
- [ ] 1 个 spacing 已添加到 AppSpacing
- [ ] 运行 `flutter pub get` 生效
- [ ] 运行 `flutter-lint-fix` 格式化代码

---

## 6. 后续步骤

1. **完成上述所有新增项**
2. **用 `flutter-page-gen` 生成完整页面** (加 Controller/Binding)
3. **用 `flutter-review` 检查代码规范**

```

## 7. 不做什么

- ❌ 不自动修改 theme 文件 (只列出清单，用户确认后由 flutter-theme-design 处理)
- ❌ 不自动切图 (需要用户手工从 Figma 导出，或用 Zeplin 自动化)
- ❌ 不生成完整页面代码 (只生成 UI 部分，Controller 由 flutter-page-gen 生成)
- ❌ 不修改路由配置
- ❌ 不自动 commit

> ⚠️ **高频错误警告:**
> - **不要硬编码颜色** `Color(0xFF...)` → 用 `AppColors.xxx`,新颜色列到切图清单
> - **不要硬编码字号** `fontSize: 14` → 用 `AppTextStyles.xxx`
> - **不要用 withOpacity** → 用 `withValues(alpha: 0.15)` (Flutter 3.27 deprecated)
> - 图片用 `AppImage` 组件,不用裸 `Image.network`
> - 文本用 `AppText` 组件
> - 浮出父容器用 `Stack + clipBehavior: Clip.none`,不用 Transform

## 8. 自检 Checklist

- [ ] 成功调用了 Figma/Zeplin MCP 或 vision 分析
- [ ] 生成的 UI 代码使用了 `AppColors` / `AppTextStyles` / `AppSpacing`
- [ ] **没有硬编码 Color(0xFF...)**
- [ ] **没有使用 withOpacity**
- [ ] 新增项清单清晰、完整
- [ ] 给出了后续步骤建议

## 9. 失败处理

**Figma MCP 调用失败:**
> "Figma MCP 暂时无法访问，降级方案:
> 1. 截图发给我，我用 vision 分析
> 2. 或手工描述设计要素"

**设计中含有复杂动画或交互**难以转 Flutter:**
> "这个交互比较复杂，建议:
> 1. 先生成静态 UI
> 2. 动画逻辑由你手工在 Controller 中实现"

**缺少切图资源:**
> "Figma 中缺少切图标注，建议:
> 1. 标注一下各个区域的尺寸
> 2. 或手工从 Figma 导出需要的图片"

## 10. 联动

**成功后:**
> "✅ 设计稿已转换为 Flutter 代码。
> 
> **生成的文件:**
> - UI 代码: lib/features/{module}/presentation/widgets/{page}_widget.dart
> - 清单: docs/assets-needed/{page}_assets.md
> 
> **新增配置待处理 (5 项):**
> - 3 个新颜色 (AppColors)
> - 2 个新字体 (AppTextStyles)
> - 1 个占位图 (assets)
> 
> **建议后续步骤:**
> 1. 用 `flutter-theme-design` 处理新增配色/字体
> 2. 用 `flutter-page-gen` 生成完整页面 (加 Controller/Binding)
> 3. 用 `flutter-review` 检查代码规范"

**上游:**
- 设计稿 (Figma / Zeplin / 截图)
- flutter-spec (需求文档中的设计约束)

**下游:**
- flutter-theme-design (处理新增配色/字体)
- flutter-page-gen (生成完整页面)
- flutter-review (代码评审)
