---
name: flutter-skeleton-gen
description: 生成 shimmer 骨架屏 Widget,替代 loading 转圈。用户说"骨架屏"、"shimmer"、"加载占位"时触发。根据页面布局自动生成对应形状的骨架。
type: skill
stage: 4
model: sonnet
priority: P2
version: 1.0.0
owner: @lead
category: generator
---

# 骨架屏生成 (flutter-skeleton-gen)

## 1. 触发场景

- "给这个页面加骨架屏"
- "shimmer loading"
- "列表加载用骨架代替转圈"
- "skeleton placeholder"

**反例:**
- "加 loading 状态" → page-gen 已有三态 (AppLoading)
- "加空状态" → AppEmptyView

## 2. 前置必读

- 目标页面代码 (分析布局结构)
- `lib/app/theme/` (颜色/间距)
- `pubspec.yaml` (确认有 `shimmer` 依赖)

## 3. 输入

**必填:**
- `source` — 目标页面文件路径

**可选:**
- `item_count` (int, default 5) — 骨架列表项数量
- `style` — card (卡片) / list (列表项) / detail (详情页) / custom

## 4. 工作流程

**Step 1 — 分析页面布局**
读目标页面代码,识别:
- 列表 → 生成列表项骨架 × N
- 图片区域 → 灰色矩形
- 文本区域 → 灰色条形 (长短不一模拟真实文本)
- 头像 → 灰色圆形

**Step 2 — 生成骨架 Widget**

**Step 3 — 在 controller loading 态替换为骨架**

**Step 4 — 自检**

## 5. 输出产物

```
lib/features/{module}/presentation/widgets/{page_name}_skeleton.dart
```

## 6. 代码模板

```dart
// announce_list_skeleton.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// 公告列表骨架屏
///
/// 用法: 替换 page 中的 AppLoading()
/// ```dart
/// if (controller.loading.value && controller.list.isEmpty) {
///   return const AnnounceListSkeleton();
/// }
/// ```
class AnnounceListSkeleton extends StatelessWidget {
  const AnnounceListSkeleton({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, __) => const _SkeletonItem(),
      ),
    );
  }
}

class _SkeletonItem extends StatelessWidget {
  const _SkeletonItem();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧图标占位
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          // 右侧文字占位
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: double.infinity, height: 16, color: Colors.white),
                const SizedBox(height: 8),
                Container(width: 200, height: 12, color: Colors.white),
                const SizedBox(height: 8),
                Container(width: 120, height: 12, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**使用方式 (在 page 中替换 AppLoading):**
```dart
// before:
if (controller.loading.value && controller.list.isEmpty) {
  return const AppLoading();
}

// after:
if (controller.loading.value && controller.list.isEmpty) {
  return const AnnounceListSkeleton();
}
```

## 7. 不做什么 (Boundary)

- ❌ 不修改 controller 逻辑
- ❌ 不添加 shimmer 依赖 (提示用户 `flutter pub add shimmer`)
- ❌ 不生成动画效果 (shimmer 包自带)
- ❌ 不替换 AppErrorView / AppEmptyView (只替换 loading)
- ❌ 不自动 commit

## 8. 自检 Checklist

- [ ] shimmer 在 pubspec.yaml 依赖中
- [ ] 骨架形状与真实页面布局对应
- [ ] 用了 `NeverScrollableScrollPhysics` (骨架列表不可滚动)
- [ ] 颜色用 `Colors.grey[300]` 和 `Colors.grey[100]`
- [ ] 有使用示例注释

## 9. 失败处理

**ASK_USER:** shimmer 包未安装
**STOP:** 目标页面不存在

## 10. 联动

**上游:** flutter-page-gen (生成页面后美化 loading)
**下游:** flutter-review (检查骨架是否匹配)
