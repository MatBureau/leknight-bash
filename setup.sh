#!/bin/bash

# LeKnight Setup Script
# Installs dependencies and prepares the environment

set -e

echo "╔════════════════════════════════════════════════════════╗"
echo "║         LeKnight v2.0 - Installation Script            ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "[!] Please run this script as a regular user (not root)"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "[!] Cannot detect operating system"
    exit 1
fi

echo "[*] Detected OS: $OS"
echo

# Function to install package
install_package() {
    local package=$1
    echo "[*] Installing $package..."

    case "$OS" in
        ubuntu|debian|kali)
            sudo apt-get install -y "$package" 2>/dev/null || echo "[!] Failed to install $package"
            ;;
        fedora|centos|rhel)
            sudo dnf install -y "$package" 2>/dev/null || echo "[!] Failed to install $package"
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm "$package" 2>/dev/null || echo "[!] Failed to install $package"
            ;;
        *)
            echo "[!] Unsupported OS for automatic installation"
            return 1
            ;;
    esac
}

# Update package lists
echo "[*] Updating package lists..."
case "$OS" in
    ubuntu|debian|kali)
        sudo apt-get update -qq
        ;;
    fedora|centos|rhel)
        sudo dnf update -y -q
        ;;
    arch|manjaro)
        sudo pacman -Sy
        ;;
esac

echo

# Install essential dependencies
echo "╔════════════════════════════════════════════════════════╗"
echo "║            Installing Core Dependencies                ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

CORE_DEPS=(
    "sqlite3"
    "curl"
    "wget"
    "git"
    "jq"
    "netcat"      # Critical for reverse shells
    "python3"     # For Python reverse shells
    "perl"        # For Perl reverse shells
)

for dep in "${CORE_DEPS[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        # Special handling for netcat (has different package names)
        if [ "$dep" = "netcat" ]; then
            # Try different netcat package names
            install_package "netcat-traditional" || install_package "ncat" || install_package "netcat" || install_package "nmap-ncat"
        else
            install_package "$dep"
        fi
    else
        echo "[✓] $dep already installed"
    fi
done

echo

# Install common pentesting tools
echo "╔════════════════════════════════════════════════════════╗"
echo "║          Installing Pentesting Tools (Optional)        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

echo "Would you like to install common pentesting tools?"
echo "This includes: nmap, nikto, sqlmap, hydra, ffuf, amass, wpscan, and more"
read -rp "Install? (y/n): " install_tools

if [[ $install_tools =~ ^[Yy] ]]; then
    PENTEST_TOOLS=(
        "nmap"
        "nikto"
        "sqlmap"
        "hydra"
        "dirb"
        "whatweb"
        "dnsenum"
        "masscan"
        "ffuf"
        "amass"
        "wpscan"
        "sslscan"
        "enum4linux"
        "snmp"
        "dnsutils"
        "whois"
        "dirsearch"
    )

    for tool in "${PENTEST_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            install_package "$tool"
        else
            echo "[✓] $tool already installed"
        fi
    done
fi

echo

# Install Go tools
echo "╔════════════════════════════════════════════════════════╗"
echo "║              Installing Go-based Tools                 ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

if ! command -v go &> /dev/null; then
    echo "[*] Go is not installed"
    read -rp "Install Go? (y/n): " install_go

    if [[ $install_go =~ ^[Yy] ]]; then
        install_package "golang-go" || install_package "go"
    fi
fi

if command -v go &> /dev/null; then
    echo "[*] Installing Go-based security tools..."

    # Add Go bin to PATH if not already
    export PATH=$PATH:$(go env GOPATH)/bin

    GO_TOOLS=(
        "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
        "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
        "github.com/projectdiscovery/httpx/cmd/httpx@latest"
        "github.com/hahwul/dalfox/v2@latest"  # XSS scanner
        "github.com/lc/gau/v2/cmd/gau@latest"
        "github.com/tomnomnom/waybackurls@latest"
        "github.com/hakluke/hakrawler@latest"
        "github.com/sensepost/gowitness@latest"
    )

    for tool in "${GO_TOOLS[@]}"; do
        tool_name=$(basename "$tool" | cut -d'@' -f1)
        if ! command -v "$tool_name" &> /dev/null; then
            echo "[*] Installing $tool_name..."
            go install -v "$tool" 2>/dev/null || echo "[!] Failed to install $tool_name"
        else
            echo "[✓] $tool_name already installed"
        fi
    done
fi

echo

# Install advanced optional tools
echo "╔════════════════════════════════════════════════════════╗"
echo "║        Installing Advanced Tools (Optional)            ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

echo "Would you like to install advanced reconnaissance tools?"
echo "This includes: theHarvester, sslyze, arjun"
read -rp "Install? (y/n): " install_advanced

