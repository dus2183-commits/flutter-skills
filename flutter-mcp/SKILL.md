---
name: flutter-mcp
description: 通过 Figma/Zeplin MCP 读取设计稿,提取 Token(颜色/字体/间距),生成符合项目规范的 Flutter Widget 代码。用户说"按设计稿生成代码"、"读取 Figma 设计"时触发。
type: skill
stage: 4
model: opus
priority: P1
version: 1.0.0
owner: @c
category: bridge
---

# MCP 设计稿转代码 (flutter-mcp)

> 本 skill 专注 MCP 工具调用和 Token 映射细节。和 `flutter-design-to-code` 的关系:
> design-to-code 是完整流程(含 vision 降级),flutter-mcp 是 MCP 调用的详细子流程。

## 1. 触发场景

- "按设计稿生成代码" / "读取 Figma 设计"
- "把这个设计转成 Flutter"
- "从 Figma 提取颜色/字体/间距"
- "Figma MCP 生成组件"
- flutter-design-to-code Step 2 调用本 skill

**反例(不该触发):**
- "根据截图生成页面" → flutter-design-to-code (用 vision)
- "加一个新颜色" → flutter-theme-design

## 2. 前置必读

- `docs/_context/conventions.md`
- `docs/_context/tech-stack.md`
- `lib/app/theme/app_colors.dart`
- `lib/app/theme/app_text_styles.dart`
- `lib/app/theme/app_spacing.dart`
- Figma MCP 文档 (`figma:figma-implement-design`)

## 3. 输入

**必填:**
- 设计稿来源: **Figma** 还是 **Zeplin**
- 设计稿链接或组件/页面名称

**可选:**
- `scope`: 生成范围 (完整页面 / 仅组件 / 仅 Token)
- `target_path`: 目标放置位置 (默认按规范自动判断)

## 4. 工作流程

**Step 1 — 调用 Figma MCP 真正读取（禁止瞎猜）**

⛔ **绝对不要只看 Figma URL 就凭想象写代码。必须调 MCP**:

```
1. 先读 figma:figma-use skill (必读前置)
2. 调 use_figma 工具,传入 Figma URL/nodeId
3. MCP 返回完整设计数据
```

**MCP 返回内容应该包含:**

| 类型 | 提取内容 |
|------|---------|
| 颜色 | 所有色值(HEX/RGBA),对应语义命名 |
| 字体 | 字号、字重、行高、字间距 |
| 间距 | padding、margin、gap、圆角数值 |
| 组件 | 组件名称、层级结构、状态变体(默认/hover/disabled) |
| 图标 | 名称 + 可下载的 SVG/PNG URL |
| 图片 | 占位图的可下载 URL (Figma 临时 CDN) |

**Step 1.5 — 自动下载图片资源**

MCP 返回里的 `images[].url` 是 Figma 临时 CDN,**必须立刻下载**（URL 会过期）:

```bash
mkdir -p assets/image/{module}

# 每张图下载
curl -L -o assets/image/{module}/ic_{name}.png "{figma_image_url}"
curl -L -o assets/image/{module}/bg_{name}.png "{figma_image_url_2}"
# ...
```

更新 `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/image/{module}/
```

**命名规则（按 conventions.md）:**
- 图标: `ic_{module}_{name}.png`
- 背景: `bg_{module}_{name}.png`
- 头像: `avatar_{name}.png`
- 按钮: `btn_{module}_{name}.png`

**Step 2 — Token 映射**

将设计稿 Token 映射到项目 theme 文件,**颜色/字体/间距不允许在 Widget 中硬编码**:

- 设计稿颜色 → 检查 `AppColors` 是否已有,新颜色列出待新增
- 设计稿字体 → 检查 `AppTextStyles` 是否已有,缺失项列出
- 设计稿间距 → 检查 `AppSpacing` 是否已有
- 特殊阴影色(如 `Color(0x14000000)`)可保留,加注释说明 Figma Token 名

**Step 3 — 布局转换**

