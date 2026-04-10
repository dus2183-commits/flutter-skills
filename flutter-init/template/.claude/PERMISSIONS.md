# Claude Code 权限说明

> 这份文档解释 `.claude/settings.json` 里每组权限的用意。
> JSON 不支持注释,所以分组说明放这里。

---

## 设计原则

1. **项目级权限,不动全局** — 全局 `~/.claude/settings.json` 默认安全模式
2. **白名单为主** — 只列必要的,其他默认拒
3. **黑名单兜底** — 几个高危操作单独 deny(防 allow 误漏)
4. **Sub-agent 继承** — workflow 内部 dispatch 的 sub-agent 也用这套权限,可以并行 Write

---

## Allow 分组 (82 条)

### 🟢 读取(全开,无风险)
```
Read(**) / Glob(**) / Grep(**)
```
读任何文件都允许,因为读不会破坏。

---

### 🟢 写代码 / 文档(项目内 5 个目录)
```
Write(lib/**)        ← 业务代码
Write(test/**)       ← 测试代码
Write(mock/**)       ← Mock JSON
Write(assets/**)     ← 图片/字体等
Write(scripts/**)    ← shell 脚本
+ Edit 同上
```

---

### 🟢 写 Artifact(spec / plan / api / review)
```
Write(docs/specs/**)
Write(docs/plans/**)
Write(docs/api/**)
Write(docs/review/**)
Write(docs/_health/**)
Write(docs/_failures/**)
+ Edit(docs/**)
```
所有 skill 生成的文档都在这里。

---

### 🟢 Workflow 运行时文件
```
Write(.flow_checkpoint/**)   ← Workflow 状态机 checkpoint
Write(.flow_log/**)          ← Workflow 执行日志
Write(.telemetry/**)         ← Skill 调用统计
```

---

### 🟢 配置文件(明确列出,避免 typo)
```
Edit(pubspec.yaml)
Edit(analysis_options.yaml)
Edit(.fvmrc)
Edit(.env.dev)
Edit(.gitignore)
Edit(README.md)
Edit(CLAUDE.md)
Edit(.vscode/launch.json)
Edit(.vscode/settings.json)
```

---

### 🟢 Bash 基础命令
ls / find / grep / cat / head / tail / wc / mkdir / cp / chmod / sed / awk 等

---

### 🟢 Flutter / Dart / fvm
```
Bash(flutter:*)   ← 任何 flutter 命令
Bash(dart:*)
Bash(fvm:*)       ← fvm flutter / fvm dart
```

---

### 🟢 跑项目脚本
```
Bash(bash scripts/*)   ← 跑 setup.sh / build_check.sh 等
Bash(./scripts/*)
Bash(bash:*)
Bash(sh:*)
```

---

### 🟢 Git 只读 + 安全操作
```
git status / diff / log / branch / show     ← 只读
git stash / restore / checkout / add / init  ← 本地操作
```
**注意:** push / commit / reset --hard / rebase / merge **被 deny**。

---

## Deny 分组 (30 条)

### 🔴 敏感文件不能写
```
.env.prod          ← 生产环境变量
.env.local
android/key.properties
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

### 🔴 Native 项目目录(flutter create 生成,Claude 不要乱改)
```
Write(android/**)
Write(ios/**)
Write(macos/**)
Write(windows/**)
Write(linux/**)
```
**例外:** 如果真要改 native 配置,用户手动改,不让 AI 动。

### 🔴 Git 内部
```
.git/** 都不能写
```

### 🔴 fvm SDK 软链
```
.fvm/flutter_sdk/**
```
那是 fvm 自己管的,Claude 不要碰。

### 🔴 危险命令
```
rm -rf
sudo
curl / wget       ← 防止下载未信任的东西
npm publish / pub publish  ← 防止误发布
```

### 🔴 Git 写操作(必须用户手动)
```
git push / push --force
git commit
git reset --hard
git rebase
git merge
```
**为什么:** Git 写操作影响共享历史,必须用户拍板。

---

## 怎么验证权限生效

```bash
# 在新建的项目内,启动 Claude Code
cd ~/Desktop/skills/my_app
claude

# 在对话中:
> 帮我列出 lib/features/ 目录(应该能跑,Read 允许)
> 帮我创建 lib/test_file.dart(应该能写,Write(lib/**) 允许)
> 帮我改 android/build.gradle(应该被拒,deny)
> 帮我 git push(应该被拒,deny)
```

---

## 全局 vs 项目级 权限优先级

- **全局**(`~/.claude/settings.json`): 默认应用所有项目
- **项目级**(`{project}/.claude/settings.json`): 覆盖全局
- 我们项目级**更宽松**(开了 Write),因为只在这个项目内信任 AI

---

## 改 permissions 后必须重启 Claude Code

修改 `.claude/settings.json` 后:
1. 关掉所有 Claude Code 进程
2. 重新打开
3. 进入项目目录
4. 跑一个写操作,确认能成功

---

## 如果 sub-agent 仍报权限错

可能原因:
1. **没重启 Claude Code** — 永远先重启
2. **路径不匹配** — 比如 `lib/**` 不匹配 `lib/features/...` (实际 ** 是匹配的,这只是举例)
3. **沙箱模式** — Claude Code 可能开了沙箱模式覆盖 settings.json
4. **路径用绝对路径** — 试 `Write(/Users/tg/Desktop/my_app/lib/**)`

诊断:
```
> 请用 Write tool 创建 lib/test.txt 写 "hello",失败时告诉我具体错误信息
```
