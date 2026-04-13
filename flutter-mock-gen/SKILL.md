---
name: flutter-mock-gen
description: 根据 model 或契约文档自动生成丰富的 mock JSON 数据(faker 风格)。用户说"生成 mock 数据"、"补充测试数据"时触发。列表至少 3 条,字段值合理不重复。
type: skill
stage: 5
model: haiku
priority: P1
version: 1.0.0
owner: @lead
category: generator
---

# Mock 数据生成 (flutter-mock-gen)

## 1. 触发场景

- "给这个模块生成 mock 数据"
- "mock 数据太少了,补充一下"
- "生成 20 条测试数据"
- "根据 model 生成 mock JSON"
- api-gen 生成的 mock 数据不够丰富时

**反例:**
- "生成 Repository" → flutter-api-gen (它会顺带生成基础 mock)
- "修改 mock 开关" → 手动改 dart-define

## 2. 前置必读

- `lib/features/{module}/data/models/*.model.dart` (字段定义)
- `docs/api/{module}.md` (接口契约,字段说明)
- `mock/{module}/` (已有 mock 文件)

## 3. 输入

**必填:**
- `module_name` — 模块名
- `source` — model 文件路径 / 契约文档路径

**可选:**
- `count` (int, default 3) — 列表数据条数
- `locale` — 数据语言 (默认中文)

## 4. 工作流程

**Step 1 — 读 model 或契约,提取字段**

**Step 2 — 按字段类型生成合理数据**

| 字段类型/名称 | 生成策略 |
|---|---|
| id / String 型 ID | 64 位 hex 随机 (`65f7a8b9c1d2e3f4`) |
| title / name | 中文短句,每条不同 |
| content | 1-3 段中文文本,可含 HTML 标签 |
| DateTime (ISO) | 最近 30 天内的随机时间,按时间倒序 |
| bool (isRead 等) | 交替 true/false |
| int (count/total) | 合理范围内随机数 |
| double (price) | 两位小数 |
| url / imageUrl | `https://picsum.photos/200/200?random={n}` |
| email | `user{n}@example.com` |
| phone | `138xxxx{4位随机}` |
| enum-like | 从已知可选值中轮换 |
| 嵌套对象 | 递归生成 |

**Step 3 — 组装 JSON (保持 status/data 包装)**

**Step 4 — 写入 mock/{module}/{action}.json**

**Step 5 — 更新 pubspec.yaml (如目录不存在)**

**Step 6 — 自检**

## 5. 输出产物

```
mock/{module}/
├── list.json      — 列表 (≥3 条,默认可配)
├── detail.json    — 详情
├── ...
```

## 6. 代码模板

```json
{
  "status": "y",
  "data": {
    "list": [
      {
        "id": "65f7a8b9c1d2e3f4",
        "title": "系统升级通知",
        "content": "<p>本周日凌晨 2:00-4:00 进行系统升级...</p>",
        "publishAt": "2026-04-12T10:00:00Z",
        "isRead": false,
        "author": "运营团队"
      },
      {
        "id": "65f7a8b9c1d2e3f5",
        "title": "新功能上线公告",
        "content": "<p>消息中心功能正式上线...</p>",
        "publishAt": "2026-04-10T15:30:00Z",
        "isRead": true,
        "author": "产品组"
      },
      {
        "id": "65f7a8b9c1d2e3f6",
        "title": "五一假期安排",
        "content": "<p>放假时间: 5月1日-5月5日...</p>",
        "publishAt": "2026-04-08T09:00:00Z",
        "isRead": false,
        "author": "行政部"
      }
    ],
    "total": 25,
    "page": 1,
    "pageSize": 20
  }
}
```

**关键规则:**
- 必须有顶层 `status` + `data` 包装 (ErrorInterceptor 依赖)
- 列表数据每条的字段值**必须不同**(不要复制粘贴只改 id)
- `total` 要大于 list.length (模拟有更多数据)
- 时间按倒序排列
- 嵌套对象的字段也要有合理值

## 7. 不做什么 (Boundary)

- ❌ 不修改 model 文件
- ❌ 不修改 Repository
- ❌ 不生成 Dart 代码
- ❌ 不启动 mock server (我们用的是 assets mock)
- ❌ 不自动 commit

## 8. 自检 Checklist

- [ ] JSON 格式合法 (jsonDecode 不报错)
- [ ] 有 `status` + `data` 包装
- [ ] 列表数据 ≥ `count` 条
- [ ] 每条数据字段值不同
- [ ] 字段类型与 model 一致
- [ ] 时间倒序排列
- [ ] pubspec.yaml 有 mock/{module}/ 注册

## 9. 失败处理

**ASK_USER:** 字段含义不明时 (不确定是人名还是地名)
**STOP:** model 文件不存在
**ROLLBACK:** 删除本次生成的 JSON

## 10. 联动

**上游:** flutter-api-gen (基础 mock) / flutter-model-gen (model 定义)
**下游:** flutter-test-gen (用 mock 数据做测试)
