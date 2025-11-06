#!/bin/bash

# Fix permissions for LeKnight on Linux

echo "╔════════════════════════════════════════════════════════╗"
echo "║         LeKnight - Permission Fix Script              ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Current directory: $SCRIPT_DIR"
echo "[*] Current user: $(whoami)"
echo

# Change ownership to current user
echo "[*] Fixing ownership..."
sudo chown -R $(whoami):$(whoami) "$SCRIPT_DIR"

if [ $? -eq 0 ]; then
    echo "[✓] Ownership fixed"
else
    echo "[!] Failed to fix ownership"
    exit 1
fi

echo

# Make scripts executable
echo "[*] Making scripts executable..."
chmod +x "$SCRIPT_DIR/setup.sh"
chmod +x "$SCRIPT_DIR/leknight-v2.sh"
chmod +x "$SCRIPT_DIR"/core/*.sh 2>/dev/null
chmod +x "$SCRIPT_DIR"/workflows/*.sh 2>/dev/null
chmod +x "$SCRIPT_DIR"/reports/*.sh 2>/dev/null

if [ $? -eq 0 ]; then
    echo "[✓] Scripts are now executable"
else
    echo "[!] Failed to make scripts executable"
    exit 1
fi

echo

# Verify
echo "[*] Verification:"
ls -la "$SCRIPT_DIR"/leknight-v2.sh | head -1
ls -la "$SCRIPT_DIR"/setup.sh | head -1

echo
echo "[✓] Permissions fixed successfully!"
echo
echo "You can now run:"
echo "  ./setup.sh"
echo "  ./leknight-v2.sh"
