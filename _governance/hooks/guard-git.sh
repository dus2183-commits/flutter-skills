#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Guard Git Hook — 拦截危险的 git 命令
# ────────────────────────────────────────────────────────────────────
#  触发: PreToolUse (Bash)
#  作用: 防止 Claude 误用危险 git 命令
# ════════════════════════════════════════════════════════════════════

INPUT=$(cat)
CMD=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

if [[ -z "$CMD" ]]; then
  exit 0
fi

# 危险命令列表
DANGEROUS_PATTERNS=(
  "git push.*--force"
  "git push.*-f "
  "git push.*-f$"
  "git reset --hard"
  "git clean -fd"
  "git clean -fx"
  "git branch -D"
  "git commit.*--amend.*--no-edit"
  "git rebase.*--abort"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if [[ "$CMD" =~ $pattern ]]; then
    echo "⛔ 拦截危险 git 命令: $CMD" >&2
    echo "" >&2
    echo "此命令可能造成不可逆的损失。" >&2
    echo "如果确实需要,请用户手动执行。" >&2
    exit 2
  fi
done

# 禁止空 commit message
if [[ "$CMD" =~ git[[:space:]]+commit.*-m[[:space:]]+[\"\']{2} ]]; then
  echo "⛔ 禁止空 commit message" >&2
  exit 2
fi

# 提醒: 不允许自动 push (必须用户确认)
if [[ "$CMD" =~ ^git[[:space:]]+push ]]; then
  # 允许但提示(不阻止,因为用户可能真的要 push)
  echo "⚠️  注意: 正在执行 git push,请确认已得到用户授权" >&2
fi

exit 0
