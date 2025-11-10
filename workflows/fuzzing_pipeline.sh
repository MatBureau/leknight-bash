#!/bin/bash

# Advanced Fuzzing Pipeline
# Comprehensive fuzzing with FFUF and result correlation

source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/database.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/wrapper.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/parsers.sh"

# Main fuzzing pipeline
fuzzing_pipeline() {
    local target=$1
    local project_id=$2
    local depth=${3:-"medium"}  # quick, medium, deep

    log_section "Advanced Fuzzing Pipeline"
    log_info "Target: $target"
    log_info "Depth: $depth"

    local output_dir="data/projects/${project_id}/scans/fuzzing"
    mkdir -p "$output_dir"

    # Phase 1: Directory and file fuzzing
    fuzz_directories "$target" "$project_id" "$output_dir" "$depth"

    # Phase 2: Parameter fuzzing
    fuzz_parameters "$target" "$project_id" "$output_dir" "$depth"

    # Phase 3: Virtual host fuzzing
    fuzz_vhosts "$target" "$project_id" "$output_dir" "$depth"

    # Phase 4: Header fuzzing
    fuzz_headers "$target" "$project_id" "$output_dir" "$depth"

    # Phase 5: Extension fuzzing
    fuzz_extensions "$target" "$project_id" "$output_dir" "$depth"

    # Phase 6: API endpoint fuzzing (if API detected)
    if detect_api "$target"; then
        fuzz_api_endpoints "$target" "$project_id" "$output_dir" "$depth"
    fi

    # Parse and correlate all results
    parse_fuzzing_results "$output_dir" "$project_id"

    log_success "Fuzzing pipeline completed"
}

# Directory and file fuzzing
fuzz_directories() {
    local target=$1
    local project_id=$2
    local output_dir=$3
    local depth=$4

    log_info "[Fuzzing] Phase 1: Directory and file enumeration"

    # Select wordlist based on depth
    local wordlist
    case "$depth" in
        "quick")
            wordlist="/usr/share/seclists/Discovery/Web-Content/common.txt"
            ;;
        "medium")
            wordlist="/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt"
            ;;
        "deep")
            wordlist="/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-big.txt"
            ;;
    esac

    # Fallback to local wordlist if SecLists not available
    if [ ! -f "$wordlist" ]; then
        wordlist="data/wordlists/directories.txt"
        create_default_wordlist "$wordlist"
    fi

    # Check if ffuf is installed
    if ! command -v ffuf &> /dev/null; then
        log_warn "[Fuzzing] FFUF not installed, skipping directory fuzzing"
        return 1
    fi

    log_info "[Fuzzing] Using wordlist: $wordlist"

    # Run FFUF for directories
    ffuf -u "${target}/FUZZ" \
         -w "$wordlist" \
         -mc all \
         -fc 404 \
         -t 50 \
         -timeout 10 \
         -rate 100 \
         -recursion \
         -recursion-depth 2 \
         -o "${output_dir}/ffuf_dirs.json" \
         -of json \
         -s \
         2>&1 | tee "${output_dir}/ffuf_dirs.log"

    log_success "[Fuzzing] Directory fuzzing completed"
}

# Parameter fuzzing
fuzz_parameters() {
    local target=$1
    local project_id=$2
    local output_dir=$3
    local depth=$4

    log_info "[Fuzzing] Phase 2: Parameter discovery"

    if ! command -v ffuf &> /dev/null; then
        log_warn "[Fuzzing] FFUF not installed, skipping parameter fuzzing"
        return 1
    fi

    # Parameter wordlist
    local param_wordlist="data/wordlists/parameters.txt"
    if [ ! -f "$param_wordlist" ]; then
        create_parameter_wordlist "$param_wordlist"
    fi

    # Test GET parameters
    log_info "[Fuzzing] Testing GET parameters"
    ffuf -u "${target}?FUZZ=test" \
         -w "$param_wordlist" \
         -mc all \
         -fc 404 \
         -t 30 \
         -timeout 10 \
         -o "${output_dir}/ffuf_params_get.json" \
         -of json \
         -s

    # Test POST parameters (if forms detected)
    log_info "[Fuzzing] Testing POST parameters"
    ffuf -u "$target" \
         -w "$param_wordlist" \
         -X POST \
         -d "FUZZ=test" \
         -H "Content-Type: application/x-www-form-urlencoded" \
         -mc all \
         -fc 404 \
         -t 30 \
         -timeout 10 \
         -o "${output_dir}/ffuf_params_post.json" \
         -of json \
         -s

    log_success "[Fuzzing] Parameter fuzzing completed"
}

