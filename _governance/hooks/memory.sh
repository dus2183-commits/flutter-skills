#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Memory Hook — 跨 session 项目记忆
# ────────────────────────────────────────────────────────────────────
#  触发: Stop (会话结束前)
#  作用: 把本次 session 的关键信息追加到 .claude/memory/project.md
#       下次打开 Claude 会自动读 CLAUDE.md 引用的 memory 文件
#
#  记录内容:
#    - 本次 session 做了哪些模块 (读 flow_state.json)
#    - 本次生成了哪些关键文件 (读 transitions-*.jsonl)
#    - 新增的依赖/配置变更
#    - 用户反馈/决策
# ════════════════════════════════════════════════════════════════════

exec /usr/bin/python3 <<'PYEOF'
import json, os, glob
from datetime import datetime

MEMORY_DIR = ".claude/memory"
MEMORY_FILE = f"{MEMORY_DIR}/project.md"

os.makedirs(MEMORY_DIR, exist_ok=True)

# 读流水线状态
state_path = ".flow_checkpoint/flow_state.json"
modules_done = []
if os.path.exists(state_path):
    try:
        with open(state_path) as f:
            state = json.load(f)
        for mod, info in state.get("modules", {}).items():
            step = info.get("step", 0)
            if step >= 7:
                modules_done.append(mod)
    except:
        pass

# 读今天的 transitions
today = datetime.now().strftime("%Y-%m-%d")
trans_file = f".flow_checkpoint/transitions-{today}.jsonl"
today_files = set()
if os.path.exists(trans_file):
    try:
        with open(trans_file) as f:
            for line in f:
                try:
                    entry = json.loads(line)
                    f_path = entry.get("file", "")
                    if f_path and not f_path.endswith((".freezed.dart", ".g.dart")):
                        today_files.add(f_path)
                except:
                    pass
    except:
        pass

# 如果 session 没做任何事,跳过
if not modules_done and not today_files:
    sys.exit(0) if False else None  # 不存在的情况
    import sys; sys.exit(0)

# 读现有 memory
existing = ""
if os.path.exists(MEMORY_FILE):
    try:
        with open(MEMORY_FILE) as f:
            existing = f.read()
    except:
        pass

# 生成本次 session 记录
now = datetime.now().strftime("%Y-%m-%d %H:%M")
session_log = f"\n## Session {now}\n\n"

if modules_done:
    session_log += f"**完成模块** ({len(modules_done)} 个):\n"
    for m in modules_done:
        session_log += f"- ✅ {m} (走完完整 7 步流水线)\n"
    session_log += "\n"

if today_files:
    # 按类型分组
    by_type = {}
    for f_path in sorted(today_files):
        ext = f_path.split(".")[-1] if "." in f_path else "其他"
        if "docs/specs" in f_path: key = "📋 Spec"
        elif "docs/plans" in f_path: key = "📝 Plan"
        elif "docs/api/" in f_path: key = "📡 API 契约"
        elif ".model.dart" in f_path: key = "📦 Model"
        elif "_repository.dart" in f_path: key = "🔌 Repository"
        elif "_page.dart" in f_path: key = "📱 Page"
        elif "_controller.dart" in f_path: key = "🎛 Controller"
        elif "_test.dart" in f_path: key = "🧪 Test"
        elif "mock/" in f_path: key = "🎭 Mock"
        elif "docs/review" in f_path: key = "🔍 Review"
        elif f_path.endswith(".md"): key = "📄 文档"
        else: key = "📁 其他"

        by_type.setdefault(key, []).append(f_path)

    session_log += f"**本次改动文件** ({len(today_files)} 个):\n"
    for key, files in sorted(by_type.items()):
        session_log += f"- {key}: {len(files)} 个\n"
    session_log += "\n"

# 写入(append)
if not existing:
    header = """# 项目记忆

> 这个文件由 memory hook 自动维护,记录每次 session 的关键动作。
> Claude 每次打开项目会读这个文件,了解项目历史。

"""
    existing = header

# 只保留最近 10 个 session
parts = existing.split("## Session ")
if len(parts) > 11:
    parts = [parts[0]] + parts[-10:]
    existing = "## Session ".join(parts)

final = existing + session_log

with open(MEMORY_FILE, "w") as f:
    f.write(final)

print(f"📝 Memory: {MEMORY_FILE} 已更新 (本次 {len(today_files)} 个文件变更)", file=__import__("sys").stderr)
PYEOF
