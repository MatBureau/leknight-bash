#!/bin/bash

# Database migration: Add protocol column to targets table
# This allows LeKnight to respect user-specified protocols (http/https)

LEKNIGHT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_PATH="${LEKNIGHT_ROOT}/data/db/leknight.db"

source "${LEKNIGHT_ROOT}/core/logger.sh"

log_section "DATABASE MIGRATION: Add Protocol Column"

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    log_error "Database not found at $DB_PATH"
    log_info "Run ./leknight.sh first to initialize the database"
    exit 1
fi

# Check if protocol column already exists
column_exists=$(sqlite3 "$DB_PATH" "PRAGMA table_info(targets);" | grep -c "protocol")

if [ "$column_exists" -gt 0 ]; then
    log_info "Protocol column already exists, skipping migration"
    exit 0
fi

log_info "Adding protocol column to targets table..."

# Add protocol column with default value 'http'
sqlite3 "$DB_PATH" <<EOF
ALTER TABLE targets ADD COLUMN protocol TEXT DEFAULT 'http';
EOF

if [ $? -eq 0 ]; then
    log_success "Protocol column added successfully"

    # Update existing records to use https for port 443
    log_info "Updating existing targets with port 443 to use https..."
    sqlite3 "$DB_PATH" "UPDATE targets SET protocol = 'https' WHERE port = 443;"

    log_success "Migration completed successfully"
    log_info "LeKnight will now respect user-specified protocols (http/https)"
else
    log_error "Migration failed"
    exit 1
fi
