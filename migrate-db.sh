#!/bin/bash

# migrate-db.sh - Database migration script for LeKnight autopilot fixes
# This script adds the autopilot_status and autopilot_completed_at columns to existing databases

# Determine script location
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
export LEKNIGHT_ROOT="$(cd -P "$(dirname "$SOURCE")" && pwd)"

# Database location
DB_PATH="${LEKNIGHT_ROOT}/data/db/leknight.db"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     LeKnight Database Migration - Autopilot Fix       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    echo -e "${YELLOW}[!] Database not found at: $DB_PATH${NC}"
    echo -e "${BLUE}[i] No migration needed - database will be created with correct schema${NC}"
    exit 0
fi

echo -e "${BLUE}[i] Database found: $DB_PATH${NC}"

# Create backup
BACKUP_PATH="${DB_PATH}.backup_$(date +%Y%m%d_%H%M%S)"
echo -e "${BLUE}[i] Creating backup: $BACKUP_PATH${NC}"
cp "$DB_PATH" "$BACKUP_PATH"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[✓] Backup created successfully${NC}"
else
    echo -e "${RED}[✗] Failed to create backup${NC}"
    exit 1
fi

# Check if columns already exist
echo -e "${BLUE}[i] Checking if migration is needed...${NC}"

COLUMN_CHECK=$(sqlite3 "$DB_PATH" "PRAGMA table_info(targets);" | grep -c "autopilot_status")

if [ "$COLUMN_CHECK" -gt 0 ]; then
    echo -e "${YELLOW}[!] Migration already applied - autopilot_status column exists${NC}"
    echo -e "${BLUE}[i] No changes needed${NC}"
    exit 0
fi

# Apply migration
echo -e "${BLUE}[i] Applying migration...${NC}"

sqlite3 "$DB_PATH" <<EOF
-- Add autopilot status tracking columns
ALTER TABLE targets ADD COLUMN autopilot_status TEXT DEFAULT 'pending';
ALTER TABLE targets ADD COLUMN autopilot_completed_at DATETIME;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_targets_autopilot ON targets(autopilot_status);
CREATE INDEX IF NOT EXISTS idx_targets_project_autopilot ON targets(project_id, autopilot_status);

-- Update existing targets to pending status
UPDATE targets SET autopilot_status = 'pending' WHERE autopilot_status IS NULL;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[✓] Migration completed successfully${NC}"
    echo
    echo -e "${BLUE}[i] Changes applied:${NC}"
    echo -e "  - Added autopilot_status column (default: 'pending')"
    echo -e "  - Added autopilot_completed_at column"
    echo -e "  - Created performance indexes"
    echo -e "  - Updated existing targets to pending status"
    echo
    echo -e "${GREEN}[✓] Backup saved at: $BACKUP_PATH${NC}"
    echo -e "${BLUE}[i] You can now run the autopilot mode${NC}"
else
    echo -e "${RED}[✗] Migration failed${NC}"
    echo -e "${YELLOW}[!] Restoring from backup...${NC}"
    cp "$BACKUP_PATH" "$DB_PATH"
    echo -e "${GREEN}[✓] Database restored from backup${NC}"
    exit 1
fi

# Verify migration
echo
echo -e "${BLUE}[i] Verifying migration...${NC}"

VERIFY=$(sqlite3 "$DB_PATH" "PRAGMA table_info(targets);" | grep autopilot_status)

if [ -n "$VERIFY" ]; then
    echo -e "${GREEN}[✓] Migration verified successfully${NC}"

    # Show statistics
    TOTAL_TARGETS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM targets;")
    PENDING_TARGETS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM targets WHERE autopilot_status = 'pending';")

    echo
    echo -e "${BLUE}[i] Database statistics:${NC}"
    echo -e "  - Total targets: $TOTAL_TARGETS"
    echo -e "  - Pending targets: $PENDING_TARGETS"
else
    echo -e "${RED}[✗] Migration verification failed${NC}"
    exit 1
fi

echo
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Migration completed successfully!             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
