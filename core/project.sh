#!/bin/bash

# project.sh - Project management for LeKnight
# Handles project creation, loading, and context management

# Current project file
CURRENT_PROJECT_FILE="${LEKNIGHT_ROOT}/data/.current_project"

# Get current project ID
get_current_project() {
    if [ -f "$CURRENT_PROJECT_FILE" ]; then
        cat "$CURRENT_PROJECT_FILE"
    else
        echo ""
    fi
}

# Set current project
set_current_project() {
    local project_id="$1"
    echo "$project_id" > "$CURRENT_PROJECT_FILE"
    export CURRENT_PROJECT_ID="$project_id"
}

# Clear current project
clear_current_project() {
    rm -f "$CURRENT_PROJECT_FILE"
    unset CURRENT_PROJECT_ID
}

# Create new project
project_create() {
    local name="$1"
    local description="$2"
    local scope="$3"
    local user_agent="$4"

    # Validate project name
    if [ -z "$name" ]; then
        log_error "Project name is required"
        return 1
    fi

    # Check if project already exists
    local existing_id=$(db_project_get_by_name "$name")
    if [ -n "$existing_id" ]; then
        log_error "Project '$name' already exists with ID: $existing_id"
        return 1
    fi

    # Create project in database
    log_info "Creating project: $name"
    local project_id=$(db_project_create "$name" "$description" "$scope" "$user_agent")

    if [ -n "$project_id" ]; then
        log_success "Project created with ID: $project_id"

        # Display User-Agent info if custom
        if [ -n "$user_agent" ]; then
            log_info "Custom User-Agent configured: $user_agent"
        fi

        # Create project directory structure
        local project_dir="${LEKNIGHT_ROOT}/data/projects/${project_id}"
        mkdir -p "$project_dir"/{scans,findings,credentials,reports,notes,evidence,exploits}

        # Create project metadata file
        cat > "${project_dir}/metadata.txt" <<EOF
Project ID: $project_id
Name: $name
Description: $description
Scope: $scope
User-Agent: ${user_agent:-Default}
Created: $(date '+%Y-%m-%d %H:%M:%S')
EOF

        # Set as current project
        set_current_project "$project_id"
        log_success "Project '$name' is now active"

        echo "$project_id"
        return 0
    else
        log_error "Failed to create project"
        return 1
    fi
}

# Create project interactively
project_create_interactive() {
    echo
    log_section "CREATE NEW PROJECT"

    read -rp "${BRIGHT_BLUE}Project Name:${RESET} " name
    read -rp "${BRIGHT_BLUE}Description:${RESET} " description

    echo
    echo "Define project scope (press Enter on empty line to finish):"
    echo "Examples: example.com, *.example.com, 192.168.1.0/24"
    echo

    local scope=""
    while true; do
        read -rp "${BRIGHT_BLUE}Scope entry:${RESET} " scope_entry
        [ -z "$scope_entry" ] && break
        scope="${scope}${scope_entry}"$'\n'
    done

    echo
    echo -e "${BRIGHT_YELLOW}Bug Bounty User-Agent Configuration (Optional)${RESET}"
    echo "Some bug bounty programs require a specific User-Agent header."
    echo "Example: 'Mozilla/5.0 -BugBounty-memento-31337'"
    echo "Leave empty for default User-Agent."
    echo
    read -rp "${BRIGHT_BLUE}Custom User-Agent:${RESET} " user_agent

    echo
    if confirm "Create project '$name'?" "y"; then
        project_create "$name" "$description" "$scope" "$user_agent"
    else
        log_info "Project creation cancelled"
    fi
}

# List all projects
project_list() {
    log_section "PROJECTS"
    db_project_list

    local current_id=$(get_current_project)
    if [ -n "$current_id" ]; then
        echo
        echo -e "${BRIGHT_BLUE}Current project:${RESET} $current_id"
    fi
}

# Load/switch project
project_load() {
    local identifier="$1"

    # Try to find project by ID or name
    local project_id=""

    if [[ $identifier =~ ^[0-9]+$ ]]; then
        # It's an ID
        project_id="$identifier"
    else
        # It's a name
        project_id=$(db_project_get_by_name "$identifier")
    fi

    if [ -z "$project_id" ]; then
        log_error "Project not found: $identifier"
        return 1
    fi

    # Verify project exists
    local project_info=$(db_project_get "$project_id")
    if [ -z "$project_info" ]; then
        log_error "Project ID $project_id not found in database"
        return 1
    fi

    # Set as current project
    set_current_project "$project_id"
    log_success "Loaded project ID: $project_id"

    # Show project info
    project_info "$project_id"

    return 0
}

# Load project interactively
project_load_interactive() {
    log_section "SELECT PROJECT"

    db_project_list

    echo
    read -rp "${BRIGHT_BLUE}Enter project ID or name:${RESET} " identifier

    if [ -n "$identifier" ]; then
        project_load "$identifier"
    else
        log_info "No project selected"
    fi
}

