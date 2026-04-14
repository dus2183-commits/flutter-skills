---
name: flutter-post-figma
description: figma-implement-design 后处理器。在 figma MCP 生成完 UI 代码后触发,把 MCP 产出的扁平代码补全成项目规范结构(下载 CDN 图到 assets/image/3.0x/{module}/、改 Image.network 为 Image.asset、加 Controller+Binding、登记路由、反推 spec/plan、归档 manifest、生成测试 + review)。和 figma-implement-design 搭配使用,不抢活只补全。
type: skill
stage: post
model: sonnet
priority: P0
version: 1.0.0
owner: @tg
category: post-processor
---

# Figma 后处理 (flutter-post-figma)

## 1. 触发场景

- `figma-implement-design` 刚跑完,生成了 UI 代码(一般在 `lib/features/{m}/` 或项目根的散落位置)
- 用户说"Figma 代码补全" / "把 figma 生成的代码整理成规范结构"
- router.sh 检测到 Figma URL + 功能开发意图时,默认触发 **"figma-implement-design → flutter-post-figma"** 串行链

**反例(不要用这个 skill):**
- 还没跑 figma-implement-design → 先让 MCP 跑,再进这个 skill
- 纯自然语言需求(无 Figma) → 用 `flutter-flow-feature`
- 纯 UI 改版且已有设计稿抓取 → 用 `flutter-design-to-code`

## 2. 核心分工

```
figma-implement-design (MCP 原生)     flutter-post-figma (本 skill)
─────────────────────────────         ─────────────────────────────
读 Figma 节点树                         接管 MCP 产出
解析 UI 结构(Stack/Column/Row)         扫描代码里的 Figma CDN URL
生成 Dart widget 代码                  curl 下载到 assets/image/3.0x/{m}/
处理矩形/文字/颜色/位置                改 Image.network → Image.asset
                                      移到三件套结构(Page/Controller/Binding)
                                      登记路由 + 更新 pubspec
                                      反推 spec.md + plan.md
                                      产出 manifest-v{N}.yaml 归档
                                      写单元测试
                                      跑 analyze + 产 review
```

## 3. 前置必读

- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `_design/app_exception.dart`
- **figma-implement-design 刚产出的文件**(在 `lib/features/{m}/` 或其他位置)

## 4. 输入

- `module_name`: snake_case 模块名(如 `splash`)
- `mcp_output_paths[]`: figma-implement-design 生成的 Dart 文件路径(可能多个)
- 可选:`docs/_context/api-global.yaml`(有接口需求时用)

## 5. 执行步骤(10 步)

### Step 1 — 扫描 MCP 产出

读所有 MCP 生成的 `.dart` 文件,提取:
1. 主要 Widget 类名(如 `SplashPage` / `LoginPage`)
2. 所有 `Image.network("https://www.figma.com/api/mcp/asset/...")` 或 `'https://...'` 字符串
3. 所有 `SvgPicture.network(...)` 同理
4. 硬编码的 Color / EdgeInsets / 尺寸(为后续 flutter_screenutil 改造做准备)

输出一个**资源清单**给用户看:
```
扫到 5 个图资源:
  [1] Image.network "https://www.figma.com/api/mcp/asset/abc..." (line 12)
  [2] Image.network "https://www.figma.com/api/mcp/asset/def..." (line 23)
  ...
建议命名:
  [1] → logo_splash.png
  [2] → img_splash_1.png
  ...
```

### Step 2 — 下载资源

生成单行 curl 清单(不要自己跑):
```bash
cd /Users/tg/Desktop/d/{project}/assets/image/3.0x/{module}

curl -L -o logo_splash.png "https://www.figma.com/api/mcp/asset/abc..."

curl -L -o img_splash_1.png "https://www.figma.com/api/mcp/asset/def..."

ls -lh
```

**⛔ 不要自己跑 curl,给用户清单让他终端粘贴运行**(避免权限/网络问题卡住)。

等用户说"图下完了"再进 Step 3。

### Step 3 — 验证下载(不用 Read)

```bash
ls -lh assets/image/3.0x/{module}/
file assets/image/3.0x/{module}/*.png
```

**⛔ 禁止用 Read 工具读图片文件**(>1MB 会 API 400 卡死),用 Bash 代替。

### Step 4 — 改写代码引用

把 MCP 产出的:
```dart
Image.network('https://www.figma.com/api/mcp/asset/abc...')
```
改成:
```dart
Image.asset('assets/image/3.0x/{module}/logo_splash.png', fit: BoxFit.cover)
```

SVG 同理:`SvgPicture.network(...)` → `SvgPicture.asset(...)`

如果某张图 curl 没下来(size=0 或不存在),改成占位:
```dart
// TODO(post-figma): 替换为 assets/image/3.0x/splash/img_splash_1.png
Container(
  color: Colors.grey[300],
  decoration: BoxDecoration(border: Border.all(color: Colors.red)),
  child: Center(child: Text('TODO: img_splash_1', style: TextStyle(color: Colors.red))),
)
```

### Step 5 — 拆三件套结构

