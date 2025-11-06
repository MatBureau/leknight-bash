# Changelog

All notable changes to LeKnight will be documented in this file.

## [2.0.0] - 2025-01-15

### 🚀 Major Rewrite

Complete rewrite of LeKnight from a simple tool launcher to a professional-grade autonomous pentesting framework.

### ✨ Added

#### Core Features
- **Project Management System**
  - Multi-project support with isolated workspaces
  - Scope definition and validation
  - Project dashboard with real-time statistics
  - Project import/export functionality

- **SQLite Database Backend**
  - Persistent storage of all scan results
  - Structured schema for projects, targets, scans, findings, and credentials
  - Automatic data correlation and deduplication
  - Database backup and cleanup utilities

- **Advanced Logging System**
  - Multi-level logging (DEBUG, INFO, SUCCESS, WARNING, ERROR, CRITICAL)
  - Colored console output
  - File-based logging with timestamps
  - Log search, export, and rotation

- **Tool Execution Wrapper**
  - Automatic output capture
  - Real-time parsing of results
  - Error handling and retry logic
  - Scan history tracking

#### Autonomous Features
- **Autopilot Mode**
  - Fully autonomous scanning engine
  - Intelligent target analysis (IP/domain/URL detection)
  - Adaptive workflow selection
  - Recursive target discovery
  - Continuous monitoring mode
  - High-value target rescanning

- **Smart Parsers**
  - Nmap: Extracts ports, services, OS, vulnerabilities
  - Nikto: Parses web vulnerabilities
  - Nuclei: Extracts template matches by severity
  - SQLMap: Detects injections and extracts credentials
  - WPScan: WordPress vulnerabilities and users
  - Subfinder/Amass: Automatic subdomain addition
  - Hydra: Valid credential extraction
  - Generic parsers: IP, domain, email, credential extraction

#### Workflows
- **Web Reconnaissance Workflow**
  - Three depth levels: Quick, Medium, Deep
  - Technology detection (WhatWeb)
  - Vulnerability scanning (Nikto, Nuclei)
  - Directory bruteforce (FFUF)
  - SSL/TLS analysis
  - Subdomain enumeration
  - WordPress detection
  - Screenshot capture

- **Network Sweep Workflow**
  - Three depth levels: Quick, Medium, Deep
  - Host discovery
  - Port scanning (quick/full)
  - Service detection
  - OS fingerprinting
  - NSE vulnerability scripts
  - SMB enumeration
  - SNMP enumeration

#### Reporting
- **Markdown Report Generation**
  - Executive summary
  - Findings by severity
  - Target inventory
  - Discovered credentials
  - Scan history
  - Methodology section

- **CSV Export**
  - Findings export for spreadsheet analysis

- **JSON Export**
  - Complete project data export
  - Integration with external tools

#### User Interface
- **Improved Navigation**
  - Hierarchical menu system
  - Context-aware options
  - Current project display
  - Real-time status updates

- **Settings Management**
  - System information viewer
  - Tool availability checker
  - Database maintenance
  - Log management
  - Backup utilities

### 🔧 Fixed

- Fixed `$(whoami)` variable misuse throughout codebase
- Added proper input validation for all user inputs
- Improved error handling with graceful failures
- Fixed menu navigation issues
- Removed premature `return` statements blocking tool chaining

### 🎨 Changed

#### Architecture
- **Modular Design**
  - Core modules (database, logger, utils, project, wrapper, parsers)
  - Workflow modules (web_recon, network_sweep, autopilot)
  - Report modules (generate_md)
  - Clear separation of concerns

- **File Organization**
  ```
  Old: Single 1683-line script
  New: Modular structure with dedicated directories
       - core/
       - workflows/
       - reports/
       - data/
  ```

- **Data Storage**
  ```
  Old: No persistence, results lost after execution
  New: SQLite database with full scan history
  ```

#### User Experience
- **From Tool Launcher to Framework**
  - Old: Simple menu to launch tools individually
  - New: Complete project lifecycle management

- **Result Management**
  - Old: No result storage
  - New: Automatic parsing, classification, and storage

- **Workflow Execution**
  - Old: One tool at a time, manual progression
  - New: Automated workflows with intelligent chaining

### 🗑️ Removed

- Removed hardcoded tool lists in favor of dynamic detection
- Removed redundant menu options
- Removed non-functional placeholder code

### 📚 Documentation

- Complete README rewrite with:
  - Installation guide
  - Quick start tutorial
  - Architecture documentation
  - Workflow descriptions
  - Integration examples
  - Troubleshooting section

- Added comprehensive inline comments
- Created setup script with guided installation

### 🔒 Security

- Added scope validation to prevent out-of-scope testing
- Input sanitization for SQL injection prevention
- Credential masking in reports
- Authorization warnings before exploit mode

## [1.0.0] - 2024-XX-XX

### Initial Release

- Basic tool launcher interface
- 6 categories of tools:
  - Network Reconnaissance
  - Vulnerability Scanning
  - Exploitation Framework
  - Post-Exploitation
  - Credential Harvesting
  - Payload Generator
- ~50 integrated tools
- Medieval-themed ASCII art
- Automatic tool installation
- Color-coded interface

---

## Migration Guide (v1 to v2)

### For Users

LeKnight v2.0 is a complete rewrite. To migrate:

1. **Backup your v1 data** (if any)
2. **Run the new setup**: `./setup.sh`
3. **Create new projects** in v2
4. **Define your scope** (v2 requires scope definition)
5. **Use Autopilot** for automated scanning

### Key Differences

| Feature | v1 | v2 |
|---------|----|----|
| Tool execution | Manual, one-by-one | Automated workflows |
| Result storage | None | SQLite database |
| Project management | None | Full project support |
| Reporting | None | Markdown, CSV, JSON |
| Autonomous mode | None | Autopilot engine |
| Target discovery | Manual | Automatic |
| Parsing | None | Automatic for all tools |

### Breaking Changes

- CLI interface completely redesigned
- All functionality requires project context
- Direct tool execution requires project to be loaded
- No backward compatibility with v1 data format

## Upcoming Features

See README.md Roadmap section for planned features.

---

**Note**: Semantic versioning is used. Major version indicates breaking changes, minor version indicates new features, patch version indicates bug fixes.
