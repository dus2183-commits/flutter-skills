# 安全检查清单

> 用于 `flutter-review` 检查安全相关问题。
> 任一 ❌ 都不能上线。

---

## A. 密钥与配置

- [ ] 没有任何硬编码 API key / secret / password (`grep -r "key.*=.*['\"]"`)
- [ ] `.env.prod` 是空模板,不入 git
- [ ] `.env.dev` 入 git 但只含开发 key
- [ ] 真实 prod key 通过 CI/CD 注入,不提交
- [ ] AppConfig 读取 dotenv,不直接读环境变量
- [ ] 三端三套 master key (web/ios/android),互不影响

---

## B. 接口加密

- [ ] 所有业务接口走 EncryptInterceptor (除标注 @raw 的)
- [ ] AES key 是动态派生 (HMAC-SHA256(requestId, masterKey)),不固定
- [ ] IV 是随机生成,不复用
- [ ] 请求 body 先 GZIP 后 AES (顺序不能反)
- [ ] 响应 bytes 先 AES 解密后 GZIP 解压
- [ ] 加密失败抛 `EncryptException`,不暴露原始错误

---

## C. 鉴权

- [ ] Token 存 `flutter_secure_storage` (不存 SharedPreferences)
- [ ] Token 过期(2002 错误码)自动刷新,**最多重试 1 次**(防死循环)
- [ ] 401 / 鉴权失败自动跳登录页
- [ ] 退出登录清空所有 Storage 中的 token
- [ ] Header 签名包含 timestamp,防重放

---

## D. 数据传输

- [ ] 所有接口 HTTPS,不允许 HTTP (除 localhost 调试)
- [ ] dio 配置 `validateStatus` 不依赖 HTTP 状态码 (业务码在响应 body)
- [ ] 上传文件先校验类型和大小
- [ ] 不在 URL 中传敏感参数 (用 body)

---

## E. 本地存储

- [ ] 敏感数据 (token / pin / cookie) 用 `flutter_secure_storage`
- [ ] 普通数据用 `get_storage`
- [ ] **web 端不存任何敏感数据**(secure_storage 在 web 落 localStorage,不安全)
- [ ] 不在 SharedPreferences 存 token
- [ ] 缓存数据 (image bytes) 不需加密

---

## F. SQL / 注入防护

- [ ] 用 drift / sqflite,**不**手动拼 SQL
- [ ] 参数化查询 (`Variable<String>`),不字符串拼接
- [ ] 用户输入不直接进 SQL

---

## G. XSS 防护 (web)

- [ ] 不用 `Html.unsafeHtml` 渲染未知来源 HTML
- [ ] flutter_html 配置 sanitize
- [ ] 用户输入不直接用 `dangerouslySetInnerHTML`
- [ ] WebView 不加载未信任的 URL

---

## H. 业务逻辑安全

- [ ] 重要操作 (支付/删除/转账) 二次确认
- [ ] 验证码 60 秒倒计时 (防爆破)
- [ ] 频控 (登录失败 5 次锁定)
- [ ] 客户端不做关键校验 (服务端校验为准)

---

## I. 隐私

- [ ] 隐私政策弹窗 (首次启动)
- [ ] 用户可拒绝权限 (相机/位置/通讯录)
- [ ] 拒绝后仍可基本使用 (降级)
- [ ] 不收集非必要数据
- [ ] 埋点不收集 PII (手机号/姓名)

---

## J. Logging

- [ ] log 不打印明文密码
- [ ] log 不打印 token
- [ ] log 不打印请求 body 中敏感字段 (password / pin)
- [ ] release 模式 log 级别提升到 ERROR
- [ ] 不上传 log 到第三方 (除非明确告知用户)

---

## 严重度判定

| 违反 | 严重度 |
|---|---|
| 硬编码 API key | ❌ 严重 |
| .env.prod 入 git | ❌ 严重 (要 rotate key) |
| Token 存 SharedPreferences | ❌ 严重 |
| HTTP 而非 HTTPS | ❌ 严重 |
| 2002 死循环重试 | ❌ 严重 |
| log 打印 password | ❌ 严重 |
| SQL 字符串拼接 | ❌ 严重 |
| flutter_secure_storage 在 web 存敏感 | ❌ 严重 |
| Header 没有 timestamp 签名 | ⚠️ 警告 |
| 缺少二次确认 | ⚠️ 警告 |
