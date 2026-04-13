---
name: flutter-init
description: 初始化新 Flutter 项目脚手架。用户说"新建 Flutter 项目"、"初始化 Flutter 项目"、 或在空目录下询问"怎么开始"时触发。从 template/ 复制完整脚手架,带 GetX + 三端兼容 + 接口加密 + Mock 开关 + 5-Tab 主壳 + 完整 docs/_context/。
type: skill
stage: 0
model: sonnet
priority: P0
version: 1.0.0
owner: @lead
category: generator
---

# 项目初始化 (flutter-init)

> 一次性 skill。给一个空目录,生成可立即 `flutter run` 的 Flutter 项目。

---

## 1. 触发场景

- "新建 Flutter 项目" / "初始化 Flutter 项目"
- "创建一个 Flutter 工程"
- "搭建 Flutter 脚手架"
- 空目录下用户询问"怎么开始"
- 用户说"按 yc141 那一套搭一个项目"

**反例(不应触发):**
- 已有 Flutter 项目时(应触发 health-check 或其他)
- 用户问"怎么用 Flutter"(应该回答而非生成代码)

---

## 2. 前置必读

- `_design/api_client_signature.dart` (理解 ApiClient 接口)
- `_design/app_exception.dart` (理解异常体系)
- `template/` 目录下的所有内容(本 skill 的源)

**注意:** flutter-init 不读 docs/_context/(因为还没有,本 skill 创建)。

---

## 3. 输入

**必填参数(必须 ask user 确认):**
- `project_name` (string, snake_case) — 项目名,如 `swift_app`
- `package_name` (string, reverse-domain) — 包名,如 `com.company.swift`
- `project_type` (enum) — **项目类型**:
  - **`standard`** (默认) — 普通业务项目,不含视频组件
  - **`video`** — 视频项目,含完整播放器 (横屏+竖屏短视频+加密视频+手势控制)
- `code_style` (enum) — **代码规范等级**:
  - **`full`** (默认) — 完整规范: freezed + ApiClient + mockKey + tearoff + EasyRefresh，所有 skill 生效
  - **`light`** — 轻量规范: 用 GetX 但不强制 freezed/ApiClient/mock，手写 model 和直接 dio 都可以
  - **`free`** — 自由模式: 不强制任何规范，CLAUDE.md 只保留目录结构约定
- `target_platforms` (list) — 目标平台,默认 `[android, ios, web]`
  - 可选: `[android, ios, web, macos, windows, linux]`

**可选参数(可省略,有默认值):**
- `tab_names` (list of N strings) — 底部 Tab 名,**任意数量(0-N)**
  - 默认: `[首页, 分类, 发现, 消息, 我的]` (5 个常见场景)
  - 可以是 1 个: `[首页]` (单页 App,自动隐藏底部栏)
  - 可以是 3 个: `[首页, 发现, 我的]`
  - 可以是 7 个: 加 `[..., 设置, 关于]` (但建议 ≤ 5)
  - 可以是 0 个: `[]` (无底部栏,启动直接跳业务首页)
- `enable_encryption` (bool, default true) — 是否启用接口加密
- `encrypt_mode` (enum, default 'static') — 加密模式: static (固定 key + Base64) / dynamic (requestId + GZIP)
- `enable_mock` (bool, default true) — 是否启用 Mock 开关
- `lead_name` (string) — 项目负责人,写入 decisions.md

**Tab 配置说明(数据驱动):**
- Template 默认 5 个 Tab,在 `lib/app/tabs.dart` 中
- `lib/app/app.dart` 是数据驱动的,自动适应 0/1/N 个 Tab
- 如果用户要 ≠ 5 个 Tab,init 流程要:
  1. 改 `lib/app/tabs.dart` 的 `tabs` 数组(加/减/改 TabConfig)
  2. 删/加 `lib/features/{xxx}/` 子目录
  3. 加/减时同步 import

**必须确认的事项(ask user):**
- 目标目录是否为空(若非空,确认是否清空)
- 是否覆盖已有 .gitignore(若存在)

