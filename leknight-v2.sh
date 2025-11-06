#!/bin/bash

# LeKnight v2.0 - Professional Bug Bounty & Pentesting Framework
# Author: Mathis BUREAU
# License: MIT

# Determine script location (resolve symlinks)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
export LEKNIGHT_ROOT="$(cd -P "$(dirname "$SOURCE")" && pwd)"

# Load color definitions
RESET="$(tput sgr0)"
BOLD="$(tput bold)"
RED="$(tput setaf 5)"
BLUE="$(tput setaf 7)"
GRAY="$(tput setaf 8)"
BRIGHT_RED="${BOLD}$(tput setaf 3)"
BRIGHT_BLUE="${BOLD}$(tput setaf 7)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"

# Export colors for use in other modules
export RESET BOLD RED BLUE GRAY BRIGHT_RED BRIGHT_BLUE GREEN YELLOW

# Load core modules
source "${LEKNIGHT_ROOT}/core/logger.sh"
source "${LEKNIGHT_ROOT}/core/utils.sh"
source "${LEKNIGHT_ROOT}/core/database.sh"
source "${LEKNIGHT_ROOT}/core/project.sh"
source "${LEKNIGHT_ROOT}/core/protocol_detection.sh"
source "${LEKNIGHT_ROOT}/core/wrapper.sh"
source "${LEKNIGHT_ROOT}/core/parsers.sh"

# Load workflows
source "${LEKNIGHT_ROOT}/workflows/web_recon.sh"
source "${LEKNIGHT_ROOT}/workflows/network_sweep.sh"
source "${LEKNIGHT_ROOT}/workflows/autopilot.sh"

# Load reporting
source "${LEKNIGHT_ROOT}/reports/generate_md.sh"

# ASCII Art
display_banner() {
    clear
    cat << 'EOF'
 __                 __    __            __            __         __
|  \               |  \  /  \          |  \          |  \       |  \
| $$       ______  | $$ /  $$ _______   \$$  ______  | $$____  _| $$_
| $$      /      \ | $$/  $$ |       \ |  \ /      \ | $$    \|   $$ \
| $$     |  $$$$$$\| $$  $$  | $$$$$$$\| $$|  $$$$$$\| $$$$$$$\\$$$$$$
| $$     | $$    $$| $$$$$\  | $$  | $$| $$| $$  | $$| $$  | $$ | $$ __
| $$_____| $$$$$$$$| $$ \$$\ | $$  | $$| $$| $$__| $$| $$  | $$ | $$|  \
| $$     \\$$     \| $$  \$$\| $$  | $$| $$ \$$    $$| $$  | $$  \$$  $$
 \$$$$$$$$ \$$$$$$$ \$$   \$$ \$$   \$$ \$$ _\$$$$$$$ \$$   \$$   \$$$$
                                           |  \__| $$
                                            \$$    $$
                                             \$$$$$$
      L e   K n i g h t   –   A r s e n a l   v 2 . 0

EOF

    echo -e "${BRIGHT_BLUE}Professional Bug Bounty & Pentesting Framework${RESET}"
    echo -e "${BLUE}By: ${BRIGHT_BLUE}Mathis BUREAU${RESET}"
    echo
}

# Main menu
display_main_menu() {
    echo -e "${BRIGHT_RED}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║             LEKNIGHT COMMAND CENTER                    ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    # Show current project if loaded
    local project_id=$(get_current_project)
    if [ -n "$project_id" ]; then
        local project_name=$(sqlite3 "$DB_PATH" "SELECT name FROM projects WHERE id = $project_id;" 2>/dev/null)
        echo -e "${BRIGHT_BLUE}Current Project:${RESET} $project_name ${GRAY}(ID: $project_id)${RESET}"
        echo
    else
        echo -e "${YELLOW}No project loaded${RESET}"
        echo
    fi

    echo -e "  ${RED}[1]${RESET}  ${BRIGHT_BLUE}Project Management${RESET}"
    echo -e "  ${RED}[2]${RESET}  ${BRIGHT_BLUE}Workflows${RESET}"
    echo -e "  ${RED}[3]${RESET}  ${BRIGHT_BLUE}Manual Scans${RESET}"
    echo -e "  ${RED}[4]${RESET}  ${BRIGHT_BLUE}Autopilot Mode${RESET}"
    echo -e "  ${RED}[5]${RESET}  ${BRIGHT_BLUE}View Results${RESET}"
    echo -e "  ${RED}[6]${RESET}  ${BRIGHT_BLUE}Generate Reports${RESET}"
    echo -e "  ${RED}[7]${RESET}  ${BRIGHT_BLUE}Settings${RESET}"
    echo -e "  ${RED}[0]${RESET}  ${BRIGHT_BLUE}Exit${RESET}"
    echo
}

