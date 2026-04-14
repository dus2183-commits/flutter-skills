# 技术决策记录 (ADR)

> 每次重要技术拍板都追加一条。
> 格式: 日期 + 决策 + 理由 + 替代方案 + 影响范围 + 拍板人 + 状态。
> **追加式,不删除历史**(可标 superseded by)。

---

## ADR-001 | 2026-04-10 | 选 GetX 而非 Riverpod

### 决策
状态管理 / 路由 / 依赖注入 / Snackbar / Dialog / i18n 全部使用 GetX 4.6.x。

### 理由
1. 团队 B 和 C 已熟悉 GetX,学习成本 0
2. 一个包搞定多种能力,减少依赖
3. 路由和 DI 一体,binding 机制清晰

### 替代方案
- **Riverpod 2.x** — 类型安全更强,但团队不熟,学习成本高
- **Bloc** — 模板代码多,小项目过重
- **Provider** — 过时

### 影响范围
- 所有 Controller 必须继承 `GetxController`
- 所有 View 必须用 `GetView<Controller>`
- 所有 DI 必须在 `binding` 文件中
- 路由用 `Get.toNamed`

### 拍板人
@lead

### 状态
active

---

## ADR-002 | 2026-04-10 | 接口加密用 AES-CBC + 动态 key

### 决策
所有业务接口走 AES-CBC-256 加密,key 用 HMAC-SHA256(requestId, masterKey) 动态派生,
随机 IV,GZIP 压缩,IV+ciphertext 拼接。

### 理由
1. 工业标准,业界广泛使用
2. 动态 key 防止密文分析
3. GZIP 压缩节省流量
4. 三端三套 master key,防 web 端被滥用波及移动端
5. yc141 已生产验证

### 替代方案
- **AES-GCM** — 更安全(自带完整性校验),但 web 兼容性差
- **静态 key AES** — 不安全,密文容易被破解
- **HTTPS 不加密** — 抓包工具可看明文,业务方拒绝

### 影响范围
- `lib/core/network/interceptors/encrypt_interceptor.dart` 实现
- `lib/core/crypto/aes_dynamic.dart` 算法
- `.env` 配置 master key (web/ios/android 三套)
- 后端必须配套实现

### 拍板人
@lead

### 状态
active

---

## ADR-003 | 2026-04-10 | Mock 开关用 dart-define 编译期决定

### 决策
Mock 模式开关用 `--dart-define=USE_MOCK=true` 编译期决定,
通过 `const bool.fromEnvironment('USE_MOCK')` 读取。
Mock 数据从 `assets/mock/{module}/{api}.json` 加载。

### 理由
1. 编译期决定,release 包不携带 mock 代码
2. .vscode/launch.json 配两套(mock/real),开发切换方便
3. CI 可根据环境跑不同模式

### 替代方案
- **运行时切换** — 灵活但 release 包会带 mock 代码,体积大且有安全风险
- **环境变量** — Flutter 不直接读 env 变量,需要中间层
- **配置文件** — 改文件后要重启,不如 dart-define 干净

### 影响范围
- `lib/core/mock/mock_loader.dart` 实现
- `lib/core/network/interceptors/mock_interceptor.dart` 拦截器
- `.vscode/launch.json` 双配置
- `assets/mock/` 目录结构
- 所有 Repository 通过 ApiClient 自动分流(业务层不感知)

### 拍板人
@lead

### 状态
active

---

## ADR-004 | 2026-04-10 | 严格三端兼容(Android+iOS+Web)

### 决策
所有 core/ 代码必须三端兼容。CI 必须跑三端编译,任一失败 PR 不能 merge。
不能用 dart:io,文件操作必须用 cross_file XFile。
平台特定能力(camera/blue/nfc)必须 platform 判断。

### 理由
1. 业务方要求 web 也要支持
2. yc141 已证明可行(完整三端实现)
3. 早期严格,后期不需要返工

### 替代方案
- **只支持移动端** — 业务方拒绝
- **web 单独项目** — 维护成本翻倍

### 影响范围
- 所有 core/ 库必须用条件导出模式
- pubspec.yaml 不能引入 web 不兼容包
- CI pipeline 加 3 个 build job
- web/js/ 目录有加密 JS 文件(yc141 抄)

### 拍板人
@lead

### 状态
active

---

## ADR-005 | 2026-04-10 | JSON 用 freezed + json_serializable

### 决策
所有数据模型用 freezed 2.x + json_serializable 6.x 生成。
不可变,自动 copyWith / == / hashCode。

### 理由
1. 不可变模型避免 state 被意外修改
2. 自动生成减少模板代码错误
3. 嵌套对象支持好

### 替代方案
- **手写 fromJson/toJson** — 容易错,改字段要改两处
- **dart_mappable** — 较新,生态不如 freezed

### 影响范围
- 必须装 build_runner
- 模型字段改动后要跑 `dart run build_runner build`
- pubspec.yaml 加 freezed 系列依赖

### 拍板人
@lead

### 状态
active

---

## ADR-006 | 2026-04-10 | template/ 直接基于 yc141 改造,不从 0 写

### 决策
flutter-init/template/ 直接基于 yc141_app 改造:
- 加密层直接 copy(aes_dynamic_util / aes_util / hash_util 删 dart:io)
- 加密图片三平台实现直接 copy
- web/js/ 加密 JS 直接 copy
- HttpApi 改造成 ApiClient + 6 个 Interceptor
- AppAPI 改造成 AppConfig (GetxService + abstract)
- 加 MockInterceptor (yc141 没有的增量)
- 加 AppException sealed class

### 理由
1. 从 0 写要 1-2 周,改造只要 2-3 天
2. yc141 是生产级代码,踩过的坑都解决了
3. 我们的增量价值是工作流(workflow)+Mock,而非重写 core

### 替代方案
- **从 0 写** — 慢且容易出错
- **整个 fork yc141** — 包含太多业务代码,不通用

### 影响范围
- 组长 Phase 1 主要任务是改造,非创造
- B/C 不需要懂 yc141 内部
- 后续 yc141 升级我们要手动同步

### 拍板人
@lead

### 状态
active