---

## 4. 工作流程

### Step 1 — 检查目标目录
- bash: `ls -A {target_dir}`
- 若非空: ASK_USER "目录非空,是否清空?(yes/no)"
- 若用户拒绝: ABORT
- 若用户同意: 继续(但不实际清空,只写新文件)

### Step 2 — 收集参数
- 用 AskUserQuestion 收集 4 个必填参数
- 给默认值,让用户改或接受
- 验证 project_name 是合法 snake_case
- 验证 package_name 是合法 reverse-domain
- 验证 tab_names 长度为 5

### Step 3 — Dry-run 列出将创建的文件
- 读 template/ 目录树
- 列出将复制的文件(预估 60-80 个)
- 列出将替换占位符的文件
- 显示给用户

### Step 4 — 用户最终确认
- ASK_USER "确认创建?"
- 若拒绝: ABORT

### Step 5 — 生成 native 项目骨架 ★ 关键
**必须先用 `flutter create` 生成 android/ios/web/macos 等原生项目目录**,
否则后续 build 会报 "Missing index.html" / "unsupported Gradle project" 等。

- bash: `flutter create --platforms=android,ios,web --org {package_org} --project-name {project_name} {target_dir}`
- 这一步会生成: android/ ios/ web/index.html web/manifest.json lib/main.dart 等
- 等价于跑 `flutter create` 后的标准 Flutter 项目结构

### Step 6 — 用 template/ 覆盖增量内容
**注意: 不要覆盖 android/ ios/ macos/ 这些 native 目录(flutter create 已生成)。
只覆盖我们的"增量内容"。**

**按 project_type 裁剪:**

| 目录/文件 | standard | video |
|---|---|---|
| `lib/core/media/network_image/` | ✅ (加密图片) | ✅ |
| `lib/core/media/player/` | ❌ 跳过 | ✅ 复制 |
| `lib/shared/widgets/app_image.dart` | ✅ | ✅ |
| `lib/shared/widgets/app_video.dart` | ❌ 跳过 | ✅ 复制 |
| `lib/shared/widgets/short_video_page_view.dart` | ❌ 跳过 | ✅ 复制 |
| `pubspec.yaml` 中 `video_player` 等依赖 | ❌ 删除 | ✅ 保留 |
| `pubspec.yaml` 中 `visibility_detector` / `screen_brightness` | ❌ 删除 | ✅ 保留 |
| 其他所有文件 | ✅ | ✅ |

**standard 模式不安装的依赖:**
- `video_player` / `video_player_web` / `video_player_web_hls`
- `visibility_detector`
- `screen_brightness`

**standard 模式不复制的文件:**
- `lib/core/media/player/` 整个目录
- `lib/shared/widgets/app_video.dart`
- `lib/shared/widgets/short_video_page_view.dart`

这样 standard 项目省掉约 1500 行代码 + 5 个三方依赖，编译更快、体积更小。

- bash: 逐项 cp,跳过 android/ios/macos:
  ```bash
  cp -R {skill_dir}/template/lib        {target_dir}/                # 覆盖 lib (flutter create 的 lib/main.dart 会被替换)
  cp -R {skill_dir}/template/scripts    {target_dir}/                # ★ 新增: setup/run/build/clean 脚本
  cp -R {skill_dir}/template/mock       {target_dir}/
  cp -R {skill_dir}/template/docs       {target_dir}/
  cp -R {skill_dir}/template/web/js     {target_dir}/web/            # 只加 js,不覆盖 index.html
  cp {skill_dir}/template/pubspec.yaml  {target_dir}/
  cp {skill_dir}/template/.fvmrc        {target_dir}/                # ★ 新增: 锁定 Flutter 3.27.2
  cp {skill_dir}/template/.env.dev      {target_dir}/
  cp {skill_dir}/template/.env.prod     {target_dir}/
  cp {skill_dir}/template/CLAUDE.md     {target_dir}/
  cp {skill_dir}/template/README.md     {target_dir}/                # ★ 新增: 含 setup 说明
  cp {skill_dir}/template/.gitignore    {target_dir}/
  cp {skill_dir}/template/analysis_options.yaml {target_dir}/
  cp -R {skill_dir}/template/.vscode    {target_dir}/                # ★ settings.json 配 fvm 路径
  cp -R {skill_dir}/template/.claude    {target_dir}/
  chmod +x {target_dir}/scripts/*.sh                                  # ★ 新增: 脚本可执行
  ```

