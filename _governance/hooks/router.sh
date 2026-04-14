#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Router Hook — 用户输入时提示该调哪个 skill
# ────────────────────────────────────────────────────────────────────
#  触发: UserPromptSubmit
#  作用:
#    - 读用户刚发的消息
#    - 关键词匹配 → 提示该用哪个 skill
#    - 多个匹配时列出候选
#    - 没匹配到时不提示
#
#  原理: 在 stderr 输出提示,Claude 会看到并优先用提示的 skill
# ════════════════════════════════════════════════════════════════════

export PYTHONUTF8=1 PYTHONIOENCODING=utf-8 LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export HOOK_INPUT="$(cat)"
exec /usr/bin/python3 <<'PYEOF'
import json, sys, re, os

try:
    data = json.loads(os.environ.get("HOOK_INPUT", "{}"))
except:
    sys.exit(0)

prompt = data.get("prompt", "")
if not prompt or len(prompt) < 3:
    sys.exit(0)

p = prompt.lower()

# 关键词 → skill 映射(按优先级排序,先匹配的优先)
# ⚠️ 规则:完整功能模块(flow-feature) 必须优先于 纯 UI 改版(flow-design)
# 原因:"做 X 模块 + figma 链接" 属于新功能(含 spec/plan/api),不是单纯重画 UI
RULES = [
    # Workflow 级(优先级最高)
    (["新建.*项目", "初始化.*项目", "搭建.*脚手架", "怎么开始"], "flutter-flow-init"),
    # 功能模块(含/不含设计稿都走完整 9 步)
    (["做.*模块", "实现.*模块", "实现.*功能", "新需求", "新功能",
      "做.*登录", "做.*注册", "做.*列表.*详情",
      "做一个.*页面.*接口", "按这份 prd", "按这个 prd",
      "根据.*prd", "根据.*需求", "做.*完整.*功能"], "flutter-flow-feature"),
    # 纯 UI 改版(不新增业务逻辑,只对照设计稿重画)
    (["重新设计.*页", "重画.*页", "改版.*页", "按这个图重画",
      "只改 ui", "只做 ui", "纯 ui 重画",
      "figma.com(?!.*模块)", "zeplin", "按这个图实现", "implement this design"], "flutter-flow-design / flutter-design-to-code"),
    (["评审一下", "代码评审", "code review", "review", "pr 评审"], "flutter-flow-review / flutter-review"),
    (["发版", "build release", "打 release", "打包"], "flutter-flow-release / flutter-release"),
    (["改技术栈", "新决策", "更新规范", "加一条 adr", "新 adr"], "flutter-flow-govern / flutter-context-update"),

    # Manifest 批量 + 回退(优先级高于具体 skill)
    (["生成.*清单.*模板", "新建 manifest", "批量.*清单", "准备批量", "生成 manifest",
      "批量.*模块", "批量.*生成", "批量做", "批量开发"], "flutter-manifest-init"),
    (["manifest:.*\\.yaml", "用.*manifest.*生成", "按清单生成"], "flutter-flow-feature (manifest 模式)"),
    (["回退.*v\\d+", "回到.*v\\d+", "撤销上次生成", "恢复.*之前.*代码", "列.*快照", "rollback"], "flutter-rollback"),
    (["导入.*切图", "我自己切.*图", "贴图.*改名", "把这.*图.*放进", "这些图片.*命名"], "flutter-asset-import"),

    # 单 skill - 快捷
    (["快速生成.*api", "一键生成.*接口", "粘贴.*生成"], "flutter-api-quick"),

    # 单 skill - 设计
    (["设计.*接口", "做.*接口契约", "新增 api"], "flutter-api-design"),
    (["拆任务", "做任务清单", "任务拆分"], "flutter-plan"),

    # 单 skill - 生成
    (["生成.*model", "json 转 dart", "json 转实体"], "flutter-model-gen"),
    (["生成.*repository", "生成接口请求", "生成 api 调用"], "flutter-api-gen"),
    (["生成.*页面", "做列表页", "做详情页", "做表单页", "做.*界面"], "flutter-page-gen"),
    (["做.*按钮组件", "生成.*卡片", "封装.*组件", "写.*组件", "做个 widget"], "flutter-widget-gen"),
    (["改主题", "加一个颜色", "改字号", "新主题"], "flutter-theme-design"),

    # 单 skill - 增强
    (["生成.*测试", "写单测", "加测试", "测试覆盖"], "flutter-test-gen"),
    (["生成.*mock", "补充.*测试数据", "生成 mock 数据"], "flutter-mock-gen"),
    (["国际化", "提取中文", "i18n", "改成 .tr"], "flutter-i18n-gen"),
    (["骨架屏", "shimmer", "加载占位"], "flutter-skeleton-gen"),
    (["错误码.*常量", "错误码 enum"], "flutter-error-code-gen"),
    (["生成接口文档", "整理接口清单"], "flutter-api-doc"),

    # 单 skill - 质量
    (["性能检查", "性能审计", "优化扫描"], "flutter-perf-audit"),
    (["体检", "项目健康", "健康检查", "诊断"], "flutter-health-check"),
    (["修格式", "跑 lint", "格式化"], "flutter-lint-fix"),

    # 单 skill - 工程
    (["配置多环境", "加 staging", "环境切换"], "flutter-env-config"),
    (["登录拦截", "路由守卫", "未登录跳"], "flutter-route-guard"),
    (["深链接", "universal link", "url 打开 app"], "flutter-deeplink"),
    (["重命名模块", "移动页面", "删除模块"], "flutter-migrate"),
    (["生成 changelog", "更新变更日志"], "flutter-changelog"),
]

