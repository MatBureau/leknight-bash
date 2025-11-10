#!/bin/bash

# Script de correction rapide des erreurs grep
# Utilise une approche simple avec find/replace

echo "═══════════════════════════════════════════════════════"
echo "  Fixing Module Errors"
echo "═══════════════════════════════════════════════════════"
echo ""

# Fonction pour corriger un fichier
fix_grep_in_file() {
    local file=$1
    if [ ! -f "$file" ]; then
        return
    fi

    echo "[*] Processing: $(basename "$file")"

    # Create backup
    cp "$file" "${file}.backup"

    # Fix grep pattern: remove --- from pattern
    # Change: grep -o "---HTTP_CODE:[0-9]*"
    # To: grep -oE "HTTP_CODE:[0-9]+"
    sed -i.tmp 's/grep -o "---HTTP_CODE:\[0-9\]\*"/grep -oE "HTTP_CODE:[0-9]+"/g' "$file" 2>/dev/null ||
        sed -i 's/grep -o "---HTTP_CODE:\[0-9\]\*"/grep -oE "HTTP_CODE:[0-9]+"/g' "$file"

    rm -f "${file}.tmp" 2>/dev/null

    echo "[✓] Fixed: $(basename "$file")"
}

# Liste des fichiers à corriger
FILES=(
    "modules/vulnerability_tests/csrf_module.sh"
    "modules/vulnerability_tests/idor_module.sh"
    "modules/vulnerability_tests/sqli_module.sh"
    "modules/vulnerability_tests/ssrf_module.sh"
    "modules/vulnerability_tests/xspa_module.sh"
)

for file in "${FILES[@]}"; do
    fix_grep_in_file "$file"
done

echo ""
echo "[✓] All grep patterns fixed!"
echo "[i] Backups saved with .backup extension"
echo ""
echo "Next: Fixing XSS module exports..."

# Fix XSS module - ensure functions are exported
XSS_MODULE="modules/vulnerability_tests/xss_module.sh"

if [ -f "$XSS_MODULE" ]; then
    echo "[*] Checking XSS module exports..."

    # Check if exports are present
    if ! grep -q "export -f test_reflected_xss" "$XSS_MODULE"; then
        echo "[!] Missing exports in XSS module, adding them..."

        # Add exports at the end if not present
        cat >> "$XSS_MODULE" <<'EOF'

# Export functions
export -f test_xss
export -f test_reflected_xss
export -f test_stored_xss
export -f test_dom_xss
export -f test_xss_parameter
export -f build_test_url
export -f extract_url_parameters
export -f urlencode
export -f save_xss_evidence
EOF
        echo "[✓] Added missing exports to XSS module"
    else
        echo "[✓] XSS module exports already present"
    fi
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Fix Summary"
echo "═══════════════════════════════════════════════════════"
echo "[✓] grep syntax errors fixed"
echo "[✓] XSS function exports verified"
echo ""
echo "Run ./leknight.sh to test the fixes!"
