# 项目词汇表

> 项目专有名词。新成员先读这个,避免概念混淆。

---

## A

### Artifact (产物)
Skill 输出的结构化文件(spec.md / plan.md / api.md / review.md)。
带 frontmatter,有 lineage 追踪,可被下游 skill 消费。

### ADR (Architecture Decision Record)
架构决策记录。每次重要决策追加一条到 `decisions.md`,包含日期/决策/理由/替代方案/影响。
追加式,不删除。

### ApiClient
全局网络客户端,封装 dio + 6 个拦截器。所有业务网络请求必须通过它。
不允许业务代码直接 `new Dio()`。
位置: `lib/core/network/api_client.dart`

### AppConfig
全局配置服务,包装 dotenv 读取。提供 apiKey/apiHeaderKey 等访问。
GetxService 单例,可注入。
位置: `lib/core/config/app_config.dart`

### AppException
应用异常基类(sealed class)。所有业务代码只 catch 这个或其子类,不 catch String。
子类: NetworkException / BusinessException / AuthException / CryptoException / ParseException / CancelException 等。
位置: `lib/core/error/app_exception.dart`

---

## B

### .bnc
加密图片的 URL 后缀。CImage / AppImage 自动识别这个后缀走解密路径。
解密用 AES-ECB,key 来自 .env 的 IMG_KEY。

### Binding (GetX)
DI 注册器。每个页面的依赖在 binding 文件中 `Get.lazyPut`。
随路由生命周期,页面销毁时自动 dispose。

### BusinessException
业务错误异常。后端返回 `{status: "n", errorCode: N}` 时抛出。
对应 yc141 的 errorCode 体系。

---

## C

### Conductor (指挥家)
L6 Orchestration 层的核心角色。维护 workflow 状态机,按 DAG 调用 L4 worker skill。
对应 6 个 `flutter-flow-*` workflow SKILL.md。

### Checkpoint
Workflow 执行过程的快照,写在 `.flow_checkpoint/{workflow_id}/`。
失败可恢复,跨会话可继续。详见 `_design/checkpoint_design.md`。

### Context Pack
`docs/_context/` 下的 4 个文件: tech-stack / conventions / decisions / glossary。
所有 SKILL.md 必读,作为统一的项目知识。

---

## D

### Dynamic Key (动态密钥)
每次接口请求生成的临时 AES key,公式: `HMAC-SHA256(requestId, masterKey)`。
密文泄露不会影响其他请求。
对应 `lib/core/crypto/aes_dynamic.dart`。

---

## E

### Encrypt Interceptor
Dio 拦截器之一,负责请求 body 加密 + 响应解密。
业务层完全无感知。

---

## F

### feature (功能模块)
`lib/features/{module}/` 下的业务模块。每个模块是独立的 data + presentation 三层结构。

### Frontmatter
Markdown 文件头部的 YAML 元数据,用 `---` 分隔。
所有 SKILL.md 和 artifact 必须有 frontmatter。

---

## G

### GetX
项目使用的状态管理 + 路由 + DI 框架。版本 4.6.x。

### Generator (skill 类型之一)
生成新代码的 skill。如 model-gen / api-gen / page-gen。
对应 L4 的 6 类之一。

---

## L

### Lineage
Artifact 之间的引用链。spec → plan → api → code → review,每个 artifact 知道自己的 parent。

### L1-L8 (8 层架构)
- L1: Foundation Model (Claude API)
- L2: Tool / MCP
- L3: Knowledge (Context + Artifact + Memory)
- L4: Skill (Worker)
- L5: Workflow (DAG)
- L6: Orchestration (Conductor + Reflector)
- L7: Governance (Quality Gate + Hooks)
- L8: Observability (Telemetry)

---

## M

### Mock-first
开发优先用 mock 数据跑通,后端就绪后再切真实接口。
开关: `--dart-define=USE_MOCK=true`

### Mock Interceptor
Dio 拦截器之一,根据 USE_MOCK 环境变量从 `assets/mock/{key}.json` 加载数据,
拦截真实网络请求。yc141 没有,我们的增量。

### Master Key
.env 中配置的 API key 主密钥。三端三套(web/ios/android),
用于派生 dynamic key。

---

## N

### NetworkImage (自实现)
`lib/core/media/network_image/` 下的 ImageProvider 实现。
io 端用 dart:io HttpClient,web 端用 JS interop。
支持 `.bnc` 加密图片自动解密。

---

## O

### Orchestration Layer (L6)
统筹层,由 Router/Conductor/Reflector 三角色构成。
6 个 workflow SKILL.md 是这一层的具体实现。

---

## P

### PageReq / PageResp
分页请求/响应基类。所有列表接口必须用这个结构。
位置: `lib/core/network/models/`

---

## Q

### Quality Gate
质量门。Workflow 关键节点的检查点,失败则阻断流水线。
G1: spec→plan / G2: plan→design / G3: design→code / G4: code→review / G5: review→done

---

## R

### Reflector (反思器)
L6 的"质量检查员"。每个 worker skill 完成后,Reflector 二次评估 artifact 是否合格。
3 种策略: Schema-based / Rule-based / LLM-based。
返回: PASS / RETRY / ASK_USER / ABORT。
详见 `_design/reflector_design.md`。

### Router (路由器)
L6 角色之一。判断用户意图属于哪个 workflow。

### Repository
数据访问层。封装对 ApiClient 的调用,转换 model。
每个 module 一个,继承 GetxService。

---

## S

### Skill (技能)
L4 worker。单点能力,无状态,有 SKILL.md 描述。
不调用其他 skill,不知道有 orchestrator 存在。

### SKILL.md
Skill 的描述文件。包含 frontmatter + 10 段标准内容(L4)或 12 段(L5/L6 workflow)。
Claude 据此识别触发场景和执行流程。

### Spec
`docs/specs/{module}.md`。需求设计文档,由 flutter-spec 生成。
包含目标/页面/流转/接口/字段/异常 7 段。

### Sealed Class
Dart 3 的密封类。AppException 用这个,catch 时编译器强制 exhaustive。

---

## T

### Telemetry
L8 观测层。记录 skill 调用日志、token 用量、Quality Gate 结果。
写到 `.telemetry/*.jsonl`。

### Three Platforms (三端)
Android + iOS + Web。所有 core/ 代码必须三端兼容。

---

## V

### Validator (skill 类型之一)
检查不修改的 skill。如 review / health-check / test-gen。

---

## W

### Workflow (L5/L6)
编排器。`flutter-flow-*` 系列。自己不生成代码,只调用 L4 worker。
有状态机,有 reflector,有 checkpoint。

### Worker (L4 skill 别名)
强调 worker 的"无状态、单点、被调用"属性。