# Project management menu
menu_project_management() {
    while true; do
        clear
        display_banner
        log_section "PROJECT MANAGEMENT"

        echo -e "  ${RED}[1]${RESET}  ${BRIGHT_BLUE}Create New Project${RESET}"
        echo -e "  ${RED}[2]${RESET}  ${BRIGHT_BLUE}List Projects${RESET}"
        echo -e "  ${RED}[3]${RESET}  ${BRIGHT_BLUE}Load Project${RESET}"
        echo -e "  ${RED}[4]${RESET}  ${BRIGHT_BLUE}Project Dashboard${RESET}"
        echo -e "  ${RED}[5]${RESET}  ${BRIGHT_BLUE}Add Target${RESET}"
        echo -e "  ${RED}[6]${RESET}  ${BRIGHT_BLUE}List Targets${RESET}"
        echo -e "  ${RED}[7]${RESET}  ${BRIGHT_BLUE}Delete Project${RESET}"
        echo -e "  ${RED}[0]${RESET}  ${BRIGHT_BLUE}Back${RESET}"
        echo

        read -rp "${BRIGHT_BLUE}Select option${RESET}${BRIGHT_RED} \$${RESET} " choice

        case "$choice" in
            1) project_create_interactive; press_enter ;;
            2) project_list; press_enter ;;
            3) project_load_interactive; press_enter ;;
            4) project_dashboard; press_enter ;;
            5) project_add_target_interactive; press_enter ;;
            6) project_list_targets; press_enter ;;
            7)
                read -rp "Enter project ID to delete: " proj_id
                project_delete "$proj_id"
                press_enter
                ;;
            0) return ;;
            *) log_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Workflows menu
menu_workflows() {
    while true; do
        clear
        display_banner
        log_section "WORKFLOWS"

        echo -e "  ${RED}[1]${RESET}  ${BRIGHT_BLUE}Web Reconnaissance${RESET}"
        echo -e "  ${RED}[2]${RESET}  ${BRIGHT_BLUE}Network Sweep${RESET}"
        echo -e "  ${RED}[3]${RESET}  ${BRIGHT_BLUE}Subdomain Scanner${RESET}"
        echo -e "  ${RED}[4]${RESET}  ${BRIGHT_BLUE}Service-Specific Scan${RESET}"
        echo -e "  ${RED}[0]${RESET}  ${BRIGHT_BLUE}Back${RESET}"
        echo

        read -rp "${BRIGHT_BLUE}Select workflow${RESET}${BRIGHT_RED} \$${RESET} " choice

        case "$choice" in
            1) workflow_web_interactive ;;
            2) workflow_network_interactive ;;
            3) workflow_scan_subdomains; press_enter ;;
            4)
                read -rp "Enter target: " target
                read -rp "Enter service (web/ftp/ssh/smb/rdp/database): " service
                workflow_service_scan "$target" "$service"
                press_enter
                ;;
            0) return ;;
            *) log_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Manual scans menu
