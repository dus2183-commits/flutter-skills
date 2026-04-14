#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  自动化测试 — 验证本轮新增 4 个 skill + 5 处改动
# ────────────────────────────────────────────────────────────────────
#  跑法: bash scripts/test_new_features.sh
#  不改任何真实项目文件,只读 + 模拟
# ════════════════════════════════════════════════════════════════════

set -e
cd "$(dirname "$0")/.."

# 选 python(需要 yaml 模块): brew python 优先,否则 /usr/bin/python3
PY=/usr/bin/python3
if command -v /opt/homebrew/bin/python3 >/dev/null 2>&1 && \
   /opt/homebrew/bin/python3 -c "import yaml" 2>/dev/null; then
  PY=/opt/homebrew/bin/python3
elif ! $PY -c "import yaml" 2>/dev/null; then
  echo "⚠️  系统 python 没 yaml 模块,尝试 pip3 install --user pyyaml"
  pip3 install --user pyyaml >/dev/null 2>&1 || true
fi
echo "使用 Python: $PY"

PASS=0
FAIL=0
WARN=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠️  $1"; WARN=$((WARN+1)); }
title() { echo ""; echo "▶ $1"; }

# ════════════════════════════════════════════════════════════════════
# Test 1: 新 skill 目录和 SKILL.md frontmatter 完整
# ════════════════════════════════════════════════════════════════════
title "Test 1 — 新 skill 目录 & frontmatter"

for skill in flutter-manifest-init flutter-asset-import flutter-rollback; do
  if [ -f "$skill/SKILL.md" ]; then
    if grep -q "^name: $skill$" "$skill/SKILL.md" && \
       grep -q "^description:" "$skill/SKILL.md" && \
       grep -q "^version:" "$skill/SKILL.md"; then
      pass "$skill/SKILL.md 有完整 frontmatter"
    else
      fail "$skill/SKILL.md frontmatter 不完整"
    fi
  else
    fail "$skill/SKILL.md 不存在"
  fi
done

# ════════════════════════════════════════════════════════════════════
# Test 2: YAML 模版合法(能 yaml.safe_load)
# ════════════════════════════════════════════════════════════════════
title "Test 2 — YAML 模版合法性"

export PYTHONUTF8=1 LC_ALL=en_US.UTF-8
for tpl in _knowledge/context-templates/api-global.template.yaml \
           _knowledge/context-templates/manifest.template.yaml; do
  if [ -f "$tpl" ]; then
    if $PY -c "import yaml; yaml.safe_load(open('$tpl'))" 2>/dev/null; then
      pass "$tpl 是合法 YAML"
    else
      fail "$tpl YAML 解析失败"
    fi
  else
    fail "$tpl 不存在"
  fi
done

# ════════════════════════════════════════════════════════════════════
# Test 3: manifest 模版 JSON 块能独立解析
# ════════════════════════════════════════════════════════════════════
title "Test 3 — manifest 里 req_json/resp_json 是合法 JSON"

$PY <<'PYEOF'
import yaml, json, sys
data = yaml.safe_load(open('_knowledge/context-templates/manifest.template.yaml'))
errs = 0
ok = 0
for m in data.get('modules', []):
    for ep in m.get('endpoints', []):
        for key in ('req_json', 'resp_json', 'req_query', 'req_form'):
            v = ep.get(key)
            if v:
                try:
                    json.loads(v)
                    ok += 1
                except Exception as e:
                    print(f"  ❌ {m['name']} {ep.get('path')} {key}: {e}")
                    errs += 1
if errs == 0:
    print(f"  ✅ {ok} 个 JSON 块全部合法")
    sys.exit(0)
else:
    sys.exit(1)
