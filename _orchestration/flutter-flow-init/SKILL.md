---
name: flutter-flow-init
description: Flutter 项目初始化流水线。用户说"新建 Flutter 项目"、"初始化项目"或在空目录下询问"怎么开始"时触发。 调用 flutter-init 复制 template,做三端编译验证,引导用户完善 docs/_context/。
type: workflow
stage: orchestration
model: opus
priority: P0
version: 1.0.0
owner: @lead
---

# 项目初始化流水线 (flutter-flow-init)

## 1. 触发场景
- "新建 Flutter 项目" / "初始化项目"
- "搭建 Flutter 脚手架"
- "按 yc141 那一套搭一个项目"
- 空目录下询问"怎么开始"

## 2. 前置必读
- `_design/api_client_signature.dart`
- `_design/app_exception.dart`

## 3. 输入
用户原始消息,可能包含项目名、包名、Tab 名、目标平台。
若缺失会在 CONFIRM_PARAMS 阶段 ask user。

## 4. 状态机定义

```
states:
  - IDLE                  初始
  - CONFIRM_PARAMS        确认参数(项目名/包名/项目类型/Tab/平台)
  - DRY_RUN               展示将创建的文件清单
  - USER_CONFIRM          等待用户最终确认
  - CREATING              调用 flutter-init 复制 template
  - REPLACING             替换占位符
  - PUB_GET               跑 flutter pub get
  - BUILD_RUNNER          跑 dart run build_runner
  - BUILD_VERIFY          三端编译验证
  - ENV_CONFIG            配置多环境 (dev/staging/prod)
  - DONE                  完成
  - ABORT                 终止
  - PAUSED                暂停

initial: IDLE
final: [DONE, ABORT]
```

## 5. Transition 规则

| 当前 | 事件 | 下个 | 条件 |
|---|---|---|---|
| IDLE | user_prompt | CONFIRM_PARAMS | - |
| CONFIRM_PARAMS | params_collected | DRY_RUN | 4 个必填参数齐全 |
| CONFIRM_PARAMS | user_cancel | ABORT | - |
| DRY_RUN | dry_run_shown | USER_CONFIRM | - |
| USER_CONFIRM | user_confirm | CREATING | 用户回答 yes |
| USER_CONFIRM | user_reject | CONFIRM_PARAMS | 用户要改参数 |
| CREATING | template_copied | REPLACING | cp 命令成功 |
| REPLACING | placeholders_replaced | PUB_GET | grep '{{' 应为空 |
| PUB_GET | pub_success | BUILD_RUNNER | exit 0 |
| PUB_GET | pub_fail | ASK_USER | exit non-0 |
| BUILD_RUNNER | gen_success | BUILD_VERIFY | exit 0 |
| BUILD_RUNNER | gen_fail | BUILD_VERIFY | (跳过,build_runner 失败不致命) |
| BUILD_VERIFY | all_pass | ENV_CONFIG | android+ios+web 全 pass |
| ENV_CONFIG | env_configured | DONE | .env.dev 配置完成 |
| BUILD_VERIFY | partial_fail | ASK_USER | 部分平台失败 |
| BUILD_VERIFY | all_fail | ABORT | 全部失败 |
| 任何 | user_abort | ABORT | - |

## 6. Worker 调用映射

| State | 调用方式 | Skill / Bash |
|---|---|---|
| CONFIRM_PARAMS | inline | (用 AskUserQuestion 收集) |
| DRY_RUN | inline | (列出 template/ 文件树) |
| CREATING | sequential | `flutter-init` (主 skill) |
| REPLACING | sequential | `flutter-init` 内部完成 |
| PUB_GET | bash | `cd {target} && flutter pub get` |
| BUILD_RUNNER | bash | `cd {target} && dart run build_runner build --delete-conflicting-outputs` |
| BUILD_VERIFY | **parallel bash** | `flutter build apk --debug` + `flutter build ios --no-codesign --debug` + `flutter build web` |
| ENV_CONFIG | sequential | `flutter-env-config` (init action,配置 dev/staging/prod 环境) |

## 7. Reflector 配置

**模型:** sonnet  
**retry 上限:** 1 (init 不太需要重试)

| State | 检查项 | 失败动作 |
|---|---|---|
| REPLACING 后 | grep '{{' 在 lib/ 应为空 | retry REPLACING (修补 skill) |
| PUB_GET 后 | pubspec.lock 存在 | ASK_USER |
| BUILD_VERIFY 后 | 三端编译产物存在 | partial fail → ASK_USER |

## 8. Checkpoint 配置

**位置:** `.flow_checkpoint/init-{project_name}-{date}/`

**写时机:**
- CONFIRM_PARAMS 后写 meta.json
- 每个 state 后更新 state.json

**清理:** DONE 后立即删除 (init 不需要保留)

## 9. 失败处理

**ASK_USER 时机:**
- 目录非空(确认是否继续)
- 必填参数缺失
- pub get 失败(可能缺依赖)
- 部分平台编译失败

**STOP 时机:**
- Flutter SDK 未安装
- 磁盘满 / 权限拒绝
- template/ 不存在(skill 安装错误)

**ROLLBACK 时机:**
- USER_CONFIRM 阶段用户取消
- BUILD_VERIFY 全部失败 → 删除已创建的文件

## 10. 进度报告

```
🚀 启动 init workflow

[1/8] ⏳ CONFIRM_PARAMS  收集项目信息...
   - 项目名: my_app
   - 包名: com.example.myapp
   - Tab: [首页/分类/发现/消息/我的]
   - 平台: [android, ios, web]

[2/8] ✅ DRY_RUN         列出将创建 67 个文件
[3/8] ✅ USER_CONFIRM    用户已确认
[4/8] ✅ CREATING        复制 template/ 完成 (3.2 MB)
[5/8] ✅ REPLACING       替换 32 个占位符
[6/8] ✅ PUB_GET         pubspec.lock 已生成 (45 个依赖)
[7/8] ✅ BUILD_RUNNER    freezed 生成 8 个文件
[8/8] ⏳ BUILD_VERIFY    并行编译 android + ios + web ...
       ✅ android (12s)
       ✅ ios (18s)
       ✅ web (8s)

✅ 项目 my_app 创建成功!
   启动: flutter run --dart-define=USE_MOCK=true
```

## 11. 自检 Checklist

- [x] 所有 state 有出口
- [x] dry-run 步骤前置(用户必须确认)
- [x] 三端编译验证(并行)
- [x] 失败可 rollback(创建的文件可删)
- [x] checkpoint 时机覆盖

## 12. 联动

**成功后:**
> "项目已创建! 下一步建议:
>   1. 编辑 .env.dev 填真实 API_KEY
>   2. 用 `flutter-context-update` 完善 docs/_context/
>   3. 用 `flutter-flow-feature` 做第一个业务模块"

**失败后:**
> "在 {state} 阶段失败,详情见 .flow_log/。
> 修复后说'重新初始化 {project_name}'"

**Workflow 编排关系:**
- 上游: (用户直接触发)
- 下游: `flutter-flow-feature` (做第一个功能)
