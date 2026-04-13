# flutter-model-gen 使用说明

> 把 JSON 或接口契约转成 freezed Dart 实体类。

## 什么时候用

当你需要生成 freezed 实体类时，对 Claude 说：

- "把这个 JSON 转成 Dart"
- "生成 XX 模块的 model"
- "根据接口文档生成实体"
- "把契约文档转成 freezed 类"
- "这个 URL 的数据转成 model"
- "这个 curl 命令转成 model"

## 支持的输入方式

| 方式 | 示例 |
|---|---|
| JSON 字符串 | 直接贴 JSON 响应样本 |
| 多 JSON 合成 | 贴多个 JSON 片段 + 模块名，自动去重合成 |
| .md 契约文档 | 给 `docs/api/{module}.md` 路径，自动提取响应结构 |
| curl 命令 | 贴 curl 命令，自动执行拿到响应后解析 |
| URL | 给在线文档链接，自动抓取解析 |

## 输出

`lib/features/{module}/data/models/`（默认路径，可自定义）：

- `{entity}.model.dart` — freezed 实体类
- `{nested_entity}.model.dart` — 嵌套实体（如有）
- `.freezed.dart` 和 `.g.dart` 由 build_runner 生成

## 使用示例

### 示例 1：贴 JSON

```
你: 把这个 JSON 转成 Dart，模块名 announce

{
  "id": "65f7a8b9c1d2e3f4",
  "title": "系统升级公告",
  "content": "<p>...</p>",
  "publishAt": "2026-04-10T10:00:00Z",
  "isRead": false
}

Claude: [解析 JSON → 推断类型 → dry-run → 生成]
  → 输出 lib/features/announce/data/models/announce.model.dart
  → 提示运行 build_runner
```

### 示例 2：从契约文档

```
你: 根据 docs/api/announce.md 生成实体类

Claude: [读契约 → 提取响应结构 → 推断类型 → dry-run → 生成]
  → 输出 announce.model.dart
```

### 示例 3：curl 命令

```
你: 这个 curl 命令转成 model，模块名 system

curl -X POST -H "content-type:application/json" \
  -d '{"token":"xxx"}' \
  "https://api.example.com/api/system/info"

Claude: [执行 curl → 拿到响应 JSON → 解析 → 推断类型 → dry-run → 生成]
  → 输出 lib/features/system/data/models/system_info.model.dart
```

### 示例 4：自定义路径

```
你: 生成 announce 的 model，保存到 lib/models/

Claude: [正常流程 → 生成到指定路径]
  → 输出 lib/models/announce.model.dart
```

### 示例 5：有嵌套对象

```
你: 把这个 JSON 转成 Dart，模块名 post

{
  "id": "xxx",
  "title": "标题",
  "author": {"id": "a1", "name": "张三", "avatar": "https://..."}
}

Claude: [解析 → 识别嵌套对象 author → 拆文件 → dry-run → 生成]
  → 输出 post.model.dart + post_author.model.dart
```

### 示例 6：多 JSON 合成

```
你: 这两个接口返回的都是用户信息，合成一个 model，模块名 user

JSON 1: {"id": "u1", "name": "张三", "email": "z@test.com"}
JSON 2: {"id": "u2", "name": "李四", "phone": "138xxxx", "avatar": "https://..."}

Claude: [解析两个 JSON → 字段去重合并 → dry-run → 生成]
  → 输出 lib/features/user/data/models/user.model.dart
  → 字段: id(required), name(required), email(?), phone(?), avatar(?)
```

## 下一步

实体类生成后：

1. 运行 `fvm dart run build_runner build --delete-conflicting-outputs`
2. 用 `flutter-api-gen` 生成 Repository

## 注意事项

- 不会自动跑 build_runner，需要你手动执行
- 不会修改 pubspec.yaml
- 嵌套对象自动拆为独立文件
- 类型不确定时会问你确认
- 不会覆盖已有文件（除非你明确要求）