### Step 7 — 替换占位符 + 调整 Tab 数量

**Step 7.1 — 跑替换脚本(基础占位符):**
```bash
cd {target_dir}
bash scripts/replace_placeholders.sh \
  --project-name={project_name} \
  --project-name-pascal={ProjectNamePascal} \
  --package-name={package_name} \
  --tab1={tab_names[0]:-首页} \
  --tab2={tab_names[1]:-分类} \
  --tab3={tab_names[2]:-发现} \
  --tab4={tab_names[3]:-消息} \
  --tab5={tab_names[4]:-我的} \
  --lead-name={lead_name} \
  --created-date={today}
```

**支持的占位符:**
| 占位符 | 替换为 |
|---|---|
| `{{PROJECT_NAME}}` | project_name |
| `{{PROJECT_NAME_PASCAL}}` | project_name 转 PascalCase |
| `{{PACKAGE_NAME}}` | package_name |
| `{{TAB_1_NAME}}` ~ `{{TAB_5_NAME}}` | tab_names[0..4](默认 5 个) |
| `{{LEAD_NAME}}` | lead_name |
| `{{CREATED_DATE}}` | 当前日期 YYYY-MM-DD |

**Step 7.2 — 调整 Tab 数量(如非默认 5 个)** ★

`lib/app/tabs.dart` 是数据驱动的 Tab 配置文件。如果 `tab_names` 长度 ≠ 5,需要修改它:

**情况 A: tab_names 少于 5 个 (如 3 个)**

直接重写 `lib/app/tabs.dart`:
```dart
import 'package:flutter/material.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/category/presentation/pages/category_page.dart';
import '../features/discover/presentation/pages/discover_page.dart';

class TabConfig {
  const TabConfig({required this.label, required this.icon, required this.activeIcon, required this.page});
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;
}

const tabs = <TabConfig>[
  TabConfig(label: '首页', icon: Icons.home_outlined, activeIcon: Icons.home, page: HomePage()),
  TabConfig(label: '分类', icon: Icons.category_outlined, activeIcon: Icons.category, page: CategoryPage()),
  TabConfig(label: '发现', icon: Icons.explore_outlined, activeIcon: Icons.explore, page: DiscoverPage()),
];
```
然后删除多余的 features 子目录: `rm -rf lib/features/{message,mine}`

**情况 B: tab_names 多于 5 个 (如 7 个)**

1. 创建新的 features 子目录: `lib/features/{settings,about}/presentation/pages/`
2. 创建对应 page 文件 (复制 home_page.dart 模板,改 class 名)
3. 在 tabs.dart 加入新 TabConfig

**情况 C: 0 个 Tab(无底部栏)**
```dart
const tabs = <TabConfig>[];
```
app.dart 自动显示空 Scaffold,需要把 main.dart 的 initialRoute 改成业务首页。

**Step 7.3 — 验证**
- `grep -r '{{[A-Z0-9_]*}}' lib/` 应为空
- `fvm flutter analyze` 应 0 issues

### Step 8 — 安装项目级 skill + CLAUDE.md (按 code_style)

**skill 装到项目级 `.claude/skills/`，不污染全局。**

**8.1 — 选择 CLAUDE.md:**

| code_style | CLAUDE.md | 效果 |
|---|---|---|
| `full` | `CLAUDE_full.md` | 强制 freezed + ApiClient + mockKey + tearoff，所有 skill 生效 |
| `light` | `CLAUDE_light.md` | 用 GetX 但不强制 freezed/ApiClient |
| `free` | `CLAUDE_free.md` | 只有目录结构，自由发挥 |

