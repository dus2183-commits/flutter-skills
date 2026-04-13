---
name: flutter-theme-design
description: |
  维护应用主题配置（颜色/字体/spacing/圆角）。
  触发场景：用户说"加一个新颜色"、"改字号"、"新增主题"、"统一 spacing"。
type: skill
stage: 0
model: sonnet
priority: P2
version: 1.0.0
owner: @lead
category: mutator
---

# 主题设计维护 (flutter-theme-design)

## 1. 触发场景
- "加一个新颜色到 theme"
- "改字号 XX"
- "统一 padding 规范"
- "新增圆角等级"
- "加深色主题"
- "改主色从蓝色到紫色"

## 2. 前置必读
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_text_styles.dart`
- `lib/core/theme/app_spacing.dart`（如果存在）
- `docs/_context/conventions.md`
- `docs/_context/decisions.md`

## 3. 输入

**必填:**
- 改动描述（自然语言）：新增颜色/改字号/改 spacing 等

**自动识别:**
- 改动类型: color / typography / spacing / radius / shadow
- 改动范围: 全局 / 某个组件
- 是否需要更新相关 UI

## 4. 工作流程

**Step 1 — 读取现有主题配置**
- 读 `app_colors.dart` (现有颜色列表)
- 读 `app_text_styles.dart` (现有字体规范)
- 读 `app_spacing.dart` (padding/margin 尺寸)

**Step 2 — 识别改动类型**

根据用户描述判断:
- 新增颜色 → 添加到 `AppColors` 类
- 改字号 → 修改 `AppTextStyles` 中对应的 style
- 新增 spacing → 添加到 `AppSpacing` 常量
- 新增圆角/阴影 → 可能需要新建 `app_radius.dart` / `app_shadow.dart`

**Step 3 — 设计改动**
- 给出 before/after 对比
- 说明为什么改（设计原因）
- 列出影响范围（哪些组件会用到）

**Step 4 — 用户确认**

ASK_USER "确认这个改动？"

**Step 5 — 应用改动**

修改对应的主题文件。

**Step 6 — 更新 ADR**

添加一条 ADR 到 `docs/_context/decisions.md`，记录这个设计决策。

格式:
```markdown
## ADR-{N} | {YYYY-MM-DD} | {简短标题}

### 决策
{改了什么主题}

### 理由
{设计或性能原因}

### 影响范围
{影响哪些组件 / 页面}

### 拍板人
@lead

### 状态
active
```

**Step 7 — 提示代码检查**

若改动影响多个页面，提议用 `flutter-review` 检查现有代码是否需要调整。

## 5. 输出产物

修改 1-2 个文件:
- 主文件: `app_colors.dart` / `app_text_styles.dart` / `app_spacing.dart` 之一
- 记录: `docs/_context/decisions.md` (添加 ADR)

## 6. 模板示例

### 示例 1: 新增颜色

```dart
// 改动: lib/core/theme/app_colors.dart

class AppColors {
  // 基础颜色
  static const Color primary = Color(0xFF1A73E8);
  static const Color secondary = Color(0xFF34A853);
  
  // ✨ 新增颜色（新）
  static const Color warning = Color(0xFFEA8B00);
  static const Color error = Color(0xFFD33B27);
  static const Color success = Color(0xFF0D652D);
  
  // 分类标签色（示例，根据业务调整）
  static const Map<String, Color> categoryColors = {
    'system': Color(0xFF1A73E8),
    'update': Color(0xFFEA8B00),
    'activity': Color(0xFF34A853),
  };
}

// 追加 ADR:
## ADR-012 | 2026-04-10 | 新增警告/成功/错误颜色

### 决策
新增 3 个语义颜色: warning (橙) / error (红) / success (绿)

### 理由
1. 多功能模块需要区分不同状态色
2. Material 3 设计规范推荐的颜色体系
3. 国际化设计易识别

### 影响范围
- 所有 UI 组件中状态标签
- 错误提示、加载提示
- 分类标签等

### 拍板人
@lead

### 状态
active
```

### 示例 2: 新增字体规范

```dart
// 改动: lib/core/theme/app_text_styles.dart

class AppTextStyles {
  // 已有
  static const TextStyle headline1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );

  // ✨ 新增（新）
  static const TextStyle tagSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  static const TextStyle captionLink = TextStyle(
    fontSize: 12,
    color: AppColors.primary,
    decoration: TextDecoration.underline,
  );
}

// 追加 ADR:
## ADR-013 | 2026-04-10 | 新增 tag 和 link 字体规范

### 决策
新增 tagSmall 和 captionLink 两个字体规范

### 理由
1. Tag 组件需要更小、更紧凑的字体
2. Link 需要下划线和主色标识
3. 统一设计，避免页面内字体杂乱

### 影响范围
- 所有 Tag 组件
- 可交互链接文本
- 分类标签等

### 拍板人
@lead

### 状态
active
```

### 示例 3: 新增 Spacing 规范

```dart
// 改动: lib/core/theme/app_spacing.dart (或统一到 constants 中)

class AppSpacing {
  // 已有
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  // ✨ 新增（新）
  static const double xl = 20;
  static const double xxl = 24;
  
  // 也可按用途命名
  static const double cardPadding = 16;        // 卡片内框距
  static const double screenHorizontal = 12;   // 屏幕两侧 padding
  static const double listItemHeight = 56;     // 列表项最小高度
}

// 追加 ADR:
## ADR-014 | 2026-04-10 | 扩展 spacing 规范至 xxl 和用途命名

### 决策
1. 扩展基础 spacing: xs(4) → xxl(24)
2. 新增用途命名: cardPadding / screenHorizontal / listItemHeight

### 理由
1. 现有 spacing 不够用，lg(16) 之后无更大选项
2. 用途命名代替魔法数字，代码可读性更高
3. 便于未来调整（改 `cardPadding = 20` 即可影响所有卡片）

### 影响范围
- 所有涉及 padding/margin 的组件
- 卡片、列表项、屏幕边距等

### 拍板人
@lead

### 状态
active
```

## 7. 不做什么

- ❌ 不改代码中的具体 padding 值 (修改主题文件后，代码自动生效)
- ❌ 不修改 Material 主题 (`ThemeData`)
- ❌ 不改图标字体 (那是另一个话题)
- ❌ 不生成设计稿 (只改代码配置)
- ❌ 不自动 commit

## 8. 自检 Checklist

- [ ] 现有主题配置都读过了
- [ ] 新增项是否与已有项冲突
- [ ] 颜色/字号是否符合设计规范
- [ ] 追加了 ADR 到 decisions.md
- [ ] 影响范围清晰
- [ ] 给出了代码示例

## 9. 失败处理

**改动冲突或不确定时:**
> ASK_USER "这个颜色和 {现有颜色} 很接近，确认要新增吗？或者改用现有的？"

**影响范围太大时:**
> "这个改动会影响 {N} 个组件，建议先在 1-2 个关键组件试验，效果好了再全量推进。"

## 10. 联动

**成功后:**
> "✅ 主题配置已更新。
> - 新增: {改动内容}
> - 影响组件: {列表}
> - ADR 已追加到 decisions.md
> 
> 建议后续: 用 `flutter-lint-fix` 检查代码格式"

**上游:**
- flutter-design-to-code (设计稿中提取的颜色/字体)
- flutter-spec (设计文档中提到的主题调整)

**下游:**
- flutter-page-gen / flutter-widget-gen (使用新主题)
- flutter-review (检查是否正确使用新主题)