menu_manual_scans() {
    while true; do
        clear
        display_banner
        log_section "MANUAL SCANS"

        echo -e "  ${RED}[1]${RESET}  ${BRIGHT_BLUE}Nmap${RESET}"
        echo -e "  ${RED}[2]${RESET}  ${BRIGHT_BLUE}Nikto${RESET}"
        echo -e "  ${RED}[3]${RESET}  ${BRIGHT_BLUE}Nuclei${RESET}"
        echo -e "  ${RED}[4]${RESET}  ${BRIGHT_BLUE}SQLMap${RESET}"
        echo -e "  ${RED}[5]${RESET}  ${BRIGHT_BLUE}WPScan${RESET}"
        echo -e "  ${RED}[6]${RESET}  ${BRIGHT_BLUE}Subfinder${RESET}"
        echo -e "  ${RED}[7]${RESET}  ${BRIGHT_BLUE}Custom Tool${RESET}"
        echo -e "  ${RED}[0]${RESET}  ${BRIGHT_BLUE}Back${RESET}"
        echo

        read -rp "${BRIGHT_BLUE}Select tool${RESET}${BRIGHT_RED} \$${RESET} " choice

        local tool target args

        case "$choice" in
            1) tool="nmap" ;;
            2) tool="nikto" ;;
            3) tool="nuclei" ;;
            4) tool="sqlmap" ;;
            5) tool="wpscan" ;;
            6) tool="subfinder" ;;
            7)
                read -rp "Enter tool name: " tool
                ;;
            0) return ;;
            *) log_error "Invalid option"; sleep 1; continue ;;
        esac

        read -rp "Enter target: " target
        read -rp "Additional arguments (optional): " args

        if [ -n "$target" ]; then
            run_tool "$tool" "$target" "$args"
            press_enter
        fi
    done
}

# Autopilot menu
menu_autopilot() {
    while true; do
        clear
        display_banner
        log_section "AUTOPILOT MODE"

        echo -e "  ${RED}[1]${RESET}  ${BRIGHT_BLUE}Start Autopilot${RESET}"
        echo -e "  ${RED}[2]${RESET}  ${BRIGHT_BLUE}Monitor Mode (Continuous)${RESET}"
        echo -e "  ${RED}[3]${RESET}  ${BRIGHT_BLUE}Rescan High-Value Targets${RESET}"
        echo -e "  ${RED}[4]${RESET}  ${BRIGHT_BLUE}Exploit Mode${RESET}"
        echo -e "  ${RED}[0]${RESET}  ${BRIGHT_BLUE}Back${RESET}"
        echo

        read -rp "${BRIGHT_BLUE}Select mode${RESET}${BRIGHT_RED} \$${RESET} " choice

        case "$choice" in
            1) autopilot_start; press_enter ;;
            2)
                read -rp "Enter scan interval in seconds (default 3600): " interval
                autopilot_monitor "${interval:-3600}"
                ;;
            3) autopilot_rescan_high_value; press_enter ;;
            4) autopilot_exploit_mode; press_enter ;;
            0) return ;;
            *) log_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# View results menu
menu_view_results() {
    while true; do
        clear
        display_banner
        log_section "VIEW RESULTS"

        echo -e "  ${RED}[1]${RESET}  ${BRIGHT_BLUE}Project Dashboard${RESET}"
        echo -e "  ${RED}[2]${RESET}  ${BRIGHT_BLUE}List All Findings${RESET}"
        echo -e "  ${RED}[3]${RESET}  ${BRIGHT_BLUE}Critical/High Findings${RESET}"
        echo -e "  ${RED}[4]${RESET}  ${BRIGHT_BLUE}Discovered Credentials${RESET}"
        echo -e "  ${RED}[5]${RESET}  ${BRIGHT_BLUE}Scan History${RESET}"
        echo -e "  ${RED}[6]${RESET}  ${BRIGHT_BLUE}View Logs${RESET}"
        echo -e "  ${RED}[0]${RESET}  ${BRIGHT_BLUE}Back${RESET}"
        echo

        read -rp "${BRIGHT_BLUE}Select view${RESET}${BRIGHT_RED} \$${RESET} " choice

        local project_id=$(get_current_project)

        case "$choice" in
            1) project_dashboard; press_enter ;;
            2) db_finding_list "$project_id" "all"; press_enter ;;
            3) db_finding_list "$project_id" "high"; press_enter ;;
            4) db_credential_list "$project_id"; press_enter ;;
            5) db_scan_list "$project_id"; press_enter ;;
            6) log_show 50; press_enter ;;
            0) return ;;
            *) log_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Generate reports menu
