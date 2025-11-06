#!/bin/bash

# Script de debug pour LeKnight

echo "=== LeKnight Debug Test ==="
echo

# Test 1: Check script location
LEKNIGHT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[1] LEKNIGHT_ROOT: $LEKNIGHT_ROOT"

# Test 2: Check if files exist
echo
echo "[2] Checking core files:"
for file in core/logger.sh core/database.sh core/utils.sh core/project.sh; do
    if [ -f "$LEKNIGHT_ROOT/$file" ]; then
        echo "  ✓ $file exists"
    else
        echo "  ✗ $file MISSING"
    fi
done

# Test 3: Try sourcing files
echo
echo "[3] Attempting to source modules:"

# Colors first
RESET="$(tput sgr0)"
BOLD="$(tput bold)"
RED="$(tput setaf 5)"
BLUE="$(tput setaf 7)"
GRAY="$(tput setaf 8)"
BRIGHT_RED="${BOLD}$(tput setaf 3)"
BRIGHT_BLUE="${BOLD}$(tput setaf 7)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"

export RESET BOLD RED BLUE GRAY BRIGHT_RED BRIGHT_BLUE GREEN YELLOW

# Source logger
if source "${LEKNIGHT_ROOT}/core/logger.sh" 2>/dev/null; then
    echo "  ✓ logger.sh sourced"
else
    echo "  ✗ logger.sh FAILED"
    cat "${LEKNIGHT_ROOT}/core/logger.sh" | head -5
fi

# Source utils
if source "${LEKNIGHT_ROOT}/core/utils.sh" 2>/dev/null; then
    echo "  ✓ utils.sh sourced"
else
    echo "  ✗ utils.sh FAILED"
fi

# Source database
if source "${LEKNIGHT_ROOT}/core/database.sh" 2>/dev/null; then
    echo "  ✓ database.sh sourced"
else
    echo "  ✗ database.sh FAILED"
fi

# Source project
if source "${LEKNIGHT_ROOT}/core/project.sh" 2>/dev/null; then
    echo "  ✓ project.sh sourced"
else
    echo "  ✗ project.sh FAILED"
fi

# Test 4: Check if functions are available
echo
echo "[4] Checking if functions are defined:"
declare -F log_info >/dev/null && echo "  ✓ log_info defined" || echo "  ✗ log_info NOT defined"
declare -F db_init >/dev/null && echo "  ✓ db_init defined" || echo "  ✗ db_init NOT defined"
declare -F project_create >/dev/null && echo "  ✓ project_create defined" || echo "  ✗ project_create NOT defined"

# Test 5: Try calling a function
echo
echo "[5] Testing log_info function:"
if declare -F log_info >/dev/null; then
    log_info "This is a test message"
else
    echo "  ✗ Cannot test - function not defined"
fi

# Test 6: Check database path
echo
echo "[6] Database configuration:"
echo "  DB_PATH: ${DB_PATH:-NOT SET}"
echo "  Expected: ${LEKNIGHT_ROOT}/data/db/leknight.db"

# Test 7: Try database init
echo
echo "[7] Testing database init:"
if declare -F db_init >/dev/null; then
    DB_PATH="${LEKNIGHT_ROOT}/data/db/test_debug.db"
    export DB_PATH
    echo "  Using test DB: $DB_PATH"

    if db_init 2>&1; then
        echo "  ✓ Database initialized successfully"

        # Check if DB file was created
        if [ -f "$DB_PATH" ]; then
            echo "  ✓ Database file created"

            # Check tables
            echo
            echo "  Tables in database:"
            sqlite3 "$DB_PATH" ".tables" 2>&1 | sed 's/^/    /'
        else
            echo "  ✗ Database file NOT created"
        fi
    else
        echo "  ✗ Database init FAILED"
    fi
else
    echo "  ✗ db_init function not available"
fi

# Test 8: Test project creation
echo
echo "[8] Testing project creation:"
if declare -F project_create >/dev/null; then
    DB_PATH="${LEKNIGHT_ROOT}/data/db/test_debug.db"
    export DB_PATH

    result=$(project_create "Test Project" "Debug test" "example.com" 2>&1)
    echo "  Result: $result"
else
    echo "  ✗ project_create function not available"
fi

echo
echo "=== Debug Test Complete ==="
