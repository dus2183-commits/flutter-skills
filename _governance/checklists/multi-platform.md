# 多平台兼容检查清单

> 用于 `flutter-review` 检查代码三端兼容。
> 任一不通过 = ⚠️ 警告;严重违反(如直接 dart:io)= ❌ 严重。

---

## A. dart:io 禁用

- [ ] 没有任何文件直接 `import 'dart:io'` (除非在条件导入文件 `*_io.dart` 中)
- [ ] 没有 `new File()` 调用 (用 `cross_file.XFile`)
- [ ] 没有 `new Directory()` 调用 (用 `path_provider`)
- [ ] 没有 `Platform.isAndroid/isIOS` 直接判断 (用 `kIsWeb` + `defaultTargetPlatform`)
- [ ] 没有 `dart:io` 的 `HttpClient` (用 dio + ApiClient)
- [ ] 没有 `dart:io` 的 `WebSocket` (用 web_socket_channel)
- [ ] 没有 `Socket` / `ServerSocket` 在 core/ 中

---

## B. 条件导出模式

- [ ] 平台特定能力放 `core/{cap}/_io.dart` 和 `core/{cap}/_web.dart`
- [ ] 入口文件用 `export '_io.dart' if (dart.library.html) '_web.dart';`
- [ ] 业务层只 import 入口文件,不直接 import 平台实现
- [ ] _io.dart 和 _web.dart 暴露相同 public API (类型、方法签名一致)

---

## C. 路由参数

- [ ] 路由参数都是基本类型 (String/int/bool)
- [ ] 不传整个对象 (用 query string 或 storage 中转)
- [ ] 路由参数支持 web URL 直接打开 (深链接)
- [ ] 刷新 web 页面不会崩 (路由参数能从 URL 恢复)

---

## D. 媒体限制

- [ ] 视频不依赖 HLS,或 web 端做了 fallback
- [ ] `video_player_web_hls` 已配置(若用 HLS)
- [ ] 图片 URL 是 https (web 端 http 会被混合内容拦截)
- [ ] 加密图片(.bnc)在 web 端实测过
- [ ] 视频在 web 端实测过

---

## E. 平台特定能力

- [ ] camera 用 `image_picker` 降级 (web 不支持 camera)
- [ ] 蓝牙(flutter_blue)只在 mobile 启用
- [ ] NFC 只在 mobile 启用
- [ ] 推送 (firebase_messaging) web 端配置 service worker
- [ ] 文件下载用 path_provider + cross_file
- [ ] 分享 (share_plus) 三端各自实现

---

## F. CORS 与网络

- [ ] web 端 API base URL 同源 (避免 CORS)
- [ ] 或后端 CORS 配置正确
- [ ] dio 在 web 端不设代理 (web 不支持)
- [ ] 上传文件用 FormData + XFile.openRead() 流式读取

---

## G. 字体与排版

- [ ] 用 MediaQuery 处理 textScaleFactor (web 浏览器缩放)
- [ ] 字体大小相对单位 (sp/dp 通过 ScreenUtil)
- [ ] 中文字体回退链 (web 上系统字体不一致)

---

## H. 滚动手势

- [ ] 长列表在 web 用鼠标滚轮可滚 (实测)
- [ ] PageView 在 web 端手势 vs 触屏行为一致
- [ ] 下拉刷新 (easy_refresh) 在 web 测试

---

## I. 安全性

- [ ] flutter_secure_storage 在 web 不存敏感数据
- [ ] web 端的 sessionStorage / localStorage 不存 token (易被 XSS)
- [ ] 后端给短期 token,web 端不持久化

---

## J. 编译验证

- [ ] `flutter build apk --debug` 通过
- [ ] `flutter build ios --no-codesign --debug` 通过
- [ ] `flutter build web` 通过
- [ ] CI 配置三端 build job
- [ ] PR merge 前必须三端 pass

---

## 严重度判定

| 违反 | 严重度 |
|---|---|
| 直接 import 'dart:io' | ❌ 严重 |
| 编译失败 (任一平台) | ❌ 严重 |
| 路由传不可序列化对象 | ❌ 严重 |
| build 超 80 行无 hashCode 等逻辑 | ⚠️ 警告 |
| 未做 platform 判断的相机/蓝牙 | ⚠️ 警告 |
| 未配置 CORS 但 web 端调跨域 API | ❌ 严重 |
| 未实测 HLS 视频 web 行为 | ⚠️ 警告 |