menu_reports() {
    while true; do
        clear
        display_banner
        log_section "GENERATE REPORTS"

        echo -e "  ${RED}[1]${RESET}  ${BRIGHT_BLUE}Markdown Report${RESET}"
        echo -e "  ${RED}[2]${RESET}  ${BRIGHT_BLUE}CSV Export (Findings)${RESET}"
        echo -e "  ${RED}[3]${RESET}  ${BRIGHT_BLUE}JSON Export${RESET}"
        echo -e "  ${RED}[4]${RESET}  ${BRIGHT_BLUE}Quick Summary${RESET}"
        echo -e "  ${RED}[0]${RESET}  ${BRIGHT_BLUE}Back${RESET}"
        echo

        read -rp "${BRIGHT_BLUE}Select format${RESET}${BRIGHT_RED} \$${RESET} " choice

        local project_id=$(get_current_project)

        case "$choice" in
            1) generate_markdown_report "$project_id"; press_enter ;;
            2) export_findings_csv "$project_id"; press_enter ;;
            3) project_export "$project_id" "json"; press_enter ;;
            4) generate_quick_summary "$project_id"; press_enter ;;
            0) return ;;
            *) log_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Settings menu
menu_settings() {
    while true; do
        clear
        display_banner
        log_section "SETTINGS"

        echo -e "  ${RED}[1]${RESET}  ${BRIGHT_BLUE}View System Info${RESET}"
        echo -e "  ${RED}[2]${RESET}  ${BRIGHT_BLUE}Check Required Tools${RESET}"
        echo -e "  ${RED}[3]${RESET}  ${BRIGHT_BLUE}Database Cleanup${RESET}"
        echo -e "  ${RED}[4]${RESET}  ${BRIGHT_BLUE}Log Management${RESET}"
        echo -e "  ${RED}[5]${RESET}  ${BRIGHT_BLUE}Backup Database${RESET}"
        echo -e "  ${RED}[0]${RESET}  ${BRIGHT_BLUE}Back${RESET}"
        echo

        read -rp "${BRIGHT_BLUE}Select option${RESET}${BRIGHT_RED} \$${RESET} " choice

        case "$choice" in
            1) get_system_info; press_enter ;;
            2)
                log_info "Checking common tools..."
                for tool in nmap nikto nuclei sqlmap subfinder ffuf; do
                    if command_exists "$tool"; then
                        log_success "$tool installed"
                    else
                        log_warning "$tool not installed"
                    fi
                done
                press_enter
                ;;
            3)
                read -rp "Delete scans older than N days (default 30): " days
                db_cleanup "${days:-30}"
                press_enter
                ;;
            4)
                echo "1) View recent logs"
                echo "2) Search logs"
                echo "3) Clear logs"
                read -rp "Select: " log_choice
                case "$log_choice" in
                    1) log_show 100 ;;
                    2)
                        read -rp "Search query: " query
                        log_search "$query"
                        ;;
                    3) log_rotate ;;
                esac
                press_enter
                ;;
            5)
                local backup=$(create_backup "$DB_PATH")
                log_success "Database backed up to: $backup"
                press_enter
                ;;
            0) return ;;
            *) log_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Initialize LeKnight
initialize() {
    # Check if database exists, if not initialize
    if [ ! -f "$DB_PATH" ]; then
        log_info "First time setup..."
        db_init
    fi
}

# Main loop
main() {
    initialize

    while true; do
        clear
        display_banner
        display_main_menu

        read -rp "${BRIGHT_BLUE}Select option${RESET}${BRIGHT_RED} \$${RESET} " choice

        case "$choice" in
            1) menu_project_management ;;
            2) menu_workflows ;;
            3) menu_manual_scans ;;
            4) menu_autopilot ;;
            5) menu_view_results ;;
            6) menu_reports ;;
            7) menu_settings ;;
            0)
                echo
                log_info "Shutting down LeKnight..."
                sleep 1
                clear
                exit 0
                ;;
            *)
                log_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Run main if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main
fi
