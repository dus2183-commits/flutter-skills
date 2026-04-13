# flutter-api-gen 使用说明

> 读取接口契约文档，生成 Repository 调用代码 + Binding + Mock JSON。

## 什么时候用

当你需要根据接口契约生成 Repository 和 Mock 数据时，对 Claude 说：

- "生成 XX 模块的 Repository"
- "根据接口契约生成调用代码"
- "把契约文档转成 Repository"
- "这个 URL 的接口转成调用代码"
- "这个 curl 命令生成 Repository"

## 支持的输入方式

| 方式 | 示例 |
|---|---|
| .md 契约文档路径 | 给 `docs/api/{module}.md` 路径 |
| JSON 字符串 | 直接贴 JSON 响应样本 |
| curl 命令 | 贴 curl 命令，自动执行拿到响应后解析 |
| URL | 给在线文档链接，自动抓取解析 |

## 输出

`lib/features/{module}/data/repositories/`（默认路径，可自定义）：

- `{module}_repository.dart` — Repository 类（方法签名严格按 ApiClient 契约）
- `{module}_repository.binding.dart` — GetX Binding

`mock/{module}/`（默认路径，可自定义）：

- `{action}.json` — 每个接口一个 Mock 文件

## 使用示例

### 示例 1：从契约文档

```
你: 根据 docs/api/announce.md 生成 Repository

Claude: [读契约 → 提取接口清单 → 推断 ApiClient 方法 → 检查 model → dry-run → 生成]
  → 输出 announce_repository.dart + announce_repository.binding.dart + mock/announce/*.json
```

### 示例 2：贴 JSON

```
你: 把这个 JSON 转成 Repository，模块名 announce

{
  "status": "y",
  "data": {
    "list": [{"id": "xxx", "title": "公告标题", "isRead": false}],
    "total": 100, "page": 1, "pageSize": 20
  }
}

Claude: [解析 JSON → 推断为列表接口 → 用 getList → dry-run → 生成]
  → 输出 announce_repository.dart + binding + mock/announce/list.json
```

### 示例 3：curl 命令

```
你: 这个 curl 命令生成 Repository，模块名 order

curl -X POST 'https://api.example.com/api/order/list' \
  -H 'Authorization: Bearer xxx' \
  -d '{"page": 1, "pageSize": 20}'

Claude: [执行 curl → 拿到响应 → 推断接口 → dry-run → 生成]
  → 输出 order_repository.dart + mock/order/list.json
```

### 示例 4：自定义路径

```
你: 生成 announce 的 Repository，保存到 lib/repositories/

Claude: [正常流程 → 生成到指定路径]
  → 输出 lib/repositories/announce_repository.dart
```

### 示例 5：给 URL

```
你: 帮我根据这个 URL 生成 Repository https://apifox.com/xxx，模块名 announce

Claude: [抓取 URL → 解析文档 → 提取接口 → dry-run → 生成]
  → 输出 announce_repository.dart + mock/announce/*.json
```

## 下一步

Repository + Mock 生成后：

1. 用 `flutter-page-gen` 生成页面

## 前置条件

- 必须先用 `flutter-model-gen` 生成实体类（Repository 需要 import model）
- 如果 model 文件不存在，会提示你先运行 flutter-model-gen

## 注意事项

- 会自动更新 pubspec.yaml 注册 mock 子目录（Flutter assets 不递归）
- 不会生成 model 实体类（交给 flutter-model-gen）
- 不会生成 Controller / Page（交给 flutter-page-gen）
- 不会修改已有 Repository 文件（除非你明确要求）
- 方法签名严格按 `api_client_signature.dart` 契约
- Repository 不 catch 异常，让 controller 上层统一处理
- ApiClient 方法自动推断，不确定时会问你确认
