# GetX 使用规范检查清单

> 用于 `flutter-review` 检查 GetX 用法是否正确。

---

## A. Controller

- [ ] 继承 `GetxController`,**不**继承 `ChangeNotifier`
- [ ] 不混用 `setState` (Stateful + GetxController = 反模式)
- [ ] 响应式变量用 `.obs` (`final list = <T>[].obs`)
- [ ] 复杂状态用 `Rxn<T>` (可空) / `Rx<T>` (必填)
- [ ] 不在 `build` 方法或 widget 内创建 controller
- [ ] `onInit()` 做初始化,不要在构造函数
- [ ] `onClose()` 释放资源 (Stream/Timer/CancelToken)
- [ ] 一个页面一个 Controller (复杂可拆多个,但要 binding 一起注册)

---

## B. View

- [ ] 用 `GetView<XxxController>`,**不**用 `StatelessWidget`
- [ ] 通过 `controller.xxx` 访问,不用 `Get.find` (GetView 自带)
- [ ] 响应式 UI 用 `Obx(() => ...)`
- [ ] 局部响应用 `GetX<XxxController>(builder: ...)` (少用)
- [ ] 不在 `Obx` 内创建大量 widget (会重建)
- [ ] `Obx` 内部必须访问 `.value` 或 .obs 变量,否则不会触发更新

---

## C. Binding

- [ ] 每个页面必须有 `binding` 文件 (`{page}_binding.dart`)
- [ ] DI 必须在 `binding` 中注册,**禁止**在 controller / view 散落 `Get.put`
- [ ] 优先 `Get.lazyPut` (惰性,只在需要时实例化)
- [ ] 全局服务用 `Get.put(..., permanent: true)` 或 `Get.putAsync`
- [ ] Repository / Service 用 `Get.lazyPut` 或全局 `Get.put`

```dart
class AnnounceListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AnnounceListController(
      repo: Get.find<AnnounceRepository>(),
    ));
  }
}
```

---

## D. 路由

- [ ] 路由名定义在 `app/routes/app_routes.dart` 常量
- [ ] 路由表注册在 `app/routes/app_pages.dart`
- [ ] 用 `Get.toNamed('/route')`,**不**用 `Navigator.push`
- [ ] 路由参数用 `Get.toNamed('/route', parameters: {'id': '123'})`
- [ ] Controller 中读参数: `Get.parameters['id']`
- [ ] 路由必须支持 web URL (参数能从 URL 恢复)
- [ ] 嵌套路由用 `GetPage` 的 `children` 或 nested navigator

---

## E. 全局 GetMaterialApp

- [ ] 用 `GetMaterialApp`,**不**用 `MaterialApp`
- [ ] 配置 `initialRoute` 和 `getPages`
- [ ] 配置 `translations` 和 `locale` (国际化)
- [ ] 配置 `theme` 和 `darkTheme`
- [ ] `defaultTransition` 选 `Transition.cupertino` 或 `Transition.fade`

---

## F. Snackbar / Dialog / BottomSheet

- [ ] 用 `Get.snackbar(...)` 不用 `ScaffoldMessenger`
- [ ] 用 `Get.dialog(...)` 不用 `showDialog`
- [ ] 用 `Get.bottomSheet(...)` 不用 `showModalBottomSheet`
- [ ] (除非有特殊需求,如自定义动画)

---

## G. DI 反模式

- [ ] **禁止** 在 `build` 方法内 `Get.find<X>()` (用 GetView 或 controller 字段)
- [ ] **禁止** 全局变量持有 controller (用 binding)
- [ ] **禁止** 跨页面直接 `Get.find<OtherPageController>()` (传数据用 arguments / 全局 service)
- [ ] **禁止** 在 main.dart 注册所有依赖 (只注册全局 service)

---

## H. Reactive 反模式

- [ ] **禁止** `.obs` 变量改名后忘记 `.value` 取值
- [ ] **禁止** 在 `Obx` 外修改 `.value` 期望 UI 刷新
- [ ] **禁止** 用 `update()` (旧 API,用 `.obs` 代替)
- [ ] `.obs` 列表修改用 `list.add(x)` / `list.assignAll(...)`,不用 `list = [...]`

---

## I. 内存泄漏防护

- [ ] Controller 的 Stream subscription 在 onClose cancel
- [ ] Timer 在 onClose dispose
- [ ] CancelToken 在 onClose cancel
- [ ] 全局 service 不持有页面级 controller 引用

---

## 严重度判定

| 违反 | 严重度 |
|---|---|
| 不用 GetxController 用 ChangeNotifier | ❌ 严重 |
| 在 build 内 Get.find | ⚠️ 警告 |
| DI 散落在 controller / view | ⚠️ 警告 |
| 用 MaterialApp 不用 GetMaterialApp | ❌ 严重 |
| Stream 未 cancel | ❌ 严重 (内存泄漏) |
| 用 Navigator.push | ⚠️ 警告 |
| Obx 未访问 .value | ❌ 严重 (UI 不更新) |
