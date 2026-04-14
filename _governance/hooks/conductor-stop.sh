#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Conductor Stop Hook — 会话结束前检查流水线完整性
# ────────────────────────────────────────────────────────────────────
#  触发: Stop (Claude 会话结束前)
#
#  作用: 读 .flow_checkpoint/flow_state.json,检查每个模块是否
#       走完完整流水线,没走完就提示 Claude 补完
#
#  完整流水线 = 7 步:
#    1 spec → 2 plan → 3 api-design → 4 model → 5 api-gen → 6 page → 7 test
# ════════════════════════════════════════════════════════════════════

export PYTHONUTF8=1 PYTHONIOENCODING=utf-8 LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
exec /usr/bin/python3 <<'PYEOF'
import json, os, sys

STATE_FILE = ".flow_checkpoint/flow_state.json"

if not os.path.exists(STATE_FILE):
    sys.exit(0)

try:
    with open(STATE_FILE) as f:
        state = json.load(f)
except:
    sys.exit(0)

modules = state.get("modules", {})
if not modules:
    sys.exit(0)

STEP_NAMES = {
    1: "spec",
    2: "plan",
    3: "api-design",
    4: "model-gen",
    5: "api-gen",
    6: "page-gen",
    7: "test-gen",
}

incomplete = []
for module, info in modules.items():
    step = info.get("step", 0)
    if step < 7:
        missing = [STEP_NAMES[i] for i in range(step + 1, 8)]
        incomplete.append((module, step, missing))

if not incomplete:
    # 检查 review 是否跑了
    import glob
    reviews = glob.glob("docs/review/*.md")
    if not reviews:
        print("", file=sys.stderr)
        print("⚠️  Conductor: 所有模块流水线已完成,但还没跑 review!", file=sys.stderr)
        print("   建议用 flutter-review + flutter-perf-audit 做收尾评审", file=sys.stderr)
        print("", file=sys.stderr)
    sys.exit(0)

# 有未完成模块
print("", file=sys.stderr)
print(f"⛔ Conductor 检测: {len(incomplete)} 个模块流水线未走完!", file=sys.stderr)
print("", file=sys.stderr)
for module, step, missing in incomplete:
    last = STEP_NAMES.get(step, "none") if step > 0 else "未开始"
    print(f"   📦 {module}: step {step}/7 ({last})", file=sys.stderr)
    print(f"      缺少: {' → '.join(missing)}", file=sys.stderr)
print("", file=sys.stderr)
print("请补完缺失的步骤。每个模块必须走完 7 步:", file=sys.stderr)
print("  1.spec → 2.plan → 3.api-design → 4.model → 5.api-gen → 6.page → 7.test", file=sys.stderr)
print("", file=sys.stderr)
print("如确认放弃补完,设 BYPASS_CONDUCTOR_STOP=1", file=sys.stderr)

if os.environ.get("BYPASS_CONDUCTOR_STOP") == "1":
    sys.exit(0)
sys.exit(2)
PYEOF