```bash
cp {skill_dir}/template/_claude_templates/CLAUDE_{code_style}.md {target_dir}/CLAUDE.md
```

**8.2 — 复制 skill 到项目级（必须 cp，不能软链）:**

⚠️ **Claude Code 不跟踪软链，必须直接复制 SKILL.md 文件。**

```bash
mkdir -p {target_dir}/.claude/skills
```

| code_style | 复制的 skill | 数量 |
|---|---|---|
| `full` | 全部 29 个 worker + 6 个 workflow | 35 |
| `light` | page-gen / review / lint-fix / health-check | 4 |
| `free` | 不装 | 0 |

```bash
# full 模式: 复制所有 SKILL.md
for dir in {skill_dir}/flutter-*/; do
  name=$(basename "$dir")
  if [ -f "$dir/SKILL.md" ]; then
    mkdir -p "{target_dir}/.claude/skills/$name"
    cp "$dir/SKILL.md" "{target_dir}/.claude/skills/$name/"
  fi
done
for dir in {skill_dir}/_orchestration/flutter-flow-*/; do
  name=$(basename "$dir")
  if [ -f "$dir/SKILL.md" ]; then
    mkdir -p "{target_dir}/.claude/skills/$name"
    cp "$dir/SKILL.md" "{target_dir}/.claude/skills/$name/"
  fi
done
```

init 完成后提示用户：**"请在项目目录下重新打开 Claude Code 开始开发"**
（因为 `.claude/settings.json` 权限 + `.claude/skills/` 需要重新加载）

### Step 9 — 处理 .env 文件 (原 Step 8)
- `.env.dev` 保留开发配置模板,含:
  - API key (三端三套)
  - 线路配置 (NORMAL_LINES / BACKUP_LINES)
  - **加密配置**: ENCRYPT_MODE=static, STATIC_ENCRYPT_KEY, DEBUG_ENCRYPT=true
  - 分页字段配置 (在 main.dart 中用 PageReq.pageField 设)
- `.env.prod` 保持空模板 (DEBUG_ENCRYPT=false)
- 给用户警告: ".env.dev 包含示例 key,请改为真实值后才能跑通真实接口。**生产环境 DEBUG_ENCRYPT 必须为 false**"

### Step 9 — 跑 setup.sh (一键搞定 fvm + Flutter + pub get) ★ 关键
**不要直接跑 `flutter pub get`,要走 setup.sh 锁定 Flutter 3.27.2:**

- bash: `cd {target_dir} && bash scripts/setup.sh`
- setup.sh 会自动做这几件事:
  1. 装 fvm (如未装)
  2. 下载 Flutter 3.27.2 (首次约 5-10 分钟)
  3. `fvm use 3.27.2` 创建 .fvm/flutter_sdk 软链接
  4. `fvm flutter pub get`
  5. `fvm dart run build_runner build` (如有 freezed)
- 失败处理: 若用户没装 brew/dart,提示手动装 fvm
- 若失败: 报告错误,但不 ABORT(用户可手动重跑)

### Step 10 — 三端编译验证
按 target_platforms 跑(用 fvm 包装):
- bash: `cd {target_dir} && bash scripts/build_check.sh`
- 等价于:
  - `fvm flutter build apk --debug` (android)
  - `fvm flutter build ios --no-codesign --debug` (ios,可能失败,标记为警告)
  - `fvm flutter build web` (web)

任一失败则 ASK_USER 是否继续(可能是缺依赖)。

### Step 11 — 输出 next-action 清单
告诉用户:
- 项目创建成功
- Flutter 锁定 3.27.2 (通过 .fvmrc + fvm)
- 几个文件需要手动填写(如 .env.dev 的真实 key)
- 启动命令(必须用 fvm 前缀):
  - `bash scripts/run.sh` (mock 模式,推荐)
  - `bash scripts/run.sh --no-mock` (真实接口)
  - `fvm flutter run --dart-define=USE_MOCK=true`
  - `fvm flutter run`