matches = []
for patterns, skill in RULES:
    for pat in patterns:
        if re.search(pat, p):
            matches.append(skill)
            break

# 去重保序
seen = set()
unique = []
for m in matches:
    if m not in seen:
        seen.add(m)
        unique.append(m)

# 判断是否同时匹配了 flow-feature 和 flow-design(歧义)
has_feature = any("flow-feature" in s for s in unique)
has_design  = any("flow-design"  in s for s in unique)
ambiguous_workflow = has_feature and has_design

# ═══════════════════════════════════════════════════════════════════
# 检测 Figma URL 注入强制指令(防止 figma MCP 的 implement-design 抢优先级)
# ═══════════════════════════════════════════════════════════════════
has_figma_url = bool(re.search(r"figma\.com/(design|file)", prompt))
has_feature_intent = any(re.search(pat, p) for pat in [
    "做.*模块", "实现.*功能", "新需求", "做.*页面", "做.*界面",
    "splash", "启动页", "登录页", "首页", "列表", "详情",
    "按.*工作流", "flow-feature", "走完整"
])

if has_figma_url and has_feature_intent:
    # stdout 注入 — UserPromptSubmit hook 的 stdout 会追加到 prompt context
    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("⛔ [Router 强制指令] 检测到 Figma URL + 功能开发意图")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("")
    print("你必须使用 flutter-flow-feature 工作流,走完整 9 步流水线:")
    print("  spec → plan → (api-design/model/repo 按需) → page-gen →")
    print("  polishing → test-gen → review")
    print("")
    print("禁止行为:")
    print("  ❌ 不许调用 figma:figma-implement-design")
    print("  ❌ 不许调用 figma-implement-design")
    print("  ❌ 不许跳过 spec/plan 直接写代码")
    print("  ❌ 不许用 figma.com/api/mcp/asset/... URL 当生产代码(7 天过期)")
    print("")
    print("允许行为:")
    print("  ✅ 调用 figma MCP 的 get_screenshot / 读节点属性(只是数据来源)")
    print("  ✅ 用 curl 把切图下载到 assets/image/3.0x/{module}/")
    print("  ✅ 每步完成汇报 '✅ Step N: 产出' 再进下一步")
    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("")

# 没匹配到 skill 且没 Figma 注入的话,直接退出
if not unique and not (has_figma_url and has_feature_intent):
    sys.exit(0)

# 输出提示(stderr,advisory)
if unique:
    print("", file=sys.stderr)
    print("🎯 Router 建议:", file=sys.stderr)
    for i, skill in enumerate(unique[:3], 1):
        print(f"   {i}. 使用 {skill}", file=sys.stderr)

if ambiguous_workflow:
    print("", file=sys.stderr)
    print("⚠️  检测到歧义:同时匹配【功能模块】和【UI 改版】两个 workflow。", file=sys.stderr)
    print("   请先用 AskUserQuestion 问清楚用户意图,再选 workflow:", file=sys.stderr)
    print("   (A) 新功能模块 → flutter-flow-feature (完整 9 步:spec/plan/api/model/repo/page/i18n/test/review)", file=sys.stderr)
    print("   (B) 纯 UI 改版 → flutter-flow-design (仅:设计提取/切图/page-gen/review)", file=sys.stderr)
    print("   判断依据:需要新增接口/model 吗? 需要 → A;只重画已有页面 → B。", file=sys.stderr)
elif unique:
    print("   (根据你的输入匹配,仅供参考)", file=sys.stderr)
print("", file=sys.stderr)
PYEOF
