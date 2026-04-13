---
name: flutter-widget-gen
description: |
  生成可复用的 Widget 组件。支持无状态/有状态/响应式三种类型。
  触发场景：用户说"做一个按钮组件"、"生成 XX 卡片"、"封装一个输入框"。
type: skill
stage: 4
model: sonnet
priority: P2
version: 1.0.0
owner: @lead
category: generator
---

# 组件生成 (flutter-widget-gen)

## 1. 触发场景
- "做一个自定义按钮"
- "生成一个卡片组件"
- "封装一个信息框"
- "做 XX 列表项"
- "生成一个底部弹窗"

## 2. 前置必读
- `docs/_context/conventions.md`
- `_governance/checklists/getx-usage.md`
- `flutter-code/flutter-widget/SKILL.md` (Widget 规范)

## 3. 输入

**必填:**
- 组件功能描述

**可选:**
- `type`: StatelessWidget / StatefulWidget / Obx响应式（不指定则推荐）
- `hasController`: 是否需要访问 GetX Controller

## 4. 工作流程

**Step 1 — 判断组件类型**

根据需求判断:
- 纯展示 → **StatelessWidget + const**
- 需要状态 → **StatefulWidget**
- 需要响应 GetX 状态 → **Obx 包裹**

**Step 2 — 设计参数**

列出组件的:
- 必填参数
- 可选参数 + 默认值

**Step 3 — 生成代码**

见下方模板。

**Step 4 — 确定位置**

- 仅本模块 → `features/{module}/views/widgets/`
- 多模块复用 → `common/widgets/`

## 5. 输出产物

生成 1 个 .dart 文件（Widget 组件）。

## 6. 模板示例

### 类型 1: 纯展示组件（StatelessWidget）

```dart
// lib/common/widgets/status_badge.dart

import 'package:flutter/material.dart';

/// 状态标签组件
///
/// 用于展示业务状态，如订单状态、审核状态等。
/// 固定展示，无交互。
///
/// 示例:
/// ```dart
/// StatusBadge(
///   label: '已发布',
///   color: AppColors.success,
/// )
/// ```
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.color = const Color(0xFF1A73E8),
  });

  /// 标签文本
  final String label;

  /// 背景色，默认使用主色
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
```

---

### 类型 2: 有交互的组件（StatelessWidget + 回调）

```dart
// lib/common/widgets/app_button.dart

import 'package:flutter/material.dart';

/// 应用通用按钮
///
/// 支持多种样式（Filled / Outlined / Text）。
/// 
/// 示例:
/// ```dart
/// AppButton(
///   label: '确定',
///   onPressed: () => print('clicked'),
/// )
/// ```
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.filled,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
  });

  /// 按钮文案
  final String label;

  /// 点击回调
  final VoidCallback onPressed;

  /// 按钮样式
  final AppButtonStyle style;

  /// 按钮尺寸
  final AppButtonSize size;

  /// 是否加载中
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDisabled = isLoading;

    return SizedBox(
      height: _getHeight(),
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);

    switch (style) {
      case AppButtonStyle.filled:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        );
      case AppButtonStyle.outlined:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        );
      case AppButtonStyle.text:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        );
    }
  }

  double _getHeight() {
    switch (size) {
      case AppButtonSize.small:
        return 32;
      case AppButtonSize.medium:
        return 44;
      case AppButtonSize.large:
        return 56;
    }
  }
}

enum AppButtonStyle { filled, outlined, text }
enum AppButtonSize { small, medium, large }
```

---

### 类型 3: 响应式组件（读取 GetX 状态）

```dart
// lib/common/widgets/network_image_widget.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 网络图片加载组件（含加载/错误状态）
///
/// 自动处理加载中、加载失败、加载成功三态。
///
/// 示例:
/// ```dart
/// NetworkImageWidget(
///   imageUrl: 'https://example.com/image.jpg',
///   width: 200,
///   height: 200,
/// )
/// ```
class NetworkImageWidget extends StatelessWidget {
  const NetworkImageWidget({
    super.key,
    required this.imageUrl,
    this.width = 200,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.borderRadius = 8,
  });

  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.image_not_supported),
            ),
          );
        },
      ),
    );
  }
}
```

---

### 类型 4: 折叠框组件（有展开/收起状态）

```dart
// lib/common/widgets/collapsible_card.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 可折叠卡片
///
/// 支持点击展开/收起。
///
/// 示例:
/// ```dart
/// CollapsibleCard(
///   title: '更多详情',
///   children: [
///     Text('内容 1'),
///     Text('内容 2'),
///   ],
/// )
/// ```
class CollapsibleCard extends StatefulWidget {
  const CollapsibleCard({
    super.key,
    required this.title,
    required this.children,
    this.initialExpanded = false,
  });

  final String title;
  final List<Widget> children;
  final bool initialExpanded;

  @override
  State<CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<CollapsibleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _expandAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (_isExpanded) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(widget.title),
            trailing: RotationTransition(
              turns: _expandAnimation,
              child: const Icon(Icons.expand_more),
            ),
            onTap: _toggle,
          ),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

### 类型 5: 列表项组件

```dart
// lib/common/widgets/list_tile_widget.dart

import 'package:flutter/material.dart';

/// 自定义列表项
///
/// 用于列表中的重复单元格。
///
/// 示例:
/// ```dart
/// ListView.builder(
///   itemBuilder: (ctx, idx) => ListTileWidget(
///     title: 'Item $idx',
///     onTap: () => print('tapped'),
///   ),
/// )
/// ```
class ListTileWidget extends StatelessWidget {
  const ListTileWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.divider = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: leading,
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          trailing: trailing,
          onTap: onTap,
        ),
        if (divider) const Divider(height: 1),
      ],
    );
  }
}
```

## 7. 不做什么

- ❌ 不生成多个组件 (一次一个)
- ❌ 不修改已有组件
- ❌ 不自动注册或导出 (用户手动 import)
- ❌ 不自动 commit

## 8. 自检 Checklist

- [ ] Widget 有完整的文档注释
- [ ] 参数清晰（必填/可选）
- [ ] 有使用示例
- [ ] StatelessWidget 有 const 构造
- [ ] 响应式组件正确使用 Obx

## 9. 失败处理

**组件复杂度太高时:**
> "这个组件涉及的逻辑比较复杂。建议拆成两个小组件，先生成基础组件，再包装。"

## 10. 联动

**成功后:**
> "✅ 组件已生成。
> - 文件: {位置}
> - 使用方式: import '{路径}'
> - 可用于: {建议的应用场景}"

**下游:**
- flutter-page-gen (在页面中使用该组件)
- flutter-review (检查组件代码规范)
