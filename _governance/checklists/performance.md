# 性能检查清单

> 用于 `flutter-review` 检查性能问题。

---

## A. Widget 性能

- [ ] 不变 widget 用 `const` 修饰 (减少 rebuild)
- [ ] StatelessWidget 优先,Stateful 只在需要时
- [ ] build 方法不做计算 (移到 controller 或 init)
- [ ] build 方法不创建大对象 (放静态变量)
- [ ] 避免 build 方法内 `Get.find` (用 GetView 或 controller 字段)
- [ ] `Obx` 范围尽量小 (只包裹响应部分,不包整页)
- [ ] 列表 item 用 `key` (避免 rebuild 错乱)

---

## B. 列表性能

- [ ] **必须** `ListView.builder`,**禁止** `ListView(children: [...])` 渲染长列表
- [ ] 列表分页 (每页 ≤ 50 条)
- [ ] 上拉加载触发距离合理 (不要一拉就刷)
- [ ] 复杂 item 用 `RepaintBoundary` 包裹
- [ ] item 高度尽量固定 (`itemExtent`)
- [ ] 滚动控制器及时 dispose

---

## C. 图片性能

- [ ] 用 `AppNetworkImage` (自带 cache + placeholder + error)
- [ ] 不用原生 `Image.network` (没有 cache)
- [ ] 大图压缩 (`flutter_luban` 或后端 thumbnail)
- [ ] 图片大小 ≤ 200KB (单图)
- [ ] 列表用缩略图,详情才加载原图
- [ ] 内存中 imageCache 配置 (`PaintingBinding.instance.imageCache.maximumSize`)

---

## D. 网络性能

- [ ] 列表分页
- [ ] 详情可缓存 (Repository 内 cache layer)
- [ ] 重复请求合并 (in-flight dedup)
- [ ] 弱网降级 (timeout 短 + retry 1 次)
- [ ] 切换路由时 cancel 进行中的请求 (CancelToken)
- [ ] 启动时不要并发太多请求 (≤ 3 个)

---

## E. 状态管理性能

- [ ] `.obs` 变量数量合理 (每个 controller ≤ 10 个 .obs)
- [ ] 复杂对象用 `Rx<T>` 整体替换,不频繁修改字段
- [ ] 列表用 `RxList<T>`,修改用 `assignAll` / `add` 不用 `=`
- [ ] 不在 Obx 内 print / 调用副作用方法

---

## F. Stream / Timer / Future

- [ ] Stream subscription 在 onClose cancel
- [ ] Timer 在 onClose dispose
- [ ] Future 取消 (CancelableOperation 或 cancelToken)
- [ ] 没有内存泄漏 (用 leak_tracker 检查)
- [ ] AnimationController 在 dispose 释放

---

## G. 启动性能

- [ ] main.dart 不做大量同步初始化
- [ ] 全局 service 用 `Get.putAsync` 异步加载
- [ ] 启动 splash 屏在 native 层 (不在 Flutter 渲染)
- [ ] 首屏 widget 数 ≤ 50
- [ ] 字体懒加载 (不全量预加载)

---

## H. 包大小

- [ ] 不引入未使用的依赖
- [ ] 大依赖按需引入 (`hide` / `show`)
- [ ] 图片资源压缩 (TinyPNG)
- [ ] SVG 优先于 PNG
- [ ] release 包跑 `flutter build apk --analyze-size` 检查
- [ ] android: minify + R8
- [ ] ios: bitcode 关闭(已废弃)
- [ ] web: tree-shake-icons

---

## I. 滚动 / 动画

- [ ] 60fps 滚动 (devtools timeline 检查)
- [ ] 复杂动画用 `Hero` 或 `AnimatedSwitcher` 不手写
- [ ] CustomPaint 慎用 (cache shouldRepaint=false)
- [ ] 长列表禁用 implicit animations

---

## J. 内存

- [ ] devtools observatory 检查内存峰值
- [ ] 内存峰值 < 200MB (普通页) / < 500MB (视频/图册)
- [ ] 不持有大对象的全局引用
- [ ] 缓存策略合理 (image / network / db)

---

## 严重度判定

| 违反 | 严重度 |
|---|---|
| ListView(children:) 渲染长列表 | ❌ 严重 |
| 内存泄漏 (stream/timer 未释放) | ❌ 严重 |
| 用原生 Image.network 不带 cache | ⚠️ 警告 |
| 缺 const 修饰 | ⚠️ 警告 |
| build 方法做大量计算 | ⚠️ 警告 |
| 没有列表分页 | ❌ 严重 (大数据时崩) |
| Obx 包整页 | ⚠️ 警告 |
| 启动时并发 > 5 个请求 | ⚠️ 警告 |
