---
name: flutter-asset-import
description: 批量导入切图并按规范自动改名。用户说"导入切图"、"我自己切的图"、"贴图 + 自动改名"、"把这些图放进项目"时触发。支持本地路径/URL 两种输入,按 icon/bg/btn/img/avatar/logo 6 类规范改名,自动生成 3x/2x/1x 三档尺寸,更新 pubspec.yaml。
type: skill
stage: 3
model: haiku
priority: P1
version: 1.0.0
owner: @tg
category: asset
---

# 切图导入 (flutter-asset-import)

## 1. 触发场景

- "我自己切的图,帮我改名放进项目"
- "导入这批切图" / "贴图"
- "这张整图不用切,放进去就行"
- "把这个 URL 的图下载下来"
- manifest 里有 `manual_assets` 段时,由 flow-feature 自动调用

**反例(不要用这个 skill)**:
- "从 Figma 下切图" → `flutter-design-to-code`(自带下载)
- "生成 app icon 启动图" → `flutter-app-icon`(未来)

## 2. 前置必读

- `_knowledge/context-templates/conventions.template.md` — 段 11 资源命名规范
- `pubspec.yaml` — 要更新 assets 段
- `assets/images/` 目录结构:
  ```
  assets/images/
  ├── 1x/
  ├── 2x/
  └── 3x/
  ```

## 3. 输入

**方式 A:从 manifest 读(flow-feature 调用)**
```yaml
manual_assets:
  - src: ~/Desktop/logo.png
    purpose: logo
  - src: https://cdn.x.com/bg.jpg
    purpose: bg
    scene: login     # 可选,拼进文件名
```

**方式 B:用户直接调用(自然语言)**
- "导入这些图: ~/Desktop/a.png(logo), ~/Desktop/b.jpg(bg)"
- 带 URL 的:"下载 https://... 作为 post 模块的 icon"

## 4. 命名规范(严格执行)

| purpose | 改名格式 | 示例 |
|---|---|---|
| `icon` | `ic_{module}_{n}.{ext}` | `ic_post_1.png` |
| `bg` | `bg_{module}.{ext}` 或 `bg_{module}_{scene}.{ext}` | `bg_auth.png` / `bg_auth_login.png` |
| `btn` | `btn_{module}_{action}.{ext}` | `btn_post_like.png` |
| `img` | `img_{module}_{scene}.{ext}` | `img_post_empty.png` |
| `avatar` | `avatar_{module}.{ext}` 或 `avatar_{module}_{n}.{ext}` | `avatar_user.png` |
| `logo` | `logo_{module}.{ext}` | `logo_app.png` |

**拼接规则:**
- `scene`/`action` 用 snake_case(`empty_state` → `empty_state`)
- 同 purpose 多图用 `n` 序号(`n: 1, n: 2, n: 3`)
- 扩展名保留原始(`.png` / `.jpg` / `.webp` 等)
- 文件名全小写

## 5. 执行步骤

1. **收集输入清单:** 方式 A(从 manifest) 或 方式 B(对话解析)
2. **下载远程 URL:** `src` 以 `http://` / `https://` 开头 → `curl -sL {src} -o /tmp/asset_{hash}.{ext}`
3. **展开本地路径:** `~/` → `$HOME/`,校验文件存在
4. **按命名规则改名**(见段 4 表)
5. **写入 3x 目录:** 原图直接拷到 `assets/images/3x/{新文件名}`
6. **生成 2x / 1x:** 用 Dart `image` 包缩放(`fvm dart run scripts/resize_asset.dart` 或 ImageMagick `convert -resize 66.66% / 33.33%`),失败则提示用户手动补
7. **更新 `pubspec.yaml`:** 确认 assets 段已包含 `assets/images/1x/` `2x/` `3x/`(一次性加,不要逐文件)
8. **跑 `fvm flutter pub get`**
9. **输出清单:**
   ```
   ✅ 导入完成,共 {N} 个切图

   | 原路径 | 新文件名 | 位置 |
   |---|---|---|
   | ~/Desktop/logo.png | logo_auth.png | assets/images/3x + 2x + 1x |
   | https://cdn.x/bg.jpg | bg_post.jpg | assets/images/3x + 2x + 1x |

   在 Flutter 中使用:
     Image.asset('assets/images/3x/logo_auth.png')
   (AppImage widget 会自动按屏幕密度选 1x/2x/3x)
   ```

## 6. 缩放脚本 (scripts/resize_asset.dart)

如项目没这个脚本,skill 首次运行时自动生成:

```dart
// scripts/resize_asset.dart — 3x → 2x / 1x 缩放工具
import 'dart:io';
import 'package:image/image.dart';

void main(List<String> args) {
  if (args.length < 1) { print('usage: dart resize_asset.dart <file_in_3x>'); exit(1); }
  final src = args[0];
  final bytes = File(src).readAsBytesSync();
  final img = decodeImage(bytes)!;
  final name = src.split('/').last;

  final size2x = copyResize(img, width: (img.width * 2 / 3).round());
  final size1x = copyResize(img, width: (img.width * 1 / 3).round());

  final ext = name.split('.').last;
  final enc = ext == 'jpg' || ext == 'jpeg' ? encodeJpg : encodePng;

  File('assets/images/2x/$name').writeAsBytesSync(enc(size2x));
  File('assets/images/1x/$name').writeAsBytesSync(enc(size1x));
  print('✓ $name → 2x + 1x');
}
```

需要 `pubspec.yaml` 的 `dev_dependencies` 里有 `image: ^4.x`。

## 7. 常见错误

- ❌ 原图尺寸 < 3x 要求(如用户贴了 1x 小图)— 警告但仍导入
- ❌ URL 下载失败 — 重试 1 次,仍失败提示用户换链接
- ❌ 文件名和已有冲突 — 自动加 `_n` 序号
- ❌ 用户传了 `.svg` — 不缩放,直接放 `assets/images/`(SVG 无分辨率概念)
- ❌ 动图 `.gif` / `.webp` 动画 — 只拷贝不缩放

## 8. 退出条件

- ✅ 所有 `src` 文件成功落地(`assets/images/3x/` 至少有原图)
- ✅ `pubspec.yaml` 已含 assets 声明
- ✅ `fvm flutter pub get` 无错
- ✅ 用户收到改名对照表