if [[ $install_advanced =~ ^[Yy] ]]; then
    ADVANCED_TOOLS=(
        "theharvester"
        "sslyze"
    )

    for tool in "${ADVANCED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            install_package "$tool"
        else
            echo "[✓] $tool already installed"
        fi
    done

    # Install arjun via pip if Python is available
    if command -v pip3 &> /dev/null || command -v pip &> /dev/null; then
        if ! command -v arjun &> /dev/null; then
            echo "[*] Installing arjun via pip..."
            pip3 install arjun 2>/dev/null || pip install arjun 2>/dev/null || echo "[!] Failed to install arjun"
        else
            echo "[✓] arjun already installed"
        fi
    fi
fi

echo

# Set up directory structure
echo "╔════════════════════════════════════════════════════════╗"
echo "║            Setting Up Directory Structure              ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make scripts executable
echo "[*] Making scripts executable..."
chmod +x "${SCRIPT_DIR}/leknight.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/core/"*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/workflows/"*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/reports/"*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/modules/vulnerability_tests/"*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/modules/exploitation/"*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/migrate-db.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/start.sh" 2>/dev/null || true

# Note: Database will be initialized on first run of leknight.sh
echo "[*] Database will be initialized on first run"

# Display installed exploitation capabilities
echo
echo "╔════════════════════════════════════════════════════════╗"
echo "║          Exploitation Modules Status                   ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

# Check reverse shell dependencies
echo "[*] Checking reverse shell capabilities..."
if command -v nc &> /dev/null || command -v netcat &> /dev/null || command -v ncat &> /dev/null; then
    echo "[✓] Netcat available - Reverse shells enabled"
else
    echo "[!] WARNING: Netcat not found - Reverse shells will be limited"
fi

if command -v python3 &> /dev/null || command -v python &> /dev/null; then
    echo "[✓] Python available - Python reverse shells enabled"
else
    echo "[!] WARNING: Python not found - Python reverse shells disabled"
fi

if command -v perl &> /dev/null; then
    echo "[✓] Perl available - Perl reverse shells enabled"
else
    echo "[!] WARNING: Perl not found - Perl reverse shells disabled"
fi

if command -v bash &> /dev/null; then
    echo "[✓] Bash available - Bash reverse shells enabled"
fi

echo
echo "[*] Exploitation modules installed:"
[ -f "${SCRIPT_DIR}/modules/exploitation/rce_exploit.sh" ] && echo "  [✓] RCE Exploitation Module"
[ -f "${SCRIPT_DIR}/modules/exploitation/post_exploit.sh" ] && echo "  [✓] Post-Exploitation Module"

echo

# Create symlink (optional)
echo "╔════════════════════════════════════════════════════════╗"
echo "║                  Installation Complete                 ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

echo "[✓] LeKnight v2.0 has been installed successfully!"
echo

read -rp "Create symlink to /usr/local/bin/leknight? (requires sudo) (y/n): " create_symlink

if [[ $create_symlink =~ ^[Yy] ]]; then
    sudo ln -sf "${SCRIPT_DIR}/leknight.sh" /usr/local/bin/leknight
    echo "[✓] Symlink created. You can now run 'leknight' from anywhere"
else
    echo "[*] You can run LeKnight with: ${SCRIPT_DIR}/leknight.sh"
fi

echo

# Update Nuclei templates (if installed)
if command -v nuclei &> /dev/null; then
    echo "[*] Updating Nuclei templates..."
    nuclei -update-templates 2>/dev/null || true
fi

echo

echo "╔════════════════════════════════════════════════════════╗"
echo "║                    Getting Started                     ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

cat << 'USAGE'
Quick Start Guide:

1. Start LeKnight:
   ./leknight.sh
   or just: leknight (if symlink created)

2. Create a project:
   Menu > Project Management > Create New Project

3. Add targets to your project

4. Run Autopilot Mode for autonomous scanning:
   Menu > Autopilot Mode > Start Autopilot

5. View results and generate reports:
   Menu > View Results
   Menu > Generate Reports

6. **NEW** - Exploit discovered vulnerabilities:
   Menu > Autopilot Mode > Exploit Mode
   ⚠️  REQUIRES EXPLICIT AUTHORIZATION
   - Automated RCE exploitation with reverse shells
   - Post-exploitation enumeration
   - SQLMap database extraction
   - LFI file disclosure

NEW FEATURES IN v2.0:
✓ Union-based SQL injection testing
✓ DNS rebinding SSRF attacks
✓ Reverse shell automation (Bash, Python, Netcat, PHP, Perl)
✓ Post-exploitation with 6 enumeration phases
✓ Enhanced SQLMap parsing (credentials + hashes)
✓ Exploitation audit logging

For more information, see README.md

Happy Hunting! 🎯
⚠️  Remember: Only exploit with explicit written authorization!
USAGE

echo
echo "[*] Setup complete!"
