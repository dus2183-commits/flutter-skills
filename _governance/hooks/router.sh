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

exec /usr/bin/python3 <<'PYEOF'
import json, sys, re

try:
    data = json.load(sys.stdin)
except:
    sys.exit(0)

prompt = data.get("prompt", "")
if not prompt or len(prompt) < 5:
    sys.exit(0)

p = prompt.lower()

# 关键词 → skill 映射(按优先级排序,先匹配的优先)
RULES = [
    # Workflow 级(优先级最高)
    (["新建.*项目", "初始化.*项目", "搭建.*脚手架", "怎么开始"], "flutter-flow-init"),
    (["做.*模块", "实现.*功能", "新需求", "做一个.*页面.*接口", "按这份 prd"], "flutter-flow-feature"),
    (["figma.com", "zeplin", "按这个图实现", "根据.*设计稿", "implement this design", "重新设计.*页"], "flutter-flow-design / flutter-design-to-code"),
    (["评审一下", "代码评审", "code review", "review", "pr 评审"], "flutter-flow-review / flutter-review"),
    (["发版", "build release", "打 release", "打包"], "flutter-flow-release / flutter-release"),
    (["改技术栈", "新决策", "更新规范", "加一条 adr", "新 adr"], "flutter-flow-govern / flutter-context-update"),

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

if not matches:
    sys.exit(0)

# 去重保序
seen = set()
unique = []
for m in matches:
    if m not in seen:
        seen.add(m)
        unique.append(m)

# 输出提示(stderr)
print("", file=sys.stderr)
print("🎯 Router 建议:", file=sys.stderr)
for i, skill in enumerate(unique[:3], 1):  # 最多显示 3 个
    print(f"   {i}. 使用 {skill}", file=sys.stderr)
print("   (根据你的输入匹配,仅供参考)", file=sys.stderr)
print("", file=sys.stderr)
PYEOF
