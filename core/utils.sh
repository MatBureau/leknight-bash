#!/bin/bash

# utils.sh - Common utility functions for LeKnight
# Provides validation, formatting, and helper functions

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check and install tool if missing
check_and_install_tool() {
    local tool_name="$1"
    local install_command="$2"
    local silent="${3:-false}"

    if ! command_exists "$tool_name"; then
        if [ "$silent" = "false" ]; then
            log_warning "$tool_name is not installed"
            read -rp "Install $tool_name? (y/n): " install_choice
        else
            install_choice="y"
        fi

        if [[ $install_choice =~ ^[Yy] ]]; then
            log_info "Installing $tool_name..."
            eval "$install_command"

            if command_exists "$tool_name"; then
                log_success "$tool_name installed successfully"
                return 0
            else
                log_error "Failed to install $tool_name"
                return 1
            fi
        else
            log_info "Installation cancelled"
            return 1
        fi
    fi
    return 0
}

# Validate IP address
is_valid_ip() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if [[ $ip =~ $regex ]]; then
        for octet in ${ip//./ }; do
            if [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Validate domain name
is_valid_domain() {
    local domain="$1"
    local regex='^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
    [[ $domain =~ $regex ]]
}

# Validate URL
is_valid_url() {
    local url="$1"
    local regex='^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$'
    [[ $url =~ $regex ]]
}

# Validate port number
is_valid_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

# Validate command for dangerous patterns
validate_command() {
    local cmd="$1"

    # Blacklist of dangerous patterns
    local dangerous_patterns=(
        ';.*rm -rf'           # Command chaining with rm -rf
        '\|\|.*rm'            # OR with rm
        '&&.*rm -rf'          # AND with rm -rf
        '`.*rm.*`'            # Backticks with rm
        '\$\(.*rm -rf.*\)'    # Command substitution with rm -rf
        '>/dev/sd'            # Write to disk device
        'dd if='              # Disk copy
        'mkfs'                # Format filesystem
        ':(){:|:&};:'         # Fork bomb
        'chmod -R 777'        # Dangerous permissions
        '>/etc/'              # Write to system config
        'curl.*\|.*bash'      # Pipe download to bash
        'wget.*\|.*sh'        # Pipe download to sh
    )

    for pattern in "${dangerous_patterns[@]}"; do
        if echo "$cmd" | grep -qE "$pattern"; then
            log_error "Dangerous pattern detected in command: $pattern"
            log_debug "Blocked command: $cmd"
            return 1
        fi
    done

    return 0
}

# Extract hostname from URL
extract_hostname() {
    local url="$1"
    echo "$url" | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:.*$||'
}

# Extract protocol from URL
extract_protocol() {
    local url="$1"
    if [[ $url =~ ^https:// ]]; then
        echo "https"
    elif [[ $url =~ ^http:// ]]; then
        echo "http"
    else
        echo ""
    fi
}

# Extract port from URL
extract_port() {
    local url="$1"
    if [[ $url =~ :([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ $url =~ ^https:// ]]; then
        echo "443"
    else
        echo "80"
    fi
}

# Format timestamp
format_timestamp() {
    local timestamp="$1"
    date -d "$timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S'
}

# Calculate duration between timestamps
calculate_duration() {
    local start="$1"
    local end="$2"
    local start_seconds=$(date -d "$start" +%s 2>/dev/null || date +%s)
    local end_seconds=$(date -d "$end" +%s 2>/dev/null || date +%s)
    echo $((end_seconds - start_seconds))
}

# Format file size
format_size() {
    local size="$1"
    if [ "$size" -lt 1024 ]; then
        echo "${size}B"
    elif [ "$size" -lt 1048576 ]; then
        echo "$((size / 1024))KB"
    elif [ "$size" -lt 1073741824 ]; then
        echo "$((size / 1048576))MB"
    else
        echo "$((size / 1073741824))GB"
    fi
}

# Generate random string
generate_random_string() {
    local length="${1:-16}"
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# Sanitize input for SQL
sanitize_sql() {
    local input="$1"
    echo "$input" | sed "s/'/''/g"
}

# Sanitize filename
sanitize_filename() {
    local filename="$1"
    echo "$filename" | tr -d '\000-\037' | tr '/' '_' | tr ' ' '_'
}

# Create output directory
create_output_dir() {
    local project_id="$1"
    local tool="$2"
    local output_dir="${LEKNIGHT_ROOT}/data/scans/${project_id}/${tool}"

    mkdir -p "$output_dir"
    echo "$output_dir"
}

# Get output filename
get_output_filename() {
    local project_id="$1"
    local tool="$2"
    local target="$3"
    local extension="${4:-.txt}"

    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local sanitized_target=$(sanitize_filename "$target")
    local output_dir=$(create_output_dir "$project_id" "$tool")

    echo "${output_dir}/${tool}_${sanitized_target}_${timestamp}${extension}"
}

# Parse CIDR notation
parse_cidr() {
    local cidr="$1"
    if [[ $cidr =~ ^([0-9\.]+)/([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    else
        echo "$cidr" "32"
    fi
}

# Check if target is in scope
is_in_scope() {
    local target="$1"
    local scope="$2"

    # If scope is empty, everything is in scope
    [ -z "$scope" ] && return 0

    # Check each scope entry
    while IFS= read -r scope_entry; do
        [[ -z "$scope_entry" ]] && continue

        # Exact match
        if [ "$target" = "$scope_entry" ]; then
            return 0
        fi

        # Wildcard domain match (*.example.com)
        if [[ $scope_entry =~ ^\*\. ]]; then
            local domain="${scope_entry#\*.}"
            if [[ $target == *"$domain" ]]; then
                return 0
            fi
        fi

        # CIDR match
        if [[ $scope_entry =~ / ]] && is_valid_ip "$target"; then
            if ip_in_cidr "$target" "$scope_entry"; then
                return 0
            fi
        fi
    done <<< "$scope"

    return 1
}

# Check if IP is in CIDR range
ip_in_cidr() {
    local ip="$1"
    local cidr="$2"

    # Convert IP to integer
    IFS=. read -r i1 i2 i3 i4 <<< "$ip"
    local ip_int=$((i1 * 256**3 + i2 * 256**2 + i3 * 256 + i4))

    # Parse CIDR
    IFS=/ read -r network mask <<< "$cidr"
    IFS=. read -r n1 n2 n3 n4 <<< "$network"
    local net_int=$((n1 * 256**3 + n2 * 256**2 + n3 * 256 + n4))

    # Calculate network mask
    local mask_int=$(( (0xFFFFFFFF << (32 - mask)) & 0xFFFFFFFF ))

    # Check if IP is in range
    [ $((ip_int & mask_int)) -eq $((net_int & mask_int)) ]
}

# Confirm action
confirm() {
    local message="$1"
    local default="${2:-n}"

    if [ "$default" = "y" ]; then
        read -rp "$message (Y/n): " response
        response="${response:-y}"
    else
        read -rp "$message (y/N): " response
        response="${response:-n}"
    fi

    [[ $response =~ ^[Yy] ]]
}

# Wait for user input
press_enter() {
    local message="${1:-Press Enter to continue...}"
    read -rp "$message"
}

# Display a menu and get selection
display_menu() {
    local title="$1"
    shift
    local options=("$@")

    echo
    echo -e "${BRIGHT_RED}╔═══════════════════════════════════════════════════╗${RESET}"
    echo -e "${BRIGHT_RED}║${RESET}  ${BRIGHT_BLUE}${title}${RESET}"
    echo -e "${BRIGHT_RED}╚═══════════════════════════════════════════════════╝${RESET}"
    echo

    for i in "${!options[@]}"; do
        local num=$((i + 1))
        echo -e "  ${RED}[$num]${RESET} ${BRIGHT_BLUE}${options[$i]}${RESET}"
    done

    echo
}

# Get user selection
get_selection() {
    local prompt="${1:-Select option}"
    local max="${2:-99}"

    while true; do
        read -rp "${BRIGHT_BLUE}$prompt${RESET}${BRIGHT_RED} \$${RESET} " selection

        if [[ $selection =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$max" ]; then
            echo "$selection"
            return 0
        else
            log_error "Invalid selection. Please enter a number between 1 and $max"
        fi
    done
}

# Create a spinner for long operations
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p "$pid" > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Execute command with timeout
execute_with_timeout() {
    local timeout="$1"
    shift
    local command="$@"

    timeout "$timeout" bash -c "$command"
    return $?
}

# Parallel execution helper
run_parallel() {
    local max_jobs="${1:-5}"
    shift
    local commands=("$@")

    local job_count=0
    for cmd in "${commands[@]}"; do
        # Wait if we've reached max parallel jobs
        while [ "$(jobs -r | wc -l)" -ge "$max_jobs" ]; do
            sleep 0.1
        done

        # Run command in background
        eval "$cmd" &
        ((job_count++))
    done

    # Wait for all jobs to complete
    wait
}

# Check if running as root
is_root() {
    [ "$(id -u)" -eq 0 ]
}

# Check if running in docker
is_docker() {
    [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null
}

# Get system info
get_system_info() {
    echo "OS: $(uname -s)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
}

# Check disk space
check_disk_space() {
    local path="${1:-.}"
    local required_mb="${2:-100}"

    local available_mb=$(df -m "$path" | awk 'NR==2 {print $4}')

    if [ "$available_mb" -lt "$required_mb" ]; then
        log_warning "Low disk space: ${available_mb}MB available, ${required_mb}MB required"
        return 1
    fi
    return 0
}

# Create backup
create_backup() {
    local file="$1"
    local backup_dir="${LEKNIGHT_ROOT}/data/backups"

    mkdir -p "$backup_dir"

    if [ -f "$file" ]; then
        local timestamp=$(date '+%Y%m%d_%H%M%S')
        local basename=$(basename "$file")
        local backup_file="${backup_dir}/${basename}.${timestamp}.bak"

        cp "$file" "$backup_file"
        log_info "Backup created: $backup_file"
        echo "$backup_file"
    fi
}

# Cleanup temporary files
cleanup_temp() {
    local temp_dir="${LEKNIGHT_ROOT}/data/temp"
    if [ -d "$temp_dir" ]; then
        rm -rf "${temp_dir:?}"/*
        log_info "Temporary files cleaned"
    fi
}
