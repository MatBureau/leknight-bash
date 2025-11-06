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
)

for dep in "${CORE_DEPS[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        install_package "$dep"
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
echo "This includes: nmap, nikto, sqlmap, hydra, etc."
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

# Set up directory structure
echo "╔════════════════════════════════════════════════════════╗"
echo "║            Setting Up Directory Structure              ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make scripts executable
echo "[*] Making scripts executable..."
chmod +x "${SCRIPT_DIR}/leknight-v2.sh"
chmod +x "${SCRIPT_DIR}/core/"*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/workflows/"*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/reports/"*.sh 2>/dev/null || true

# Initialize database
echo "[*] Initializing database..."
export LEKNIGHT_ROOT="$SCRIPT_DIR"
source "${SCRIPT_DIR}/core/logger.sh"
source "${SCRIPT_DIR}/core/database.sh"
db_init

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
    sudo ln -sf "${SCRIPT_DIR}/leknight-v2.sh" /usr/local/bin/leknight
    echo "[✓] Symlink created. You can now run 'leknight' from anywhere"
else
    echo "[*] You can run LeKnight with: ${SCRIPT_DIR}/leknight-v2.sh"
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
   ./leknight-v2.sh
   or just: leknight (if symlink created)

2. Create a project:
   Menu > Project Management > Create New Project

3. Add targets to your project

4. Run Autopilot Mode for autonomous scanning:
   Menu > Autopilot Mode > Start Autopilot

5. View results and generate reports:
   Menu > View Results
   Menu > Generate Reports

For more information, see README.md

Happy Hunting! 🎯
USAGE

echo
echo "[*] Setup complete!"
