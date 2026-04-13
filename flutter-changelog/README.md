# flutter-changelog 使用说明

> 从 git log 生成 CHANGELOG.md，按 Conventional Commits 解析，输出 Keep a Changelog 格式。

## 什么时候用

当你需要生成或更新变更日志时，对 Claude 说：

- "生成 changelog"
- "更新变更日志"
- "generate changelog"

## 输入

| 参数 | 必填 | 默认值 | 说明 |
|---|---|---|---|
| version | 是 | — | 新版本号（SemVer） |
| tag_from | 否 | 上一个 tag | 起始 tag |
| output_path | 否 | CHANGELOG.md | 输出路径 |

## 映射规则

| commit 前缀 | CHANGELOG 分类 |
|---|---|
| `feat:` | Added |
| `fix:` | Fixed |
| `docs:` | Documentation |
| `refactor:` / `perf:` | Changed |
| `BREAKING CHANGE` / `!` | Breaking Changes |
| `chore:` / `ci:` / `test:` / `style:` / `build:` | 跳过 |
| 不符合规范的 commit | Other |

## 使用示例

```
你: 生成 changelog，版本 1.2.0

Claude: [读 context → git log v1.1.0..HEAD → 解析分类 → dry-run → 写入]
  → 更新 CHANGELOG.md
```

## 注意事项

- 需要在 git 仓库中执行
- 需要有至少一个 git tag（如果没有，会询问是否用首次 commit 作为起点）
- 不会自动 git commit / tag / push
- 不会修改 pubspec.yaml
- Merge commit 会被跳过
