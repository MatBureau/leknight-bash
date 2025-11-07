#!/bin/bash

# Migration script to add user_agent column to existing projects table

LEKNIGHT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_PATH="${LEKNIGHT_ROOT}/data/db/leknight.db"

echo "==================================="
echo "LeKnight Database Migration"
echo "Adding User-Agent support"
echo "==================================="
echo ""

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    echo "❌ Database not found at: $DB_PATH"
    echo "Nothing to migrate."
    exit 0
fi

# Check if user_agent column already exists
column_exists=$(sqlite3 "$DB_PATH" "PRAGMA table_info(projects);" | grep -c "user_agent")

if [ "$column_exists" -gt 0 ]; then
    echo "✅ Column 'user_agent' already exists in projects table"
    echo "No migration needed."
    exit 0
fi

echo "📊 Adding 'user_agent' column to projects table..."

# Add the column
sqlite3 "$DB_PATH" <<EOF
ALTER TABLE projects ADD COLUMN user_agent TEXT;
EOF

if [ $? -eq 0 ]; then
    echo "✅ Migration successful!"
    echo ""
    echo "Column 'user_agent' has been added to the projects table."
    echo "Existing projects will use the default User-Agent."
    echo ""
    echo "To set a custom User-Agent for a project:"
    echo "  ./leknight.sh"
    echo "  > project load <id>"
    echo "  > project set-user-agent 'Mozilla/5.0 -BugBounty-youridentifier'"
    echo ""
else
    echo "❌ Migration failed!"
    echo "Please check the database and try again."
    exit 1
fi