# Virtual host fuzzing
fuzz_vhosts() {
    local target=$1
    local project_id=$2
    local output_dir=$3
    local depth=$4

    log_info "[Fuzzing] Phase 3: Virtual host discovery"

    if ! command -v ffuf &> /dev/null; then
        return 1
    fi

    # Extract domain from target
    local domain=$(echo "$target" | grep -oP 'https?://\K[^/]+')

    # VHost wordlist
    local vhost_wordlist="data/wordlists/vhosts.txt"
    if [ ! -f "$vhost_wordlist" ]; then
        create_vhost_wordlist "$vhost_wordlist"
    fi

    # Fuzz Host header
    ffuf -u "$target" \
         -w "$vhost_wordlist" \
         -H "Host: FUZZ.${domain}" \
         -mc all \
         -fc 404 \
         -fs 0 \
         -t 30 \
         -timeout 10 \
         -o "${output_dir}/ffuf_vhosts.json" \
         -of json \
         -s

    log_success "[Fuzzing] VHost fuzzing completed"
}

# Header fuzzing
fuzz_headers() {
    local target=$1
    local project_id=$2
    local output_dir=$3
    local depth=$4

    log_info "[Fuzzing] Phase 4: HTTP header discovery"

    if ! command -v ffuf &> /dev/null; then
        return 1
    fi

    # Header wordlist
    local header_wordlist="data/wordlists/headers.txt"
    if [ ! -f "$header_wordlist" ]; then
        create_header_wordlist "$header_wordlist"
    fi

    # Fuzz headers
    ffuf -u "$target" \
         -w "$header_wordlist" \
         -H "FUZZ: test" \
         -mc all \
         -t 20 \
         -timeout 10 \
         -o "${output_dir}/ffuf_headers.json" \
         -of json \
         -s

    log_success "[Fuzzing] Header fuzzing completed"
}

# Extension fuzzing
fuzz_extensions() {
    local target=$1
    local project_id=$2
    local output_dir=$3
    local depth=$4

    log_info "[Fuzzing] Phase 5: File extension discovery"

    if ! command -v ffuf &> /dev/null; then
        return 1
    fi

    # Common extensions
    local extensions=("php" "asp" "aspx" "jsp" "bak" "old" "txt" "conf" "config" "sql" "db" "log" "zip" "tar.gz" "json" "xml" "env" "git" "swp" "~")

    # Create extension wordlist
    local ext_wordlist="${output_dir}/extensions.txt"
    printf '%s\n' "${extensions[@]}" > "$ext_wordlist"

    # Fuzz extensions
    ffuf -u "${target}/indexFUZZ" \
         -w "$ext_wordlist" \
         -mc all \
         -fc 404 \
         -t 30 \
         -timeout 10 \
         -o "${output_dir}/ffuf_extensions.json" \
         -of json \
         -s

    log_success "[Fuzzing] Extension fuzzing completed"
}

# API endpoint fuzzing
fuzz_api_endpoints() {
    local target=$1
    local project_id=$2
    local output_dir=$3
    local depth=$4

    log_info "[Fuzzing] Phase 6: API endpoint discovery"

    if ! command -v ffuf &> /dev/null; then
        return 1
    fi

    # API wordlist
    local api_wordlist="data/wordlists/api_endpoints.txt"
    if [ ! -f "$api_wordlist" ]; then
        create_api_wordlist "$api_wordlist"
    fi

    # Common API paths
    local api_bases=("/api" "/v1" "/v2" "/rest" "/graphql")

    for base in "${api_bases[@]}"; do
        ffuf -u "${target}${base}/FUZZ" \
             -w "$api_wordlist" \
             -mc all \
             -fc 404 \
             -t 30 \
             -timeout 10 \
             -o "${output_dir}/ffuf_api_${base//\//_}.json" \
             -of json \
             -s
    done

    log_success "[Fuzzing] API fuzzing completed"
}

# Detect if target is an API
detect_api() {
    local target=$1

    local response=$(curl -s -I "$target" 2>/dev/null)

    # Check for API indicators
    if echo "$response" | grep -qiE "application/json|application/xml|rest|graphql|swagger"; then
        return 0
    fi

    # Check URL patterns
    if echo "$target" | grep -qiE "/api/|/v[0-9]+/|/rest/|/graphql"; then
        return 0
    fi

    return 1
}

