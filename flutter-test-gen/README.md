# flutter-test-gen 使用说明

> 给一段 Dart 代码，生成 mocktail 单元测试。

## 什么时候用

当你需要为 Dart 代码生成单元测试时，对 Claude 说：

- "给这个类生成单测"
- "生成 XX 的 mocktail 测试"
- "给这段代码写 test"
- "生成 Repository 的测试"

## 支持的输入方式

| 方式 | 示例 |
|---|---|
| 文件路径 | 给 `.dart` 文件路径 |
| 代码片段 | 直接贴 Dart 代码 |

## 输出

`test/`（默认路径，可自定义）：

- `{class_name_snake_case}_test.dart` — mocktail 单元测试文件

## 测试覆盖

每个 public 方法生成 3 类测试用例：

| 类型 | 说明 |
|---|---|
| 成功路径 | mock 返回正常数据，验证返回值 |
| 异常路径 | mock 抛 AppException，验证异常传播 |
| 边界值 | 空列表、null、零值等边界场景 |

## 使用示例

### 示例 1：给文件路径

```
你: 给 lib/features/message/data/repositories/message_repository.dart 生成单测

Claude: [读文件 → 分析结构 → 识别依赖 ApiClient → 生成 Mock + 测试 → dry-run → 生成]
  → 输出 test/message_repository_test.dart
```

### 示例 2：贴代码

```
你: 给这段代码写单测

class UserService extends GetxService {
  final ApiClient _api = Get.find();
  Future<User> getProfile({...}) async { ... }
}

Claude: [解析代码 → 识别依赖 → 生成 Mock + 测试 → dry-run → 生成]
  → 输出 test/user_service_test.dart
```

### 示例 3：自定义路径

```
你: 生成 message_repository 的测试，保存到 test/unit/

Claude: [正常流程 → 生成到指定路径]
  → 输出 test/unit/message_repository_test.dart
```

## 下一步

测试文件生成后：

1. 运行 `flutter test test/{file}` 验证测试通过

## 注意事项

- 使用 mocktail（不是 mockito）
- 测试数据优先从 Mock JSON 文件读取
- 遵循 given-when-then 注释结构
- 不会自动运行测试
- 不会修改被测代码
- 不会覆盖已有测试文件（除非你明确要求）
