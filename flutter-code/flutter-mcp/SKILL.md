---
name: flutter-mcp
description: 用于通过 Figma 或 Zeplin MCP 读取设计稿，快速生成符合项目规范的 Flutter UI 代码。触发场景：用户说"按设计稿生成代码"、"读取 Figma 设计"、"把这个设计转成 Flutter"。
---

# 设计稿转代码（flutter-mcp）

## 概述

通过 MCP（Model Context Protocol）接入 Figma 或 Zeplin，读取设计稿中的组件、颜色、字体、间距等信息，生成符合本项目规范的 Flutter Widget 代码。

## 前置信息确认

开始前确认：
- 设计稿来源：**Figma** 还是 **Zeplin**
- 提供设计稿链接或组件/页面名称
- 目标放置位置：
  - 页面级 → `features/[module]/views/`
  - 通用组件 → `common/widgets/`

## 工作流程

### Step 1 — 读取设计稿信息

通过 MCP 工具提取以下内容：

| 类型 | 提取内容 |
|------|---------|
| 颜色 | 所有色值（HEX/RGBA），对应语义命名 |
| 字体 | 字号、字重、行高、字间距 |
| 间距 | padding、margin、gap、圆角数值 |
| 组件 | 组件名称、层级结构、状态变体（默认/hover/disabled） |
| 图标 | 名称，确认是否有对应项目资源 |
| 图片 | 占位尺寸，确认资源来源（本地 assets / 远程 URL） |

### Step 2 — Token 映射

将设计稿 Token 映射到 `common/theme/`，**颜色/字体/间距不允许在 Widget 中硬编码**：

```dart
// common/theme/app_colors.dart
class AppColors {
  AppColors._();

  // 主色系（对应 Figma: Primary/500）
  static const primary = Color(0xFF1A73E8);
  static const primaryLight = Color(0xFFD2E3FC);
  static const primaryDark = Color(0xFF1557B0);

  // 功能色
  static const success = Color(0xFF34A853);
  static const error = Color(0xFFD93025);
  static const warning = Color(0xFFFBBC04);

  // 文字色
  static const textPrimary = Color(0xFF202124);
  static const textSecondary = Color(0xFF5F6368);
  static const textHint = Color(0xFF9AA0A6);

  // 背景色
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const divider = Color(0xFFE8EAED);
}

// common/theme/app_text_styles.dart
class AppTextStyles {
  AppTextStyles._();

  // 对应 Figma: Typography/Heading1
  static const heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.textPrimary,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );
}

// common/theme/app_spacing.dart
class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}
```

**规则：**
- 设计稿新增颜色先在 `AppColors` 中定义并标注 Figma 对应 Token 名，再在 Widget 中引用
- 字体样式在 `AppTextStyles` 中统一管理，Widget 内通过 `.copyWith()` 做局部覆盖
- 间距优先使用 `AppSpacing` 中的标准值；设计稿中的特殊数值（如 6、14）可直接使用，加注释说明来源

### Step 3 — 布局转换规则

| 设计稿概念 | Flutter 对应 |
|-----------|-------------|
| Auto Layout（横向） | `Row` |
| Auto Layout（纵向） | `Column` |
| 绝对定位层叠 | `Stack` + `Positioned` |
| 固定宽高 | `SizedBox(width: x, height: y)` |
| 内边距 | `Padding` 或 `Container(padding:)` |
| 圆角 | `BorderRadius.circular(n)` |
| 阴影 | `BoxShadow` |
| 分割线 | `Divider` 或 `Container(height: 1, color: AppColors.divider)` |
| 裁剪圆角图片 | `ClipRRect` + `BorderRadius` |

**像素说明：** Figma @ 1x 的像素值直接对应 Flutter 逻辑像素，无需换算。

### Step 4 — 生成 Widget 代码

根据设计稿层级结构生成代码，拆分规则：
- 可复用单元 → 独立 Widget 文件
- 页面内复杂区块 → 私有 `_buildXxx()` 方法
- 简单容器/间距 → 保留在父 Widget 的 `build` 中

**示例输出（商品卡片组件）：**

```dart
/// 商品卡片
///
/// 对应 Figma: Components/Card/ProductCard
/// 规格：宽度自适应，固定高度 240
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

  /// 角标文字，如"热销"、"新品"，为 null 时不显示
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
              color: Color(0x14000000), // 8% 黑色阴影，对应 Figma: Shadow/Card
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(),
            _buildInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Image.network(
            imageUrl,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        if (badge != null)
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            child: _BadgeLabel(label: badge!),
          ),
      ],
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '¥${price.toStringAsFixed(2)}',
            style: AppTextStyles.heading2.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _BadgeLabel extends StatelessWidget {
  const _BadgeLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: Colors.white),
      ),
    );
  }
}
```

### Step 5 — 生成后自动检查

生成代码后逐项确认：

- [ ] 所有颜色引用 `AppColors`，无硬编码 `Color(0xFFxxxxxx)`（设计稿特殊阴影色可保留，加注释）
- [ ] 所有字体引用 `AppTextStyles`，无硬编码 `fontSize`
- [ ] 所有标准间距引用 `AppSpacing`，特殊间距加注释说明来源
- [ ] `const` 构造函数已正确声明
- [ ] 组件文档注释中标注了对应 Figma/Zeplin 路径
- [ ] 图片加载使用 `BoxFit.cover` 并处理了加载失败的 fallback
- [ ] 长文本设置了 `maxLines` + `overflow: TextOverflow.ellipsis`

## 注意事项

- 复杂动效（Lottie 动画、自定义过渡）需单独确认资源来源，不在本 skill 范围内自动生成
- 设计稿中的 `sp` 字体单位在 Flutter 中对应 `fontSize`，系统字体缩放由 Flutter 自动处理
- 图标优先使用项目 `assets/icons/` 中的 SVG 资源；如果是系统图标，使用 `Icons.xxx`

## 完成后联动

> "UI 代码生成完成。可使用 `flutter-review` skill 评审生成的组件是否符合项目规范。"
