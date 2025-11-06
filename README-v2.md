# LeKnight v2.0 - Professional Bug Bounty & Pentesting Framework

![LeKnight Banner](https://img.shields.io/badge/LeKnight-v2.0-red?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)
![Bash](https://img.shields.io/badge/Bash-5.0+-green?style=for-the-badge)

## Overview

LeKnight v2.0 is a complete rewrite of the original LeKnight framework, transforming it from a simple tool launcher into a **professional-grade autonomous pentesting framework**. It's designed for bug bounty hunters and penetration testers who need to manage complex engagements with multiple targets, automated workflows, and comprehensive reporting.

## Key Features

### 🎯 Project Management
- **Multi-project support** with isolated workspaces
- **Scope management** with automatic target validation
- **Target tracking** with automatic discovery and enumeration
- **SQLite database** for persistent storage of all results

### 🤖 Autonomous Scanning (Autopilot)
- **Intelligent target analysis** - automatically detects IP, domain, or URL
- **Adaptive workflows** - chooses appropriate tools based on discoveries
- **Recursive enumeration** - discovers and scans subdomains automatically
- **Zero-touch operation** - runs continuously without human intervention

### 📊 Advanced Result Management
- **Automatic parsing** of tool outputs
- **Severity classification** (Critical, High, Medium, Low, Info)
- **Credential extraction** and storage
- **Finding deduplication** and correlation

### 📈 Professional Reporting
- **Markdown reports** with executive summaries
- **CSV exports** for spreadsheet analysis
- **JSON exports** for integration with other tools
- **Real-time dashboards** showing project status

### 🔄 Workflow Automation
- **Pre-built workflows** for common scenarios:
  - Web application reconnaissance (quick/medium/deep)
  - Network sweeps (quick/medium/deep)
  - Subdomain scanning
  - Service-specific enumeration
- **Intelligent chaining** - results from one tool feed into the next

### 📝 Comprehensive Logging
- **Multi-level logging** (DEBUG, INFO, SUCCESS, WARNING, ERROR, CRITICAL)
- **Colored output** for easy reading
- **File logging** with timestamps
- **Log search and export**

## Installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/MatBureau/leknight-bash.git
cd leknight-bash

# Run setup script
chmod +x setup.sh
./setup.sh

# Start LeKnight
./leknight-v2.sh
```

### Manual Installation

```bash
# Install core dependencies
sudo apt-get update
sudo apt-get install -y sqlite3 curl wget git jq

# Install common pentesting tools
sudo apt-get install -y nmap nikto sqlmap hydra dirb whatweb

# Install Go-based tools (optional but recommended)
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest

# Make scripts executable
chmod +x leknight-v2.sh
chmod +x core/*.sh workflows/*.sh reports/*.sh
```

## Quick Start

### 1. Create a Project

```bash
./leknight-v2.sh

# Navigate to: Project Management > Create New Project
# Enter:
#   - Project Name: "Acme Corp Pentest"
#   - Description: "External penetration test"
#   - Scope: example.com, *.example.com, 192.168.1.0/24
```

### 2. Option A: Use Autopilot (Recommended)

```bash
# Navigate to: Autopilot Mode > Start Autopilot
# Sit back and watch as LeKnight:
#   - Analyzes each target in scope
#   - Runs appropriate reconnaissance tools
#   - Discovers new targets (subdomains, IPs)
#   - Enumerates services
#   - Detects vulnerabilities
#   - Extracts credentials
```

### 2. Option B: Manual Workflows

```bash
# Navigate to: Workflows > Web Reconnaissance
# Enter target: https://example.com
# Select depth: Medium
```

### 3. View Results

```bash
# Navigate to: View Results > Project Dashboard
# See:
#   - Total targets discovered
#   - Scans executed
#   - Findings by severity
#   - Discovered credentials
```

### 4. Generate Report

```bash
# Navigate to: Generate Reports > Markdown Report
# Report will be saved to: data/projects/[ID]/reports/
```

## Architecture

```
leknight-bash/
├── core/
│   ├── database.sh       # SQLite operations
│   ├── logger.sh         # Logging system
│   ├── utils.sh          # Utility functions
│   ├── project.sh        # Project management
│   ├── wrapper.sh        # Tool execution wrapper
│   └── parsers.sh        # Output parsers
│
├── workflows/
│   ├── web_recon.sh      # Web application workflows
│   ├── network_sweep.sh  # Network scanning workflows
│   └── autopilot.sh      # Autonomous scanning engine
│
├── reports/
│   └── generate_md.sh    # Report generation
│
├── data/
│   ├── db/               # SQLite database
│   ├── projects/         # Project workspaces
│   ├── scans/            # Tool outputs
│   ├── logs/             # Log files
│   └── exports/          # Exported reports
│
└── leknight-v2.sh        # Main entry point
```

## Database Schema

LeKnight uses SQLite to store all project data:

```sql
- projects        # Project metadata
- targets         # Discovered targets
- scans           # Executed scans
- findings        # Discovered vulnerabilities
- credentials     # Extracted credentials
- workflow_runs   # Workflow execution history
```

## Autopilot Mode

The Autopilot is the crown jewel of LeKnight v2.0. It operates in a continuous loop:

1. **Target Discovery**: Reads targets from project scope
2. **Target Analysis**: Determines target type (IP/domain/URL)
3. **Workflow Selection**: Chooses appropriate scanning strategy
4. **Execution**: Runs tools and captures output
5. **Parsing**: Extracts findings, credentials, and new targets
6. **Iteration**: Repeats for newly discovered targets

### Autopilot Example

```bash
# Input: Single domain
example.com

# Autopilot discovers:
├── 15 subdomains (via subfinder)
├── 23 open ports (via nmap)
├── 8 web services (via whatweb)
├── 12 vulnerabilities (via nikto, nuclei)
├── 3 credentials (via various tools)
└── Total: 45 findings across 16 targets

# All discovered automatically in one run!
```

## Workflows

### Web Reconnaissance Workflow

**Quick** (3 steps, ~5 min):
- Technology detection (WhatWeb)
- Vulnerability scan (Nikto)
- SSL/TLS analysis

**Medium** (6 steps, ~15 min):
- All Quick steps
- Directory bruteforce (FFUF)
- Template scanning (Nuclei)
- Subdomain enumeration

**Deep** (10 steps, ~30 min):
- All Medium steps
- JavaScript analysis
- Parameter discovery
- Screenshot capture
- WordPress detection (if applicable)

### Network Sweep Workflow

**Quick** (3 steps, ~5 min):
- Host discovery
- Quick port scan (top 100)
- Service detection

**Medium** (6 steps, ~15 min):
- All Quick steps
- OS detection
- NSE scripts
- Vulnerability scripts

**Deep** (9 steps, ~45 min):
- All Medium steps
- Full port scan (all 65535)
- SMB enumeration
- SNMP enumeration

## Parsers

LeKnight automatically extracts valuable information from tool outputs:

| Tool | Extracted Data |
|------|----------------|
| Nmap | Open ports, services, OS, vulnerabilities |
| Nikto | Web vulnerabilities, misconfigurations |
| Nuclei | Template matches by severity |
| SQLMap | SQL injections, database credentials |
| WPScan | WordPress version, vulnerable plugins, users |
| Subfinder/Amass | Subdomains (auto-added as targets) |
| Hydra | Valid credentials |

## Integration Examples

### Bug Bounty Workflow

```bash
# 1. Create project for target program
Project: "HackerOne - Example Corp"
Scope: *.example.com, example.com

# 2. Start autopilot
Autopilot Mode > Start Autopilot

# 3. Let it run for several hours
# LeKnight will:
#   - Enumerate all subdomains
#   - Scan each subdomain for vulnerabilities
#   - Discover hidden endpoints
#   - Extract sensitive data

# 4. Review critical/high findings
View Results > Critical/High Findings

# 5. Generate professional report
Generate Reports > Markdown Report

# 6. Submit findings to bug bounty program!
```

### Continuous Monitoring

```bash
# Monitor mode runs autopilot on an interval
Autopilot Mode > Monitor Mode
Enter interval: 3600  # Scan every hour

# Perfect for:
#   - Long-term engagements
#   - Asset monitoring
#   - CI/CD security testing
```

## Advanced Usage

### Command Line (for automation)

```bash
# Source the framework
source leknight-v2.sh

# Create project programmatically
project_create "My Project" "Description" "scope here"

# Run autopilot
autopilot_start

# Generate report
generate_markdown_report
```

### Custom Parsers

Add custom parsers in `core/parsers.sh`:

```bash
parse_mytool_output() {
    local output_file="$1"
    local scan_id="$2"
    # Parse your tool's output
    # Extract findings and call db_finding_add
}
```

## Security Considerations

⚠️ **Important**:
- Always obtain **written authorization** before testing any system
- Respect the defined **scope** of your engagement
- LeKnight is for **authorized testing only**
- Be aware of **rate limiting** and aggressive scanning

## Troubleshooting

### Database locked error
```bash
# Check for zombie processes
ps aux | grep leknight

# Reset database connection
rm data/.current_project
```

### Tool not found
```bash
# Check if tool is installed
which nmap

# Install manually
sudo apt-get install nmap
```

### Parsing errors
```bash
# Check logs
Menu > Settings > Log Management > View recent logs

# Search for errors
log_search "ERROR"
```

## Roadmap

- [ ] HTML report generation
- [ ] API REST interface
- [ ] Web dashboard
- [ ] Integration with Metasploit
- [ ] Slack/Discord notifications
- [ ] Docker container
- [ ] Multi-user collaboration
- [ ] Cloud deployment support

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - See LICENSE file

## Credits

**Author**: Mathis BUREAU
**GitHub**: [@MatBureau](https://github.com/MatBureau)

Built with ❤️ for the security community

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history

## Support

- **Issues**: https://github.com/MatBureau/leknight-bash/issues
- **Discussions**: https://github.com/MatBureau/leknight-bash/discussions

---

**Happy Hunting! 🎯⚔️**
