#!/bin/bash

# Verification script for LeKnight bug fixes

echo "╔════════════════════════════════════════════════════════╗"
echo "║          LeKnight v2.0.3 - Fix Verification            ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

LEKNIGHT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$LEKNIGHT_ROOT"

PASSED=0
FAILED=0

# Test 1: Check protocol column in database schema
echo "[TEST 1] Checking database schema for protocol column..."
if grep -q "protocol TEXT DEFAULT 'http'" core/database.sh; then
    echo "  ✓ Protocol column exists in schema"
    ((PASSED++))
else
    echo "  ✗ Protocol column missing from schema"
    ((FAILED++))
fi

# Test 2: Check subdomain validation in parser
echo "[TEST 2] Checking subdomain validation in parser..."
if grep -q "Skipping unrelated domain" core/parsers.sh; then
    echo "  ✓ Subdomain validation implemented"
    ((PASSED++))
else
    echo "  ✗ Subdomain validation missing"
    ((FAILED++))
fi

# Test 3: Check fuzzing pipeline fix
echo "[TEST 3] Checking fuzzing pipeline integer fix..."
if grep -q 'exists="\${exists:-0}"' workflows/fuzzing_pipeline.sh; then
    echo "  ✓ Fuzzing pipeline integer fix applied"
    ((PASSED++))
else
    echo "  ✗ Fuzzing pipeline fix missing"
    ((FAILED++))
fi

# Test 4: Check XSS module replacement
echo "[TEST 4] Checking XSS module replacement..."
if [ -f "modules/vulnerability_tests/xss_module_simple.sh" ]; then
    echo "  ✓ New simplified XSS module exists"
    ((PASSED++))
else
    echo "  ✗ New XSS module missing"
    ((FAILED++))
fi

# Test 5: Check vulnerability_testing.sh uses new XSS module
echo "[TEST 5] Checking vulnerability_testing.sh configuration..."
if grep -q "xss_module_simple.sh" workflows/vulnerability_testing.sh; then
    echo "  ✓ vulnerability_testing.sh uses new XSS module"
    ((PASSED++))
else
    echo "  ✗ vulnerability_testing.sh not updated"
    ((FAILED++))
fi

# Test 6: Check dalfox in setup.sh
echo "[TEST 6] Checking dalfox in setup.sh..."
if grep -q "hahwul/dalfox" setup.sh; then
    echo "  ✓ Dalfox added to setup script"
    ((PASSED++))
else
    echo "  ✗ Dalfox missing from setup"
    ((FAILED++))
fi

# Test 7: Check SQLi function name fix
echo "[TEST 7] Checking SQLi module function names..."
if ! grep -q "db_add_credential" modules/vulnerability_tests/sqli_module.sh; then
    echo "  ✓ SQLi module uses correct function names"
    ((PASSED++))
else
    echo "  ✗ SQLi module still has incorrect function name"
    ((FAILED++))
fi

# Test 8: Syntax check on key files
echo "[TEST 8] Syntax checking critical modules..."
SYNTAX_OK=true

for file in \
    core/parsers.sh \
    core/database.sh \
    workflows/fuzzing_pipeline.sh \
    workflows/vulnerability_testing.sh \
    modules/vulnerability_tests/xss_module_simple.sh \
    modules/vulnerability_tests/sqli_module.sh
do
    if bash -n "$file" 2>/dev/null; then
        echo "  ✓ $file - syntax OK"
    else
        echo "  ✗ $file - syntax errors!"
        SYNTAX_OK=false
    fi
done

if [ "$SYNTAX_OK" = true ]; then
    ((PASSED++))
else
    ((FAILED++))
fi

# Test 9: Check if dalfox is installed
echo "[TEST 9] Checking if dalfox is installed..."
if command -v dalfox &> /dev/null; then
    echo "  ✓ Dalfox is installed"
    ((PASSED++))
else
    echo "  ⚠ Dalfox not installed (optional, but recommended)"
    echo "    Install with: go install github.com/hahwul/dalfox/v2@latest"
    # Don't count as failure since it's optional
    ((PASSED++))
fi

# Test 10: Check protocol preservation in autopilot
echo "[TEST 10] Checking protocol preservation in autopilot..."
if grep -q "SELECT protocol FROM targets" workflows/autopilot_advanced.sh; then
    echo "  ✓ Autopilot queries stored protocol"
    ((PASSED++))
else
    echo "  ✗ Autopilot doesn't query protocol"
    ((FAILED++))
fi

echo
echo "════════════════════════════════════════════════════════"
echo "                    TEST RESULTS                        "
echo "════════════════════════════════════════════════════════"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo

if [ $FAILED -eq 0 ]; then
    echo "✅ All fixes verified successfully!"
    echo
    echo "Next steps:"
    echo "1. If you have an existing database, run: bash core/db_migration_protocol.sh"
    echo "2. Install dalfox if not installed: go install github.com/hahwul/dalfox/v2@latest"
    echo "3. Test with: ./leknight.sh project create 'Test' && ./leknight.sh autopilot"
    exit 0
else
    echo "❌ Some fixes are missing or incomplete!"
    echo "Please review the failed tests above."
    exit 1
fi