- 下一步建议:
  - 用 `flutter-context-update` 完善 decisions.md
  - 用 `flutter-flow-feature` 做第一个功能

---

## 5. 输出产物

```
{target_dir}/
├── .env.dev
├── .env.prod
├── .gitignore
├── .vscode/launch.json
├── .claude/settings.json
├── analysis_options.yaml
├── pubspec.yaml
├── CLAUDE.md
├── README.md
├── android/                                (Flutter 自带)
├── ios/                                    (Flutter 自带)
├── web/
│   ├── index.html
│   ├── js/
│   │   ├── image.js
│   │   ├── asmcrypto.min.js
│   │   ├── db.js
│   │   └── dexie.min.js
│   └── manifest.json
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   ├── routes/
│   │   │   ├── app_routes.dart
│   │   │   └── app_pages.dart
│   │   ├── theme/
│   │   ├── locales/
│   │   └── bindings/
│   ├── core/
│   │   ├── config/app_config.dart
│   │   ├── crypto/
│   │   │   ├── aes_dynamic.dart          动态密钥 AES (yc141 方案)
│   │   │   ├── aes_static.dart           ★ 新增: 静态密钥 AES (后端新规范)
│   │   │   ├── aes_util.dart             图片解密
│   │   │   └── hash_util.dart
│   │   ├── network/
│   │   │   ├── api_client.dart
│   │   │   ├── interceptors/             含 encrypt_interceptor (双模式)
│   │   │   ├── models/
│   │   │   └── services/
│   │   │       └── line_service.dart     ★ 新增: 线路测速 + 自动选线
│   │   ├── error/app_exception.dart
│   │   ├── mock/
│   │   │   ├── mock_loader.dart
│   │   │   └── mock_config.dart
│   │   ├── media/
│   │   │   └── network_image/            加密图片 (io/web 条件导出)
│   │   ├── storage/
│   │   └── platform/
│   ├── features/
│   │   ├── home/
│   │   ├── category/
│   │   ├── discover/
│   │   ├── message/
│   │   └── mine/
│   └── shared/
│       ├── widgets/
│       │   ├── app_image.dart            ★ 新增: 统一图片组件 (自动解密 .bnc)
│       │   └── ...                       app_text / app_button / app_loading 等
│       └── pages/
│           └── network_error_page.dart   ★ 新增: 线路全挂占位页
├── mock/
│   └── README.md
├── assets/
│   ├── image/common/
│   └── image/tabs/
├── docs/
│   └── _context/
│       ├── tech-stack.md
│       ├── conventions.md
│       ├── decisions.md
│       └── glossary.md
└── test/
    └── widget_test.dart
```

预计文件数: 60-80 个
预计大小: ~5 MB (含 web/js/ 加密 JS)

---

## 6. 代码模板

本 skill 不生成新代码,只复制 + 替换占位符。模板代码全在 `template/` 目录。

