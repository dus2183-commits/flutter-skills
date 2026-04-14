---
name: flutter-design-to-code
description: Figma/Zeplin/截图 → Flutter 代码（自动下载 3x 切图 + Token 映射 + 按项目命名规范）。用户说"根据 Figma 生成页面"、"把这个设计稿变成代码"、"按设计稿生成代码"、"读取 Figma 设计"、"实现这个 Figma 设计"、"Implement this design from Figma"、"从 Zeplin 切图"、"把这个截图转成 Flutter"、"重新设计 XX 页"（含 Figma 链接时）时触发。⚠️ 这个 skill 比 figma:figma-implement-design 优先 — 因为它会按项目规范下载切图(3x + ic_/bg_ 命名 + assets/image/3.0x/{module}/)并更新 pubspec.yaml,而不是用临时 MCP URL。内部会调 figma:figma-implement-design 或 use_figma 拿数据,但后续处理完全按项目规范走。
type: skill
stage: 4
model: opus
priority: P1
version: 1.0.0
owner: @c
category: bridge
---

# 设计稿转代码 (flutter-design-to-code)

## ⛔ 铁律（违反立即停止）

0. **MCP 下图必须用"返回 URL"的方式,禁止用 base64。**
   - 正确: `get_screenshot` / `get_image_url` / `use_figma(return_url=true)` 返回 URL,然后 `curl -o 本地路径 "URL"` 下载
   - 错误: `export_image` 返回 base64 → 切分 chunk → 拼接 → 解码(大图会截断,1MB+ 就崩)
   - 如果只有 base64 方式,先 `data:image/png;base64,xxx` 写到临时文件再 mv
   - 最糟的情况: 告诉用户手动从 Figma 导出,不要硬试 base64 chunking
1. **禁止把 Figma MCP 的临时 URL 当生产代码。** MCP 返回的 `https://www.figma.com/api/mcp/asset/...` 只有 7 天有效期,**必须**立刻 curl 下载到本地 `assets/image/3.0x/{module}/`。
2. **禁止用 `Image.network` 当图片占位。** 项目有 `AppImage` / `AppNetworkImage` 组件,统一用这个。本地 Asset 用 `Image.asset` 或封装组件。
3. **禁止使用驼峰 / 中文命名图片文件。** 必须按 conventions.md 段 11.1 规则: `ic_/bg_/btn_/img_/avatar_/logo_` 前缀 + snake_case。
4. **禁止跳过 pubspec.yaml 注册。** 下载完必须在 `pubspec.yaml` 的 `assets:` 加对应目录,否则打包后读不到。
5. **禁止用 const String 把 URL 硬编码到 Dart 文件里。** 这会把临时 URL 带进生产代码。
6. **优先调用本 skill,不要直接用 `figma:figma-implement-design`。** 那个是通用工具,不知道项目规范。

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

- Figma URL → `figma:figma-implement-design` MCP
- 截图/Zeplin → Claude vision
- 图片 URL → 先 curl 下载再 vision

**Step 2 — Figma 必须调 MCP (不要自己瞎猜)**

**⛔ 禁止只看 URL 凭想象写代码。必须真正调用 MCP 工具:**

```
1. 先调 figma:figma-use (必读前置,不要跳)
2. 再调 use_figma 工具 (具体参数看 figma-use 说明)
3. MCP 返回: 布局结构 / 颜色 / 字体 / 组件 / 图片资源 URL
```

**Step 2.2 — 布局转换对照表**

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
| 文本段落 | `Text` + `TextStyle` (引用 AppTextStyles) |

**像素说明:** Figma @ 1x 的像素值直接对应 Flutter 逻辑像素,无需换算。

**Step 2.3 — Token 映射规则**

将设计稿 Token 映射到项目 theme 文件,**颜色/字体/间距不允许在 Widget 中硬编码**:

| 类别 | 检查 | 缺失时 |
|------|------|--------|
| 颜色 | 对照 `AppColors`,有的直接引用 | 列入新增清单 → 交给 theme-design |
| 字体 | 对照 `AppTextStyles` | 同上 |
| 间距 | 对照 `AppSpacing` | 同上（或直接用数字 + 注释） |
| 图标 | 对照 `assets/image/ic_*` | 下载 Figma 切图 |
| 图片 | 对照 `assets/image/` | 下载 Figma 切图 |

