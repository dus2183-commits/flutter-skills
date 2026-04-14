#!/bin/bash
# pre-commit.sh
# Hook: git commit 前跑 lint + test
#
# 安装:
#   ln -s ../../_governance/hooks/pre-commit.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit

set -e

echo "🔍 Pre-commit checks..."

# 1. dart format check
if command -v dart &> /dev/null; then
  echo "  → dart format check"
  if ! dart format --output=none --set-exit-if-changed lib/ test/; then
    echo "❌ Code is not formatted. Run: dart format lib/ test/"
    exit 1
  fi
fi

# 2. flutter analyze
if command -v flutter &> /dev/null; then
  echo "  → flutter analyze"
  if ! flutter analyze --no-pub; then
    echo "❌ Lint errors found"
    exit 1
  fi
fi

# 3. flutter test (only if test/ has files)
if [ -d test ] && [ "$(ls -A test 2>/dev/null)" ]; then
  if command -v flutter &> /dev/null; then
    echo "  → flutter test"
    if ! flutter test --no-pub; then
      echo "❌ Tests failed"
      exit 1
    fi
  fi
fi

# 4. Check no .env.prod is staged
if git diff --cached --name-only | grep -q "\.env\.prod"; then
  echo "❌ .env.prod must not be committed"
  exit 1
fi

# 5. Check no hardcoded secrets
if git diff --cached -U0 | grep -E "^\+" | grep -iE "(password|secret|api[_-]?key)\s*=\s*['\"][^'\"]{8,}" | grep -v "your_key_here" > /dev/null; then
  echo "⚠️  Possible hardcoded secret detected. Review changes."
  exit 1
fi

echo "✅ All checks passed"
exit 0