# Show project information
project_info() {
    local project_id="${1:-$(get_current_project)}"

    if [ -z "$project_id" ]; then
        log_error "No project specified or loaded"
        return 1
    fi

    echo
    echo -e "${BRIGHT_RED}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BRIGHT_RED}║${RESET}  ${BRIGHT_BLUE}PROJECT INFORMATION${RESET}"
    echo -e "${BRIGHT_RED}╚════════════════════════════════════════════════════════╝${RESET}"
    echo

    # Get project details
    db_project_get "$project_id"

    echo
    echo -e "${BRIGHT_BLUE}Statistics:${RESET}"
    db_project_stats "$project_id"

    echo
}

# Show project dashboard
project_dashboard() {
    local project_id="${1:-$(get_current_project)}"

    if [ -z "$project_id" ]; then
        log_error "No project loaded. Use 'project load <id>' first"
        return 1
    fi

    clear
    echo -e "${BRIGHT_RED}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              ⚔️  LEKNIGHT DASHBOARD  ⚔️                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    # Get project info
    local project_name=$(sqlite3 "$DB_PATH" "SELECT name FROM projects WHERE id = $project_id;")
    local created_at=$(sqlite3 "$DB_PATH" "SELECT created_at FROM projects WHERE id = $project_id;")

    echo -e "${BRIGHT_BLUE}Project:${RESET} $project_name ${GRAY}(ID: $project_id)${RESET}"
    echo -e "${BRIGHT_BLUE}Created:${RESET} $created_at"
    echo

    # Get statistics
    local target_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM targets WHERE project_id = $project_id;")
    local scan_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM scans WHERE project_id = $project_id;")
    local finding_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM findings WHERE project_id = $project_id;")
    local cred_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM credentials WHERE project_id = $project_id;")

    echo -e "${BRIGHT_BLUE}📊 STATISTICS${RESET}"
    echo -e "├─ Targets scanned: ${BRIGHT_RED}$target_count${RESET}"
    echo -e "├─ Total scans: ${BRIGHT_RED}$scan_count${RESET}"
    echo -e "├─ Findings: ${BRIGHT_RED}$finding_count${RESET}"
    echo -e "└─ Credentials: ${BRIGHT_RED}$cred_count${RESET}"
    echo

    # Get findings by severity
    local findings_stats=$(db_finding_stats "$project_id")
    local critical=$(echo "$findings_stats" | awk '{print $1}')
    local high=$(echo "$findings_stats" | awk '{print $2}')
    local medium=$(echo "$findings_stats" | awk '{print $3}')
    local low=$(echo "$findings_stats" | awk '{print $4}')
    local info=$(echo "$findings_stats" | awk '{print $5}')

    echo -e "${BRIGHT_BLUE}🎯 FINDINGS BY SEVERITY${RESET}"
    echo -e "├─ ${BRIGHT_RED}Critical:${RESET} $critical"
    echo -e "├─ ${RED}High:${RESET} $high"
    echo -e "├─ ${YELLOW}Medium:${RESET} $medium"
    echo -e "├─ ${BLUE}Low:${RESET} $low"
    echo -e "└─ ${GRAY}Info:${RESET} $info"
    echo

    # Recent activity
    echo -e "${BRIGHT_BLUE}📜 RECENT ACTIVITY${RESET}"
    db_scan_get_recent "$project_id" 5
    echo

    # Recent findings
    if [ "$finding_count" -gt 0 ]; then
        echo -e "${BRIGHT_BLUE}🔍 RECENT FINDINGS${RESET}"
        sqlite3 -column "$DB_PATH" <<EOF
SELECT severity, title, created_at
FROM findings
WHERE project_id = $project_id
ORDER BY created_at DESC
LIMIT 5;
EOF
        echo
    fi
}

# Delete project
project_delete() {
    local project_id="$1"

    if [ -z "$project_id" ]; then
        log_error "Project ID required"
        return 1
    fi

    # Get project name
    local project_name=$(sqlite3 "$DB_PATH" "SELECT name FROM projects WHERE id = $project_id;")

    if [ -z "$project_name" ]; then
        log_error "Project not found: $project_id"
        return 1
    fi

    echo
    log_warning "This will permanently delete project: $project_name (ID: $project_id)"
    log_warning "All data including scans, findings, and credentials will be lost!"
    echo

    if confirm "Are you sure you want to delete this project?" "n"; then
        # Delete from database (cascades to all related data)
        db_project_delete "$project_id"

        # Delete project directory
        local project_dir="${LEKNIGHT_ROOT}/data/projects/${project_id}"
        if [ -d "$project_dir" ]; then
            rm -rf "$project_dir"
        fi

        # Clear current project if it's the deleted one
        if [ "$(get_current_project)" = "$project_id" ]; then
            clear_current_project
        fi

        log_success "Project deleted: $project_name"
    else
        log_info "Deletion cancelled"
    fi
}