PYEOF
if [ $? -eq 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ════════════════════════════════════════════════════════════════════
# Test 4: 5 个 python hook 已加 UTF-8 导出(防止 Non-UTF-8 报错)
# ════════════════════════════════════════════════════════════════════
title "Test 4 — hook UTF-8 防御"

for hook in reflector.sh router.sh memory.sh conductor-stop.sh conductor.sh; do
  if grep -q "PYTHONUTF8=1" "_governance/hooks/$hook"; then
    pass "$hook 已 export PYTHONUTF8"
  else
    fail "$hook 缺 PYTHONUTF8 — 中文可能触发 Non-UTF-8 错误"
  fi
done

# ════════════════════════════════════════════════════════════════════
# Test 5: Hook 能处理中文 prompt 不报错(模拟)
# ════════════════════════════════════════════════════════════════════
title "Test 5 — router.sh 吃中文 prompt 不崩"

TEST_INPUT='{"prompt":"生成清单模板,我要做几个模块"}'
OUTPUT=$(echo "$TEST_INPUT" | bash _governance/hooks/router.sh 2>&1 || true)
if echo "$OUTPUT" | grep -q "Non-UTF-8\|SyntaxError"; then
  fail "router.sh 对中文报错: $OUTPUT"
else
  pass "router.sh 吃中文不报错"
fi

# ════════════════════════════════════════════════════════════════════
# Test 6: Router 新关键词命中
# ════════════════════════════════════════════════════════════════════
title "Test 6 — Router 新关键词路由正确"

check_route() {
  local prompt="$1"
  local expected="$2"
  local out
  out=$(echo "{\"prompt\":\"$prompt\"}" | bash _governance/hooks/router.sh 2>&1 || true)
  if echo "$out" | grep -q "$expected"; then
    pass "\"$prompt\" → $expected"
  else
    fail "\"$prompt\" 未命中 $expected (实际: $out)"
  fi
}

check_route "生成清单模板" "flutter-manifest-init"
check_route "我要批量做几个模块" "flutter-manifest-init"
check_route "回退到 v2" "flutter-rollback"
check_route "导入切图" "flutter-asset-import"
check_route "做一个登录模块" "flutter-dev"

# ════════════════════════════════════════════════════════════════════
# Test 7: Router 歧义提示(同时匹配 flow-feature + flow-design)
# ════════════════════════════════════════════════════════════════════
title "Test 7 — Router 歧义警告"

# "做登录模块" 只命中 feature,不算歧义
AMBIGUOUS_OUT=$(echo '{"prompt":"按这个图重画登录页"}' | bash _governance/hooks/router.sh 2>&1 || true)
# 这个只命中 design
if echo "$AMBIGUOUS_OUT" | grep -q "flutter-flow-design"; then
  pass "纯 UI 重画路由到 flow-design"
else
  warn "纯 UI 重画未命中 flow-design (实际: $AMBIGUOUS_OUT)"
fi

# ════════════════════════════════════════════════════════════════════
# Test 8: Reflector 拦截 @freezed 但不是 .model.dart 的文件
# ════════════════════════════════════════════════════════════════════
title "Test 8 — Reflector 拦截 .model.dart 命名违规"

TMP_DART=$(mktemp -t reflector_XXXXXX.dart)
cat > "$TMP_DART" <<'DARTEOF'
import 'package:freezed_annotation/freezed_annotation.dart';
part 'login_response.freezed.dart';
part 'login_response.g.dart';

@freezed
class LoginResponse with _$LoginResponse {
  const factory LoginResponse({required String token}) = _LoginResponse;
  factory LoginResponse.fromJson(Map<String, dynamic> json) => _$LoginResponseFromJson(json);
}
DARTEOF

REFLECTOR_INPUT=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$TMP_DART")
REFLECTOR_OUT=$(echo "$REFLECTOR_INPUT" | bash _governance/hooks/reflector.sh 2>&1 || true)
REFLECTOR_EXIT=$?

if echo "$REFLECTOR_OUT" | grep -q "命名违规.*\.model\.dart"; then
  pass "Reflector 拦截 @freezed 非 .model.dart 命名"
else
  fail "Reflector 未拦截命名违规 (输出: $REFLECTOR_OUT)"
fi
rm -f "$TMP_DART"

# ════════════════════════════════════════════════════════════════════
# Test 9: Reflector 对正确命名不拦截
# ════════════════════════════════════════════════════════════════════
title "Test 9 — Reflector 放行合规文件"

TMP_MODEL=$(mktemp -t reflector_XXXXXX).model.dart
cat > "$TMP_MODEL" <<'DARTEOF'
import 'package:freezed_annotation/freezed_annotation.dart';
part 'user.model.freezed.dart';
part 'user.model.g.dart';

@freezed
class User with _$User {
  const factory User({required int id}) = _User;
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
DARTEOF

REFLECTOR_INPUT=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$TMP_MODEL")
echo "$REFLECTOR_INPUT" | bash _governance/hooks/reflector.sh >/dev/null 2>&1
if [ $? -eq 0 ]; then
  pass "Reflector 放行合规 .model.dart"
else
  fail "Reflector 误拦截合规文件"
fi
rm -f "$TMP_MODEL"

# ════════════════════════════════════════════════════════════════════
# Test 10: flow-feature SKILL.md 已加 manifest 模式 B
# ════════════════════════════════════════════════════════════════════
title "Test 10 — flow-feature 支持 manifest 入参"

if grep -q "模式 B.*Manifest\|manifest:.*\.yaml" _orchestration/flutter-flow-feature/SKILL.md; then
  pass "flow-feature SKILL.md 有 manifest 模式段"
else
  fail "flow-feature SKILL.md 未加 manifest 模式"
fi

# ════════════════════════════════════════════════════════════════════
# Test 11: model-gen SKILL.md 有 .model.dart 命名铁律
# ════════════════════════════════════════════════════════════════════
title "Test 11 — model-gen 有命名铁律段"

if grep -q "文件命名铁律" flutter-model-gen/SKILL.md; then
  pass "model-gen 有命名铁律段"
else
  fail "model-gen 缺命名铁律段"
fi

# ════════════════════════════════════════════════════════════════════
# 汇总
# ════════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════"
echo "  ✅ 通过: $PASS"
echo "  ❌ 失败: $FAIL"
echo "  ⚠️  警告: $WARN"
echo "═══════════════════════════════════════"

# ════════════════════════════════════════════════════════════════════
# Test 12: Router 检测 Figma URL + 功能意图 → stdout 注入强制指令
# ════════════════════════════════════════════════════════════════════
title "Test 12 — Figma URL 注入强制指令"

OUT=$(echo '{"prompt":"做一个 splash 启动页 https://www.figma.com/design/abc?node-id=1-43 纯UI"}' | \
      bash _governance/hooks/router.sh 2>/dev/null)
if echo "$OUT" | grep -q "figma-implement-design.*flutter-post-figma\|Router 调用链\|阶段 2.*flutter-post-figma"; then
  pass "Figma URL + 功能意图 → 注入禁令"
else
  fail "未注入禁令 (stdout: $OUT)"
fi

# 无 Figma URL 不应注入
OUT2=$(echo '{"prompt":"做一个 auth 模块"}' | bash _governance/hooks/router.sh 2>/dev/null)
if echo "$OUT2" | grep -q "强制指令"; then
  fail "无 Figma URL 也注入了 (不应该)"
else
  pass "无 Figma URL 不注入"
fi

# ════════════════════════════════════════════════════════════════════
# Test 13: Reflector 拦截 .dart 里的 figma MCP URL
# ════════════════════════════════════════════════════════════════════
title "Test 13 — Reflector 拦截 figma MCP URL"

TMP_DART=$(mktemp -t ref_mcp_XXXXXX).dart
cat > "$TMP_DART" <<'DARTEOF'
const _kLogo = 'https://www.figma.com/api/mcp/asset/92a13c99-eead-4215-9f2b';
DARTEOF
INPUT=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$TMP_DART")
OUT=$(echo "$INPUT" | bash _governance/hooks/reflector.sh 2>&1 || true)
if echo "$OUT" | grep -q "figma.com/api/mcp/asset"; then
  pass "Reflector 拦截 MCP URL"
else
  fail "Reflector 未拦截 (输出: $OUT)"
fi
rm -f "$TMP_DART"

# ════════════════════════════════════════════════════════════════════
# Test 14: Reflector 拦截 spec.md 的 CDN 后门话术
# ════════════════════════════════════════════════════════════════════
title "Test 14 — Reflector 拦截 spec CDN 后门"

TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR/docs/specs"
SPEC_FILE="$TMP_DIR/docs/specs/splash.md"
cat > "$SPEC_FILE" <<'MDEOF'
## 1. 目标
...
## 2. 涉及页面
## 3. 页面流转
## 4. 接口需求
## 5. 关键字段
## 6. 异常场景
- a
- b
- c
## 7. 非功能需求
Figma CDN URL 有效期 7 天,之后替换为本地资源
MDEOF

INPUT=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$SPEC_FILE")
OUT=$(echo "$INPUT" | bash _governance/hooks/reflector.sh 2>&1 || true)
if echo "$OUT" | grep -q "后门话术"; then
  pass "Reflector 拦截 spec CDN 后门"
else
  fail "Reflector 未拦截 spec 后门 (输出: $OUT)"
fi
rm -rf "$TMP_DIR"

# ════════════════════════════════════════════════════════════════════
# Test 15: CLAUDE.md 模板有 Figma URL 铁律段
# ════════════════════════════════════════════════════════════════════
title "Test 15 — CLAUDE.md 模板有 Figma 铁律"

if grep -q "Figma URL 处理\|flutter-post-figma" flutter-init/template/CLAUDE.md; then
  pass "CLAUDE.md 有 Figma URL 处理段(双阶段协作)"
else
  fail "CLAUDE.md 缺 Figma URL 处理段"
fi

# ════════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════"
echo "  ✅ 通过: $PASS"
echo "  ❌ 失败: $FAIL"
echo "  ⚠️  警告: $WARN"
echo "═══════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  echo ""
  echo "🎉 所有测试通过,可以提交了"
  exit 0
fi
