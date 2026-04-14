#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Conductor Hook — 流水线状态机追踪 + 跳步拦截
# ────────────────────────────────────────────────────────────────────
#  触发: PreToolUse (Write) + PostToolUse (Write)
#
#  作用:
#    - 追踪每个模块走到流水线第几步
#    - 写文件前检查依赖是否满足(跳步会拦截)
#    - 写文件后更新状态
#
#  状态存储: .flow_checkpoint/flow_state.json
#  {
#    "modules": {
#      "auth": { "step": 3, "last": "api-design", "ts": 123456 }
#    }
#  }
#
#  流水线依赖:
#    1 spec       → docs/specs/{m}.md
#    2 plan       → docs/plans/{m}.md          (依赖 1)
#    3 api-design → docs/api/{m}.md            (依赖 2)
#    4 model-gen  → lib/features/{m}/data/models/*.model.dart (依赖 3)
#    5 api-gen    → lib/features/{m}/data/repositories/*.dart (依赖 4)
#    6 page-gen   → lib/features/{m}/presentation/pages/      (依赖 5)
#    7 test-gen   → test/features/{m}/*_test.dart             (依赖 5)
# ════════════════════════════════════════════════════════════════════

set -e

INPUT=$(cat)
EVENT="${CLAUDE_HOOK_EVENT:-PostToolUse}"

export PYTHONUTF8=1 PYTHONIOENCODING=utf-8 LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
/usr/bin/python3 <<PYEOF
import json, os, re, sys, time

INPUT = """$INPUT"""
EVENT = "$EVENT"

try:
    data = json.loads(INPUT)
except:
    sys.exit(0)

tool = data.get('tool_name', '')
if tool not in ('Write', 'Edit'):
    sys.exit(0)

file_path = data.get('tool_input', {}).get('file_path', '')
if not file_path:
    sys.exit(0)

# 解析模块名和步骤
STEP_PATTERNS = [
    (1, 'spec',       r'docs/specs/([^/]+)\.md$'),
    (2, 'plan',       r'docs/plans/([^/]+)\.md$'),
    (3, 'api-design', r'docs/api/([^/]+)\.md$'),
    (4, 'model-gen',  r'lib/features/([^/]+)/data/models/[^/]+\.model\.dart$'),
    (5, 'api-gen',    r'lib/features/([^/]+)/data/repositories/[^/]+_repository\.dart$'),
    (6, 'page-gen',   r'lib/features/([^/]+)/presentation/pages/'),
    (7, 'test-gen',   r'test/features/([^/]+)/.+_test\.dart$'),
]

match_step = None
match_module = None
match_name = None
for step, name, pattern in STEP_PATTERNS:
    m = re.search(pattern, file_path)
    if m:
        match_step = step
        match_name = name
        match_module = m.group(1)
        break

if not match_step:
    # 不是流水线文件，跳过
    sys.exit(0)

# 跳过生成的文件
if file_path.endswith(('.freezed.dart', '.g.dart', '.config.dart')):
    sys.exit(0)

STATE_FILE = '.flow_checkpoint/flow_state.json'
os.makedirs('.flow_checkpoint', exist_ok=True)

# 读现有状态
state = {"modules": {}}
if os.path.exists(STATE_FILE):
    try:
        with open(STATE_FILE) as f:
            state = json.load(f)
    except:
        pass

mod_state = state["modules"].get(match_module, {"step": 0, "last": None})

if EVENT == "PreToolUse":
    # 检查依赖是否满足
    required_prev = match_step - 1

    # 特殊: test-gen 依赖 step 5 (api-gen),不需要 6
    if match_name == 'test-gen':
        required_prev = 5

    if mod_state["step"] < required_prev:
        missing = []
        for step, name, _ in STEP_PATTERNS[:required_prev]:
            if mod_state["step"] < step:
                missing.append(f"{step}.{name}")

        print(f"⛔ Conductor: 跳步检测!", file=sys.stderr)
        print(f"   模块 '{match_module}' 当前在 step {mod_state['step']} ({mod_state['last'] or 'none'})", file=sys.stderr)
        print(f"   试图写: {file_path}", file=sys.stderr)
        print(f"   这是 step {match_step} ({match_name})", file=sys.stderr)
        print(f"   缺少: {', '.join(missing)}", file=sys.stderr)
        print(f"", file=sys.stderr)
        print(f"   必须先完成依赖步骤,不能跳过。", file=sys.stderr)
        print(f"   如果确认绕过(如用户指定),设 BYPASS_CONDUCTOR=1", file=sys.stderr)

        if os.environ.get('BYPASS_CONDUCTOR') == '1':
            sys.exit(0)
        sys.exit(2)  # 拦截

    # 同步执行检查通过

elif EVENT == "PostToolUse":
    # 更新状态
    if match_step > mod_state["step"]:
        mod_state["step"] = match_step
        mod_state["last"] = match_name
        mod_state["ts"] = int(time.time())
        state["modules"][match_module] = mod_state

        with open(STATE_FILE, 'w') as f:
            json.dump(state, f, indent=2, ensure_ascii=False)

        print(f"✅ Conductor: {match_module} → step {match_step} ({match_name})", file=sys.stderr)
PYEOF
