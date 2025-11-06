#!/bin/bash

# burp_suite.sh - Burp Suite integration scripts
# Bidirectional integration: import scope from Burp, export findings to Burp

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEKNIGHT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load LeKnight core if not already loaded
if [ -z "$DB_PATH" ]; then
    source "${LEKNIGHT_ROOT}/core/logger.sh"
    source "${LEKNIGHT_ROOT}/core/database.sh"
    source "${LEKNIGHT_ROOT}/core/project.sh"
fi

# Import scope from Burp Suite JSON export
burp_import_scope() {
    local burp_scope_file="$1"
    local project_id="$2"

    if [ ! -f "$burp_scope_file" ]; then
        echo "Usage: $0 <burp_scope.json> <project_id>"
        echo
        echo "To export scope from Burp Suite:"
        echo "  1. Target tab > Scope"
        echo "  2. Right-click > Save"
        exit 1
    fi

    if [ -z "$project_id" ]; then
        echo "Error: Project ID required"
        exit 1
    fi

    echo "🎯 Importing Burp Suite scope..."

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required for JSON parsing"
        echo "Install with: sudo apt-get install jq"
        exit 1
    fi

    local count=0

    # Parse Burp scope JSON and extract hosts
    jq -r '.target.scope.include[] | select(.enabled==true) | .host' "$burp_scope_file" 2>/dev/null | \
    while read -r target; do
        if [ -n "$target" ]; then
            echo "  Adding target: $target"

            # Add to LeKnight project using the function from project.sh
            project_add_target "$project_id" "$target"
            ((count++))
        fi
    done

    echo
    echo "✅ Scope imported successfully: $count targets added"
}

# Export LeKnight findings to Burp Suite XML
burp_export_findings() {
    local project_id="$1"
    local output_file="${2:-burp_import_${project_id}.xml}"

    if [ -z "$project_id" ]; then
        echo "Usage: $0 <project_id> [output_file]"
        exit 1
    fi

    echo "📤 Exporting findings to Burp Suite XML..."

    # Use the export function from export_json.sh if available
    if type export_burp_xml &>/dev/null; then
        export_burp_xml "$project_id" "$output_file"
    else
        # Inline implementation
        cat > "$output_file" <<'XMLHEADER'
<?xml version="1.0"?>
<!DOCTYPE issues [
  <!ELEMENT issues (issue*)>
  <!ELEMENT issue (serialNumber, type, name, host, path, location, severity, confidence, issueBackground?, issueDetail?)>
]>
<issues burpVersion="2023.11">
XMLHEADER

        # Export findings as XML issues
        sqlite3 "$DB_PATH" <<EOF | while IFS='|' read -r id title severity description hostname ip; do
SELECT
    f.id,
    f.title,
    f.severity,
    f.description,
    COALESCE(t.hostname, 'unknown'),
    COALESCE(t.ip, '0.0.0.0')
FROM findings f
LEFT JOIN targets t ON t.id = f.target_id
WHERE f.project_id = $project_id
AND f.severity IN ('critical', 'high', 'medium');
EOF

            # Map severity
            local burp_severity="Information"
            case "$severity" in
                critical|high) burp_severity="High" ;;
                medium) burp_severity="Medium" ;;
                low) burp_severity="Low" ;;
            esac

            # Escape XML entities
            title=$(echo "$title" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            description=$(echo "$description" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            hostname=$(echo "$hostname" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

            cat >> "$output_file" <<XMLISSUE
  <issue>
    <serialNumber>$id</serialNumber>
    <type>0x$(printf '%08x' $id)</type>
    <name>$title</name>
    <host>$hostname</host>
    <path>/</path>
    <location>$hostname</location>
    <severity>$burp_severity</severity>
    <confidence>Certain</confidence>
    <issueBackground>LeKnight Autopilot Finding</issueBackground>
    <issueDetail>$description</issueDetail>
  </issue>
XMLISSUE
        done

        echo "</issues>" >> "$output_file"
    fi

    echo "✅ Export complete: $output_file"
    echo
    echo "📋 To import in Burp Suite:"
    echo "  1. Target tab > Site map"
    echo "  2. Right-click on target > Import"
    echo "  3. Select: $output_file"
}

# Interactive menu
if [ "$#" -eq 0 ]; then
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║        LeKnight ↔️ Burp Suite Integration             ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo
    echo "Usage:"
    echo "  $0 import-scope <burp_scope.json> <project_id>"
    echo "  $0 export-findings <project_id> [output_file]"
    echo
    echo "Examples:"
    echo "  # Import Burp scope to LeKnight project 1"
    echo "  $0 import-scope burp_scope.json 1"
    echo
    echo "  # Export LeKnight findings to Burp"
    echo "  $0 export-findings 1 findings.xml"
    echo
    exit 0
fi

# Handle commands
case "$1" in
    import-scope)
        burp_import_scope "$2" "$3"
        ;;
    export-findings)
        burp_export_findings "$2" "$3"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run without arguments for help"
        exit 1
        ;;
esac
