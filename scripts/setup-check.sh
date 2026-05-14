#!/bin/bash
ERRORS=0
check_tool() {
    local tool=$1
    if command -v "$tool" &> /dev/null; then
        echo "✓ $tool: $($tool --version 2>&1 | head -n 1)"
    else
        echo "✗ $tool: NOT INSTALLED"
        ERRORS=$((ERRORS + 1))
    fi
}
echo "=== Checking Required Tools ==="
check_tool git
check_tool aws
check_tool terraform
check_tool docker
check_tool python3
echo
if [ $ERRORS -eq 0 ]; then
    echo "✓ All checks passed!"
    exit 0
else
    echo "✗ $ERRORS issue(s) found"
    exit 1
fi