| 设计稿概念 | Flutter 对应 |
|-----------|-------------|
| Auto Layout(横向) | `Row` |
| Auto Layout(纵向) | `Column` |
| 绝对定位层叠 | `Stack` + `Positioned` |
| 固定宽高 | `SizedBox(width: x, height: y)` |
| 内边距 | `Padding` 或 `Container(padding:)` |
| 圆角 | `BorderRadius.circular(n)` |
| 阴影 | `BoxShadow` |
| 分割线 | `Divider` 或 `Container(height: 1, color: AppColors.divider)` |
| 裁剪圆角图片 | `ClipRRect` + `BorderRadius` |

**像素说明:** Figma @ 1x 的像素值直接对应 Flutter 逻辑像素,无需换算。

**Step 4 — 生成 Widget 代码**

拆分规则:
- 可复用单元 → 独立 Widget 文件
- 页面内复杂区块 → 私有 `_buildXxx()` 方法
- 简单容器/间距 → 保留在父 Widget 的 `build` 中

**Step 5 — 自检 (跑段 8 checklist)**

## 5. 输出产物

1. `lib/features/{module}/presentation/widgets/{widget_name}.dart` — Widget 代码 (或 `lib/shared/widgets/`)
2. 新增 Token 清单 (打印到输出,供 flutter-theme-design 处理)

## 6. 代码模板

```dart
/// 商品卡片
///
/// 对应 Figma: Components/Card/ProductCard
/// 规格: 宽度自适应,固定高度 240
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.title,
    required this.price,
    required this.imageUrl,
    this.badge,
    this.onTap,
  });

  final String title;
  final double price;
  final String imageUrl;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000), // 8% 黑色阴影,对应 Figma: Shadow/Card
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... 图片区 + 信息区
          ],
        ),
      ),
    );
  }
}
```

**Token 映射规则:**
- 颜色引用 `AppColors.xxx`,不硬编码 `Color(0xFF...)`
- 字体引用 `AppTextStyles.xxx`,不硬编码 `fontSize`
- 间距引用 `AppSpacing.xxx`,特殊值加注释说明来源
- 设计稿新增 Token 先定义再引用

## 7. 不做什么 (Boundary)

- ❌ 不修改 theme 文件 (只列出需要新增的 Token,由 flutter-theme-design 处理)
- ❌ 不生成复杂动效 (Lottie 动画等需单独确认资源)
- ❌ 不自动切图 (需要用户从 Figma 导出)
- ❌ 不生成 Controller / Binding (那是 page-gen 的事)
- ❌ 不自动 commit

## 8. 自检 Checklist

- [ ] MCP 调用成功,设计信息完整提取
- [ ] 所有颜色引用 `AppColors`,无硬编码 `Color(0xFFxxxxxx)` (阴影色例外,需加注释)
- [ ] 所有字体引用 `AppTextStyles`,无硬编码 `fontSize`
- [ ] 所有标准间距引用 `AppSpacing`
- [ ] `const` 构造函数已正确声明
- [ ] 组件文档注释中标注了对应 Figma/Zeplin 路径
- [ ] 长文本设置了 `maxLines` + `overflow: TextOverflow.ellipsis`
- [ ] **没有使用 withOpacity** (用 withValues)

> ⚠️ **高频错误警告:**
> - **不要用 withOpacity** → 用 `withValues(alpha: 0.15)` (Flutter 3.27 deprecated)
> - **不要硬编码颜色** → 统一放 AppColors
> - 浮出父容器用 `Stack + clipBehavior: Clip.none`,不用 Transform
> - 图片用 `AppImage` 组件(自带 cache)

## 9. 失败处理

**MCP 调用失败:**
> "Figma MCP 暂时无法访问,降级方案:
> 1. 截图发给我,用 vision 分析 (走 flutter-design-to-code)
> 2. 或手工描述设计要素"

**设计稿含复杂动画:**
> "动画逻辑建议手工在 Controller 中实现,先生成静态 UI。"

**设计稿 Token 和项目主题差异大:**
> ASK_USER "设计稿颜色和项目 AppColors 差异较大,是新增到 AppColors 还是用设计稿的?"

## 10. 联动

**成功后:**
> "UI 代码生成完成。
> - 新增 Token 待处理: {N 个颜色} / {M 个字体}
> - 建议用 `flutter-theme-design` 处理新增 Token
> - 建议用 `flutter-review` 评审代码规范"

**上游:** flutter-design-to-code (调用本 skill)
**下游:** flutter-theme-design / flutter-review