**特殊阴影色**（如 `Color(0x14000000)` 8% 黑）可保留硬编码,加注释说明 Figma Token 名。

**Step 2.5 — 自动下载切图 (Figma 才能做) ★ 默认 3x**

MCP 返回里有 `images[].url`（Figma 提供的临时 PNG/SVG URL）。**必须下载**。

**调 MCP 前必须 ASK_USER 确认倍数**:
```
问: "图片导几倍? (1) 3x (默认,推荐) (2) 2x (3) 1x+2x+3x 完整倍图"
```

**默认 3x 策略:**
- 调 `use_figma(scale=3)` 拿到 3x URL
- 保存到 `assets/image/3.0x/{module}/`
- Flutter 自动按设备 devicePixelRatio 降级,1x/2x 设备也能用

**⛔ 文件名必须按 conventions.md 段 11.1 规则（前缀_模块_名称）：**

| 图片类型 | 前缀 | 示例 |
|---------|------|------|
| 图标 | `ic_` | `ic_home_bell.png` |
| 背景 | `bg_` | `bg_login.png` |
| 按钮 | `btn_` | `btn_submit.png` |
| 插图/空态 | `img_` | `img_empty_list.png` |
| 头像 | `avatar_` | `avatar_default.png` |
| Logo | `logo_` | `logo_app.png` |

**Figma 原名可能是 "Icon/home/Bell" 或中文 "首页-铃铛"，下载时必须重命名:**
- `Icon/home/Bell` → `ic_home_bell.png`
- `首页-铃铛` → `ic_home_bell.png`（翻译或音译）
- **禁止**保留驼峰、中文、特殊字符

```bash
# 3x 默认 (示例：从 Figma 的 "Icon/home/Bell" 导出)
mkdir -p assets/image/3.0x/{module}
curl -L -o "assets/image/3.0x/home/ic_home_bell.png" "{figma_url_3x}"
curl -L -o "assets/image/3.0x/home/bg_home_banner.png" "{figma_url_3x_2}"
```

**完整倍图（用户选 1+2+3）:**
```bash
mkdir -p assets/image/{module} assets/image/2.0x/{module} assets/image/3.0x/{module}
curl -L -o "assets/image/{module}/ic_{name}.png" "{url_1x}"
curl -L -o "assets/image/2.0x/{module}/ic_{name}.png" "{url_2x}"
curl -L -o "assets/image/3.0x/{module}/ic_{name}.png" "{url_3x}"
```

更新 `pubspec.yaml`（Flutter 认 N.0x 目录）:
```yaml
flutter:
  assets:
    - assets/image/3.0x/{module}/
```

**curl 失败时的 3 级降级(禁止降级到"用文字"):**

**Level 1 — curl 权限被拒 或 自动下载任何原因失败:**

不要 fallback 到文字。直接产出 **可复制粘贴的 curl 清单** + 目标路径 + 重命名后的文件名,让用户一键跑:

⛔ **curl 格式硬性规则(违反 = 用户粘贴就报错):**
1. **每条 curl 必须单行**,禁止用 `\` 反斜杠换行分成多行(用户复制会断行)
2. **URL 必须用双引号**包起来(包含 `&` 或 `?` 的 URL 不加引号会被 shell 解析)
3. **一行只做一件事**:`curl -o {file} "{url}"` — 不要加 `&&` 串多个
4. **首行必须是 `cd /完整/绝对/路径`**(用户不知道当前 pwd)
5. **末尾加一条 `ls -lh` 让用户自验**

✅ 正确示例:
```bash
cd /Users/tg/Desktop/d/project/assets/image/3.0x/module

curl -L -o img_module_1.png "https://cdn.example.com/path?w=600&q=80"

curl -L -o img_module_2.png "https://cdn.example.com/path2"

ls -lh
```

❌ 错误示例(用户粘贴会断行出错):
```bash
curl -L -o img_1.png \
  "https://..."
```


````markdown
# {module} 模块切图 — 手动下载清单

由于 curl 权限被拒(或自动下载失败),请在终端复制粘贴以下命令:

```bash
cd /Users/tg/Desktop/d/{project_name}

