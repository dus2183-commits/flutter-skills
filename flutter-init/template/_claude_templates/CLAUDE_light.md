# {{PROJECT_NAME_PASCAL}}

## AI 协作必读

任何 AI 操作前,请先读以下文件:
1. `docs/_context/tech-stack.md` — 技术栈
2. `docs/_context/conventions.md` — 编码规范

## 技术栈
- 状态管理/路由/DI: **GetX**
- 网络: **dio**
- 三端: **Android + iOS + Web**

## 约定

### 建议(非强制)
- 页面用 GetView<Controller> 或 StatelessWidget 都行
- Model 可以用 freezed 也可以手写
- 网络请求可以用 ApiClient 也可以直接 dio
- Mock 数据按需使用

### 目录结构
```
lib/
├── main.dart
├── app/                       路由/主题
├── core/                      基础库
├── features/                  业务模块
│   └── {module}/
│       ├── data/              数据层(model + repository)
│       └── presentation/      UI 层(page + controller)
└── shared/                    公共组件
```

### 禁止
- ❌ 直接 `import 'dart:io'`（跨平台兼容）
- ❌ throw String

## 启动
```bash
fvm flutter run
```