# Parse fuzzing results and add to database
parse_fuzzing_results() {
    local output_dir=$1
    local project_id=$2

    log_info "[Fuzzing] Parsing results and adding to database"

    local total_found=0

    # Parse each JSON output file
    for json_file in "$output_dir"/ffuf_*.json; do
        if [ ! -f "$json_file" ]; then
            continue
        fi

        log_debug "[Fuzzing] Parsing: $json_file"

        # Extract results using jq if available
        if command -v jq &> /dev/null; then
            local results=$(jq -r '.results[] | "\(.url)|\(.status)|\(.length)|\(.words)"' "$json_file" 2>/dev/null)

            while IFS='|' read -r url status length words; do
                [ -z "$url" ] && continue

                # Skip if already in database
                local exists=$(db_execute "SELECT COUNT(*) FROM targets WHERE url='$url' AND project_id=$project_id" 2>/dev/null | tail -1)
                # Default to 0 if empty
                exists="${exists:-0}"
                [ "$exists" -gt 0 ] && continue

                # Determine tag based on status and characteristics
                local tag="fuzzed_endpoint"
                local priority=3

                # High-value endpoints
                if echo "$url" | grep -qiE "admin|login|auth|api|upload|backup|config|\.env|\.git|\.sql|debug"; then
                    tag="high_value_endpoint"
                    priority=1
                elif [ "$status" = "200" ] || [ "$status" = "301" ] || [ "$status" = "302" ]; then
                    priority=2
                fi

                # Add to targets table
                db_execute "INSERT OR IGNORE INTO targets (project_id, url, http_status, tag, autopilot_status, priority) \
                            VALUES ($project_id, '$url', $status, '$tag', 'pending', $priority)" 2>/dev/null

                total_found=$((total_found + 1))

                # Log interesting findings
                if [ "$priority" = "1" ]; then
                    log_success "[Fuzzing] High-value endpoint found: $url (HTTP $status)"
                fi
            done <<< "$results"
        fi
    done

    log_success "[Fuzzing] Found $total_found new endpoints"

    # Generate fuzzing summary
    generate_fuzzing_summary "$output_dir" "$project_id"
}

# Generate fuzzing summary
generate_fuzzing_summary() {
    local output_dir=$1
    local project_id=$2

    local summary_file="${output_dir}/fuzzing_summary.txt"

    cat > "$summary_file" <<EOF
===========================================
Advanced Fuzzing Pipeline - Summary
===========================================
Date: $(date)
Project ID: $project_id

EOF

    # Count results from each phase
    for json_file in "$output_dir"/ffuf_*.json; do
        if [ -f "$json_file" ] && command -v jq &> /dev/null; then
            local phase=$(basename "$json_file" .json | sed 's/ffuf_//')
            local count=$(jq '.results | length' "$json_file" 2>/dev/null || echo "0")

            echo "Phase: $phase - $count results" >> "$summary_file"
        fi
    done

    cat >> "$summary_file" <<EOF

High-Value Endpoints:
EOF

    # List high-value endpoints
    db_execute "SELECT url, http_status FROM targets WHERE project_id=$project_id AND tag='high_value_endpoint'" 2>/dev/null | \
        while read -r url status; do
            echo "  - $url (HTTP $status)" >> "$summary_file"
        done

    log_info "[Fuzzing] Summary saved to: $summary_file"
}

# Create default wordlists if not present
create_default_wordlist() {
    local file=$1
    mkdir -p "$(dirname "$file")"

    cat > "$file" <<'EOF'
admin
api
backup
config
dashboard
debug
login
test
upload
user
users
api/v1
api/v2
.git
.env
.htaccess
.DS_Store
robots.txt
sitemap.xml
EOF
}

create_parameter_wordlist() {
    local file=$1
    mkdir -p "$(dirname "$file")"

    cat > "$file" <<'EOF'
id
page
search
q
query
user
username
email
password
token
redirect
url
callback
debug
test
admin
file
path
dir
name
action
method
EOF
}

create_vhost_wordlist() {
    local file=$1
    mkdir -p "$(dirname "$file")"

    cat > "$file" <<'EOF'
www
mail
ftp
admin
test
dev
stage
staging
api
app
portal
secure
vpn
remote
blog
shop
forum
support
help
docs
cdn
media
static
assets
EOF
}

create_header_wordlist() {
    local file=$1
    mkdir -p "$(dirname "$file")"

    cat > "$file" <<'EOF'
X-Forwarded-For
X-Forwarded-Host
X-Original-URL
X-Rewrite-URL
X-Custom-IP-Authorization
X-Originating-IP
X-Remote-IP
X-Remote-Addr
X-Client-IP
X-Real-IP
True-Client-IP
Cluster-Client-IP
Via
Forwarded
X-Override-URL
X-HTTP-DestinationURL
X-HTTP-Host-Override
EOF
}

create_api_wordlist() {
    local file=$1
    mkdir -p "$(dirname "$file")"

    cat > "$file" <<'EOF'
users
user
admin
auth
login
logout
register
profile
account
settings
config
status
health
version
endpoints
swagger
graphql
docs
documentation
v1
v2
api
data
items
products
orders
payments
notifications
messages
search
export
import
upload
download
EOF
}

# Export functions
export -f fuzzing_pipeline
export -f fuzz_directories
export -f fuzz_parameters
export -f parse_fuzzing_results