# 创建目标目录
mkdir -p assets/image/3.0x/{module}

# 下载并改名(文件名已按规范命名,直接跑)
curl -L -o "assets/image/3.0x/{module}/logo_app.png" \
  "https://www.figma.com/api/mcp/asset/92a13c99-eead-4215-9f2b-738647369674"
curl -L -o "assets/image/3.0x/{module}/img_splash_diamond_1.png" \
  "https://www.figma.com/api/mcp/asset/xxxx-yyyy-zzzz-1"
curl -L -o "assets/image/3.0x/{module}/img_splash_diamond_2.png" \
  "https://www.figma.com/api/mcp/asset/xxxx-yyyy-zzzz-2"
# ... 更多切图
```

或者改 `.claude/settings.json`:
1. 打开 `.claude/settings.json`
2. `Bash(curl:*)` 从 `deny` 移到 `allow`
3. 回来说 "curl 权限已开,重试下载"

验证(运行完检查):
```bash
ls -lh assets/image/3.0x/{module}/
# 应看到所有文件,大小 > 0
```

下载完告诉我 "切图下载完成",我继续改代码。
````

⛔ **硬性要求:**
- curl 命令的 `-o` 后的路径必须是 **完整目标路径** + **重命名后的文件名**(不能让用户再改)
- 文件名遵循段 "文件命名规则"(ic_/bg_/btn_/img_/avatar_/logo_)
- 命令可直接从终端复制粘贴运行,0 修改

❌ 不要自己 fallback 到"用文字 logo",这是糟糕 UX。
❌ 不要让用户自己想文件名 — 你必须把对应关系算好给他。

**Level 2 — MCP 不给 URL(Figma 权限限制):**
生成 `docs/manual-download-{module}.md`,列出所有切图:
```markdown
# {module} 模块手动下载清单

以下切图 Figma MCP 无法自动下载,请手动操作:

1. Figma 里打开节点 `1:43`
2. 选中以下图层,Export 为 3x PNG
3. 下载后重命名并放到指定路径

| Figma 图层 | 重命名为 | 目标路径 |
|---|---|---|
| Icon/home/Bell | ic_home_bell.png | assets/image/3.0x/home/ |
| Logo/AppLogo | logo_app.png | assets/image/3.0x/splash/ |
...