# Add target to project
project_add_target() {
    local project_id="${1:-$(get_current_project)}"
    local target="$2"
    local port="${3:-}"
    local service="${4:-}"
    local tags="${5:-}"

    if [ -z "$project_id" ]; then
        log_error "No project loaded"
        return 1
    fi

    if [ -z "$target" ]; then
        log_error "Target required"
        return 1
    fi

    # Determine if target is IP, hostname, or URL
    local hostname=""
    local ip=""
    local protocol="http"  # Default protocol

    if is_valid_url "$target"; then
        # Extract hostname from URL
        hostname=$(extract_hostname "$target")
        # Extract port from URL if not provided
        if [ -z "$port" ]; then
            port=$(extract_port "$target")
        fi
        # Extract protocol from URL
        protocol=$(extract_protocol "$target")
        [ -z "$protocol" ] && protocol="http"  # Fallback to http
        log_debug "Extracted hostname '$hostname', port '$port', and protocol '$protocol' from URL"
    elif is_valid_ip "$target"; then
        ip="$target"
        # Default to https if port 443, otherwise http
        if [ "$port" = "443" ]; then
            protocol="https"
        fi
    elif is_valid_domain "$target"; then
        hostname="$target"
        # Default to https if port 443, otherwise http
        if [ "$port" = "443" ]; then
            protocol="https"
        fi
    else
        log_error "Invalid target: $target"
        return 1
    fi

    # Add to database with protocol
    local target_id=$(db_target_add "$project_id" "$hostname" "$ip" "$port" "$service" "$tags" "$protocol")

    if [ -n "$target_id" ]; then
        log_success "Target added: $target (ID: $target_id)"
        echo "$target_id"
        return 0
    else
        log_error "Failed to add target"
        return 1
    fi
}

# Add target interactively
project_add_target_interactive() {
    local project_id=$(get_current_project)

    if [ -z "$project_id" ]; then
        log_error "No project loaded. Use 'project load <id>' first"
        return 1
    fi

    echo
    log_section "ADD TARGET"

    read -rp "${BRIGHT_BLUE}Target (IP or hostname):${RESET} " target
    read -rp "${BRIGHT_BLUE}Port (optional):${RESET} " port
    read -rp "${BRIGHT_BLUE}Service (optional):${RESET} " service
    read -rp "${BRIGHT_BLUE}Tags (optional):${RESET} " tags

    if [ -n "$target" ]; then
        project_add_target "$project_id" "$target" "$port" "$service" "$tags"
    else
        log_info "No target specified"
    fi
}

# List targets in project
project_list_targets() {
    local project_id="${1:-$(get_current_project)}"

    if [ -z "$project_id" ]; then
        log_error "No project loaded"
        return 1
    fi

    log_section "TARGETS"
    db_target_list "$project_id"
}

# Archive project
project_archive() {
    local project_id="$1"

    if [ -z "$project_id" ]; then
        log_error "Project ID required"
        return 1
    fi

    db_project_update_status "$project_id" "archived"
    log_success "Project archived"
}

# Reactivate project
project_reactivate() {
    local project_id="$1"

    if [ -z "$project_id" ]; then
        log_error "Project ID required"
        return 1
    fi

    db_project_update_status "$project_id" "active"
    log_success "Project reactivated"
}

# Export project
project_export() {
    local project_id="${1:-$(get_current_project)}"
    local format="${2:-json}"

    if [ -z "$project_id" ]; then
        log_error "No project loaded"
        return 1
    fi

    local project_name=$(sqlite3 "$DB_PATH" "SELECT name FROM projects WHERE id = $project_id;")
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local output_file="${LEKNIGHT_ROOT}/data/exports/${project_name}_${timestamp}.${format}"

    mkdir -p "$(dirname "$output_file")"

    case "$format" in
        json)
            db_export_json "$project_id" "$output_file"
            ;;
        *)
            log_error "Unsupported format: $format"
            return 1
            ;;
    esac

    if [ -f "$output_file" ]; then
        log_success "Project exported to: $output_file"
        echo "$output_file"
    else
        log_error "Export failed"
        return 1
    fi
}

# Set User-Agent for project
project_set_user_agent() {
    local project_id="${1:-$(get_current_project)}"
    local user_agent="$2"

    if [ -z "$project_id" ]; then
        log_error "No project loaded. Use 'project load <id>' first"
        return 1
    fi

    if [ -z "$user_agent" ]; then
        log_error "User-Agent is required"
        echo "Usage: project set-user-agent '<user-agent-string>'"
        echo "Example: project set-user-agent 'Mozilla/5.0 -BugBounty-memento-31337'"
        return 1
    fi

    db_set_user_agent "$project_id" "$user_agent"
    log_success "User-Agent updated for project $project_id"
}

# Get User-Agent for project
project_get_user_agent() {
    local project_id="${1:-$(get_current_project)}"

    if [ -z "$project_id" ]; then
        log_error "No project loaded"
        return 1
    fi

    local user_agent=$(db_get_user_agent "$project_id")

    echo -e "${BRIGHT_BLUE}User-Agent for project ${project_id}:${RESET}"
    echo "$user_agent"
}