MCP 一般把所有东西塞在一个 Page 类里。要拆成:
- `lib/features/{m}/presentation/pages/{page_name}/{page_name}_page.dart` — View(GetView<Controller>)
- `lib/features/{m}/presentation/pages/{page_name}/{page_name}_controller.dart` — GetxController
- `lib/features/{m}/presentation/pages/{page_name}/{page_name}_binding.dart` — Bindings

MCP 生成的如果是 StatelessWidget + 无状态,可以直接改 extends GetView<Controller>。
有状态逻辑的(定时器/异步/用户输入),把 setState 搬到 Controller 的 obs 变量里。

### Step 6 — 加响应式

如果项目用了 `flutter_screenutil`:
- 硬编码尺寸 `80` → `80.w`
- 字号 `16` → `16.sp`
- 圆角 `8` → `8.r`

判断:看 `pubspec.yaml` 有 `flutter_screenutil` 就加,没有跳过。

### Step 7 — 登记路由 + pubspec

1. `lib/app/routes/app_routes.dart` 加路由常量(如果没有)
2. `lib/app/routes/app_pages.dart` 的 `routes` 列表加 GetPage
3. `pubspec.yaml` 的 `flutter: assets:` 段加 `- assets/image/3.0x/{module}/`(如果没有)
4. `fvm flutter pub get`

### Step 8 — 反推文档

**产出 `docs/specs/{module}.md`**(7 段齐):
- 从 Page 类的 UI 结构推断"涉及页面" / "页面流转"
- 从 Controller 的方法推断"接口需求"(如果 Controller 调了 repo)
- 从 UI 元素推断"关键字段"
- 异常场景至少 3 条(网络错误 / 加载中 / 空数据)

**产出 `docs/plans/{module}.md`**:任务清单 + 依赖图(已完成,回顾性 plan)

**产出 `docs/manifests/manifest-v{N}.yaml`**:归档(N = 下一个版本号)

### Step 9 — 测试 + review

- `test/features/{m}/{m}_controller_test.dart` — Controller 的核心方法测试
- `docs/review/{date}-{m}.md` — review 报告,列出:
  - MCP 生成了什么(UI)
  - post-figma 做了什么(结构/资源/文档)
  - 遗留项(没下完的图、没测的分支)
  - 下一步建议

### Step 10 — 验证

- `fvm flutter analyze` 必须 0 error
- `fvm flutter test test/features/{m}/` 必须通过

## 6. 输出产物

```
lib/features/{m}/presentation/pages/{page}/
├── {page}_page.dart          ← 基于 MCP 产出改造
├── {page}_controller.dart    ← 新建(从 MCP 代码提取状态)
└── {page}_binding.dart       ← 新建(tearoff 模式)

lib/features/{m}/data/        ← 如果有接口(无接口可省)
├── models/
├── repositories/
└── mock/

assets/image/3.0x/{m}/        ← 下载的图
├── logo_*.png / .svg
├── img_*_1.png
└── ...

docs/specs/{m}.md             ← 反推的 spec
docs/plans/{m}.md             ← 反推的 plan
docs/manifests/manifest-v{N}.yaml  ← 归档
docs/review/{date}-{m}.md     ← review

test/features/{m}/            ← 测试

pubspec.yaml                  ← assets 段更新
lib/app/routes/app_pages.dart ← 路由登记
```

## 7. 常见错误

### ❌ 自己跑 curl
给清单让用户跑,避开权限/卡顿问题。

### ❌ Read 大图文件
API 400 必卡。用 `ls -lh` / `file` 验证。

### ❌ 直接用 MCP 产出的代码不改
MCP 产出缺 Controller/Binding/路由登记/测试,必须补。

### ❌ 图没下完就硬链 Image.asset
会报错 "Unable to load asset"。必须用占位块 + TODO。

### ❌ 跳过反推 spec/plan
归档缺失,后续无法回溯。

## 8. 退出条件

- ✅ `lib/features/{m}/presentation/pages/{page}/` 三件套齐
- ✅ `assets/image/3.0x/{m}/` 所有图存在(或占位 TODO 明确)
- ✅ 代码里没有 `figma.com/api/mcp/asset` 硬编码(reflector 会拦截)
- ✅ `docs/specs/{m}.md` / `docs/plans/{m}.md` / `docs/manifests/manifest-v{N}.yaml` 存在
- ✅ `test/features/{m}/` 存在
- ✅ `docs/review/{date}-{m}.md` 存在
- ✅ `fvm flutter analyze` 0 error

## 9. 和其他 skill 的关系

| Skill | 职责 |
|---|---|
| `figma-implement-design` (MCP 原生) | 从 Figma 生成 UI Dart 代码 |
| **`flutter-post-figma` (本 skill)** | **接手 MCP 产出,补全成规范结构** |
| `flutter-flow-feature` | 无 Figma 时的自然语言开发 |
| `flutter-design-to-code` | 纯 UI 改版(不走完整 9 步) |
| `flutter-page-gen` | 被 post-figma 调用来生成三件套骨架 |
| `flutter-manifest-init` | 被 post-figma 调用来归档 |

**典型调用链:**
```
用户 "做 X 页 [figma URL]"
   ↓
router.sh stdout 注入: "先 figma-implement-design,再 flutter-post-figma"
   ↓
figma-implement-design 跑(MCP)
   ↓
flutter-post-figma 接力(本 skill)
   ↓
完成
```
