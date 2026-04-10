# Mock 数据目录

> Mock JSON 文件按模块组织,用于 `--dart-define=USE_MOCK=true` 开发模式。

## 目录约定

```
mock/
├── README.md
├── {module}/
│   ├── list.json
│   ├── detail.json
│   └── ...
└── ...
```

## 命名规则

- 模块名: snake_case (与 lib/features/{module}/ 对应)
- 接口名: snake_case (与接口路径对应)
- 文件名 = mockKey + `.json`

## 示例

```
mock/
├── announce/
│   ├── list.json          ← mockKey: "announce/list"
│   ├── detail.json        ← mockKey: "announce/detail"
│   └── markRead.json      ← mockKey: "announce/markRead"
└── user/
    ├── login.json
    └── profile.json
```

## JSON 格式

mock JSON **应符合后端真实响应格式**(包括 status/data 包装):

```json
{
  "status": "y",
  "data": {
    "list": [
      { "id": "1", "title": "测试公告" }
    ],
    "total": 100,
    "page": 1,
    "pageSize": 20
  }
}
```

## 启用 Mock

```bash
flutter run --dart-define=USE_MOCK=true
```

或在 `.vscode/launch.json` 选 "Mock (开发)" 配置。

## 注意

- ⚠️ 必须在 `pubspec.yaml` 中声明 `assets: - mock/`
- ⚠️ 修改 mock JSON 后需要 hot restart (不是 hot reload)
- ⚠️ Mock 数据应与 model 字段一致(否则解析失败)