**关键文件示例(template/lib/main.dart):**

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app.dart';
import 'app/routes/app_pages.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/network/models/page_req.dart';
import 'core/network/services/line_service.dart';
import 'core/mock/mock_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 加载 .env
  await dotenv.load(fileName: '.env.dev');
  
  // ★ 分页字段名配置 (根据后端约定选一个)
  // PageReq.pageField = 'pageNum';  // 后端用 pageNum (默认)
  // PageReq.pageField = 'page';     // 后端用 page
  
  // 初始化 GetxService
  await Get.putAsync<AppConfig>(() async => DotenvAppConfig().init());
  await Get.putAsync<MockLoader>(() async => MockLoader());
  await Get.putAsync<ApiClient>(() async => ApiClient().init());
  
  // ★ 线路测速 + 自动选线 (正常线路全挂时会切备用线路)
  final lineService = await Get.putAsync(() => LineService().init());
  lineService.onAllLinesFailed = () {
    Get.offAllNamed('/network-error');
  };
  
  runApp(
    GetMaterialApp(
      title: '{{PROJECT_NAME_PASCAL}}',
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      debugShowCheckedModeBanner: false,
    ),
  );
}
```

---

## 7. 不做什么

- ❌ 不做 `git init`(用户决定)
- ❌ 不创建远程仓库
- ❌ 不修改 yc141_app(那是源,我们只读)
- ❌ 不安装 Flutter SDK(假设已装好)
- ❌ 不下载额外依赖(只跑 pub get)
- ❌ 不创建第一个业务模块(用 flutter-flow-feature)
- ❌ 不替换 .env.prod 的空值
- ❌ 不修改 hash_util.dart 已删除的 hashFile (template 已处理)
- ❌ 不生成 Reflector 代码(那是 skill 仓库的内部组件)

---

## 8. 自检 Checklist

执行完后验证:

- [ ] `flutter analyze` 在新项目中 0 error
- [ ] `flutter pub get` 成功
- [ ] `flutter build apk --debug` 成功
- [ ] `flutter build web` 成功
- [ ] `lib/main.dart` 存在
- [ ] `lib/core/network/api_client.dart` 存在
- [ ] `lib/core/crypto/aes_dynamic.dart` 存在
- [ ] `web/js/image.js` 存在
- [ ] `web/js/asmcrypto.min.js` 存在
- [ ] `.env.dev` 存在
- [ ] `docs/_context/` 4 个文件存在
- [ ] `CLAUDE.md` 存在
- [ ] 5 个 Tab 目录存在(features/home, /category, /discover, /message, /mine)
- [ ] 占位符全部替换(grep `{{` 应为空)
- [ ] `.vscode/launch.json` 含 mock + real 两套
- [ ] hash_util.dart 没有 dart:io 引用
- [ ] `lib/core/crypto/aes_static.dart` 存在
- [ ] `lib/core/network/services/line_service.dart` 存在
- [ ] `lib/shared/widgets/app_image.dart` 存在
- [ ] `lib/shared/pages/network_error_page.dart` 存在
- [ ] `.env.dev` 含 ENCRYPT_MODE + STATIC_ENCRYPT_KEY + DEBUG_ENCRYPT
- [ ] **video 类型时:** `lib/core/media/player/` 存在 + `app_video.dart` 存在
- [ ] **standard 类型时:** `lib/core/media/player/` 不存在 + pubspec 无 video_player

---

## 9. 失败处理

**ASK_USER 时机:**
- 目标目录非空
- 必填参数模糊或非法
- 任一编译失败(android/ios/web)
- 占位符替换有歧义

**STOP 时机:**
- bash cp 命令失败(磁盘满 / 权限拒绝)
- template/ 目录不存在(skill 安装错误)
- Flutter SDK 未安装

**ROLLBACK 时机:**
- 写文件过程中失败
- 用户在 dry-run 后取消
- 三端编译全部失败

**Rollback 实现:**
- 记录所有写入的文件路径
- 失败时倒序删除
- 不改动用户原有文件

---

## 10. 联动

**成功后建议:**
> "项目 {project_name} 已创建!
> 
> 启动命令:
>   flutter run --dart-define=USE_MOCK=true   (mock 模式)
>   flutter run                                (真实接口模式)
> 
> 下一步建议:
>   1. 用 `flutter-context-update` 完善 docs/_context/
>   2. 用 `flutter-flow-feature` 做第一个业务模块
>   3. 改 .env.dev 填真实 API_KEY 等"

**失败时建议:**
> "初始化失败在 Step {N}。
> 已写入的文件已 rollback。
> 错误: {error_msg}
> 解决建议: {suggestion}"

**Workflow 编排关系:**
- 上游: (用户直接触发) 或 `flutter-flow-init`
- 下游: `flutter-context-update` (完善 context) → `flutter-flow-feature` (做第一个功能)