下载完跑: `fvm flutter pub get`,然后说"切图已手动放置,继续"。
```
❌ 不要 fallback 到文字。

**Level 3 — 用户确认手动搞不定:**
临时用 Flutter 自带的占位图标(`Icons.image` / 灰色 Container),但 **必须在代码里加 TODO:**
```dart
// TODO: 替换为 assets/image/3.0x/splash/logo_app.png (Figma node 1:43)
Container(width: 80, height: 80, color: Colors.grey[300])
```
并在 `docs/review/{date}-{module}.md` 的 "遗留项" 段记录。

## ⚠️ 占位规则(结构 vs 降级的分界)

**核心原则: 宁可难看,不可无物。**

开发期 Figma 图拿不到时:
- ✅ **必须渲染一个可见的占位元素**,保留原设计的位置/尺寸/形状(菱形就是菱形,圆就是圆)
- ✅ 占位元素**必须有明显标记**(虚线边框 / 灰色背景 / "TODO: 替换照片" 文字),让 review 一眼看出
- ❌ **禁止什么都不渲染**(让 UI 结构完整丢失)
- ❌ **禁止把占位当最终交付**(没下完图就汇报 "✅ 完成")

**占位的标准写法:**
```dart
// ✅ 好的占位:保留结构 + 明显标记 + TODO 注释
// TODO(splash): 替换为 assets/image/3.0x/splash/img_splash_1.png (Figma node 1:43 child[0])
Container(
  width: 120.w,
  height: 120.w,
  decoration: BoxDecoration(
    color: Colors.grey[300],
    border: Border.all(color: Colors.red, width: 2, style: BorderStyle.solid),
    borderRadius: BorderRadius.circular(20.r),
  ),
  child: Center(
    child: Text(
      'TODO: img_splash_1',
      style: TextStyle(fontSize: 10.sp, color: Colors.red),
    ),
  ),
)
```

**同时必须产出 `docs/manual-download-{module}.md`** 列出所有待下载资源(含 curl 清单),
让用户/开发跟得上进度。

---

**3 种硬性禁止的 fallback(这些改变了设计意图,不是占位):**
1. 把图形元素改成文字(Image → Text)— 完全换元素
2. 把原本 4 个元素改成 2 个(减数量)或 6 个(加数量)
3. 把原本的形状改变(菱形→矩形,圆→方)

**但这些"状态占位"是允许的(不是 fallback,是 UI 状态):**
| 场景 | 允许做法 | 理由 |
|---|---|---|
| 用户头像未上传 | `Icons.person` + 圆形背景 | 业务上本来就没图 |
| 列表空状态 | 灰色插画 + "暂无数据" 文字 | 空数据状态不是缺资源 |
| 图片加载中(CachedNetworkImage placeholder) | `CircularProgressIndicator` / 灰块 | 异步加载必须有过渡态 |
| 图片加载失败(errorWidget) | 错误图标 + 重试按钮 | 容错设计 |
| Mock 头像 / 默认封面 | 品牌色 Container + 用户名首字母 | 缺图时的合理兜底 |

**区分标准**:
- ✅ "这个位置**运行时可能**没资源" → 占位合理
- ❌ "设计稿**明确画了**这个图,但我懒得下载" → 降级违规

判断法:**Figma 里那个节点有 image fill 或 export enabled 吗?**
- 有 → 必须下载到本地,不许占位代替
- 没有(只是 rect + color) → 按 Figma 画 Container 即可,无需下载

**硬性禁止的布局做法(违反 = 跟 Figma 对不齐):**
1. ❌ 凭"视觉印象"猜 Positioned 的 top/left 数值
2. ❌ 不读 Figma 节点的 boundingBox 就开写 Stack
3. ❌ 忽略 Figma 的 rotation(旋转角度)/ effects(阴影/模糊)/ opacity
4. ❌ 不管 z-order(图层叠加顺序),随便 Stack children 顺序

**必须做的(每个位置敏感的节点):**
1. 调 `figma:get_design_context` 或 `get_metadata` 拿到每个子节点的:
   - `boundingBox: {x, y, width, height}` — 绝对坐标
   - `rotation` — 旋转角度(弧度)
   - `effects[]` — 阴影/模糊/渐变
   - `opacity` — 透明度
   - z-order — 图层顺序(子节点数组顺序 = 从底到顶)
2. **把读到的数据先打印给用户看确认**,再写代码:
   ```
   节点 1:43 有 4 个 Diamond 子节点:
   - [0] x=100 y=50 size=120x120 rotation=0.785rad shadow=(0,4,16,rgba(0,0,0,0.3))
   - [1] x=220 y=150 size=100x100 rotation=0.785rad shadow=...
   ...
   ```
3. 用 `Stack` + `Positioned` 按这些精确值还原,**不修改数字**:
   ```dart
   Positioned(
     left: 100.w,           // ★ 响应式,用 flutter_screenutil .w
     top: 50.h,             // ★ .h 对高度
     child: Transform.rotate(
       angle: 0.785,
       child: Container(
         width: 120.w,
         height: 120.w,     // 正方形用 .w 不用 .h(避免纵横比失真)
         decoration: BoxDecoration(
           boxShadow: [BoxShadow(offset: Offset(0, 4), blurRadius: 16, color: Color(0x4D000000))],
         ),
         child: ...,
       ),
     ),
   )
   ```

**照片 fallback 顺序(从好到差,每一级都要试):**
1. Figma MCP 拿 imageRef + Figma API 下载 → 最佳
2. 问用户有没有切图(manual_assets 或手动贴路径)→ 次佳
3. 用 Unsplash / Pexels 免费公开图(4xx 张风格接近的)→ 可接受的 placeholder
4. 灰色 Container + TODO 注释 + review.md 遗留项 → 最后兜底

⛔ **禁止跳过 1-3 级直接到"渐变色块" 或 "Icon 图标"**,这不是 fallback 是改设计。

---

**如果 MCP 不给 URL**（Figma 权限限制）→ 降级到 Level 2 切图清单方案

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
- ✅ Figma 场景自动切图 (调 figma MCP 拿 URL + curl 下载)
- ❌ Zeplin / 截图场景不自动切图 (用户手工导出)
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
