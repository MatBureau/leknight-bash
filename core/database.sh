#!/bin/bash

# database.sh - SQLite database management for LeKnight
# Handles all database operations for projects, targets, scans, findings, and credentials

# Database location
DB_PATH="${LEKNIGHT_ROOT}/data/db/leknight.db"

# Initialize database with schema
db_init() {
    if [ ! -f "$DB_PATH" ]; then
        log_info "Initializing database at $DB_PATH"
        mkdir -p "$(dirname "$DB_PATH")"
    fi

    sqlite3 "$DB_PATH" <<EOF
-- Projects table
CREATE TABLE IF NOT EXISTS projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    scope TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'active'
);

-- Targets table
CREATE TABLE IF NOT EXISTS targets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER NOT NULL,
    hostname TEXT,
    ip TEXT,
    port INTEGER,
    service TEXT,
    tags TEXT,
    notes TEXT,
    autopilot_status TEXT DEFAULT 'pending',
    autopilot_completed_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Scans table
CREATE TABLE IF NOT EXISTS scans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER NOT NULL,
    target_id INTEGER,
    tool TEXT NOT NULL,
    command TEXT NOT NULL,
    output_file TEXT,
    status TEXT DEFAULT 'running',
    started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME,
    exit_code INTEGER,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (target_id) REFERENCES targets(id) ON DELETE SET NULL
);

-- Findings table
CREATE TABLE IF NOT EXISTS findings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_id INTEGER NOT NULL,
    target_id INTEGER,
    project_id INTEGER NOT NULL,
    severity TEXT NOT NULL,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    evidence TEXT,
    cvss_score REAL,
    cve TEXT,
    remediation TEXT,
    status TEXT DEFAULT 'open',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE,
    FOREIGN KEY (target_id) REFERENCES targets(id) ON DELETE SET NULL,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Credentials table
CREATE TABLE IF NOT EXISTS credentials (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER NOT NULL,
    target_id INTEGER,
    username TEXT,
    password TEXT,
    hash TEXT,
    hash_type TEXT,
    service TEXT,
    source TEXT,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (target_id) REFERENCES targets(id) ON DELETE SET NULL
);

-- Workflow runs table
CREATE TABLE IF NOT EXISTS workflow_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER NOT NULL,
    workflow_name TEXT NOT NULL,
    target TEXT NOT NULL,
    status TEXT DEFAULT 'running',
    progress INTEGER DEFAULT 0,
    total_steps INTEGER,
    current_step TEXT,
    started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_targets_project ON targets(project_id);
CREATE INDEX IF NOT EXISTS idx_targets_autopilot ON targets(autopilot_status);
CREATE INDEX IF NOT EXISTS idx_targets_project_autopilot ON targets(project_id, autopilot_status);
CREATE INDEX IF NOT EXISTS idx_scans_project ON scans(project_id);
CREATE INDEX IF NOT EXISTS idx_scans_target ON scans(target_id);
CREATE INDEX IF NOT EXISTS idx_findings_project ON findings(project_id);
CREATE INDEX IF NOT EXISTS idx_findings_severity ON findings(severity);
CREATE INDEX IF NOT EXISTS idx_findings_status ON findings(status);
CREATE INDEX IF NOT EXISTS idx_credentials_project ON credentials(project_id);
CREATE INDEX IF NOT EXISTS idx_workflow_runs_project ON workflow_runs(project_id);
EOF

    if [ $? -eq 0 ]; then
        log_success "Database initialized successfully"
    else
        log_error "Failed to initialize database"
        return 1
    fi
}

# Project operations
db_project_create() {
    local name="$1"
    local description="$2"
    local scope="$3"

    sqlite3 "$DB_PATH" <<EOF
INSERT INTO projects (name, description, scope)
VALUES ('$name', '$description', '$scope');
SELECT last_insert_rowid();
EOF
}

db_project_list() {
    sqlite3 -header -column "$DB_PATH" <<EOF
SELECT id, name, status, created_at,
       (SELECT COUNT(*) FROM targets WHERE project_id = projects.id) as targets,
       (SELECT COUNT(*) FROM scans WHERE project_id = projects.id) as scans,
       (SELECT COUNT(*) FROM findings WHERE project_id = projects.id) as findings
FROM projects
ORDER BY created_at DESC;
EOF
}

db_project_get() {
    local project_id="$1"
    sqlite3 -header -column "$DB_PATH" <<EOF
SELECT * FROM projects WHERE id = $project_id;
EOF
}

db_project_get_by_name() {
    local name="$1"
    sqlite3 "$DB_PATH" <<EOF
SELECT id FROM projects WHERE name = '$name' LIMIT 1;
EOF
}

db_project_delete() {
    local project_id="$1"
    sqlite3 "$DB_PATH" <<EOF
DELETE FROM projects WHERE id = $project_id;
EOF
}

db_project_update_status() {
    local project_id="$1"
    local status="$2"
    sqlite3 "$DB_PATH" <<EOF
UPDATE projects SET status = '$status', updated_at = CURRENT_TIMESTAMP WHERE id = $project_id;
EOF
}

# Target operations
db_target_add() {
    local project_id="$1"
    local hostname="$2"
    local ip="$3"
    local port="$4"
    local service="$5"
    local tags="$6"

    # Handle NULL values for port
    local port_value="NULL"
    if [ -n "$port" ] && [ "$port" != "0" ] && [ "$port" != "" ]; then
        port_value="$port"
    fi

    # Use -batch mode to avoid extra output
    sqlite3 -batch "$DB_PATH" <<EOF 2>/dev/null
INSERT INTO targets (project_id, hostname, ip, port, service, tags, autopilot_status)
VALUES ($project_id, '$hostname', '$ip', $port_value, '$service', '$tags', 'pending');
SELECT last_insert_rowid();
EOF
}

db_target_list() {
    local project_id="$1"
    sqlite3 -header -column "$DB_PATH" <<EOF
SELECT id, hostname, ip, port, service, tags FROM targets
WHERE project_id = $project_id
ORDER BY created_at DESC;
EOF
}

db_target_get() {
    local target_id="$1"
    sqlite3 -header -column "$DB_PATH" <<EOF
SELECT * FROM targets WHERE id = $target_id;
EOF
}

# Scan operations
db_scan_create() {
    local project_id="$1"
    local target_id="$2"
    local tool="$3"
    local command="$4"
    local output_file="$5"

    # Validate target_id is not empty
    if [ -z "$target_id" ] || [ "$target_id" = "" ]; then
        echo "ERROR: target_id is empty" >&2
        return 1
    fi

    # Escape single quotes in command and output_file
    command=$(echo "$command" | sed "s/'/''/g")
    output_file=$(echo "$output_file" | sed "s/'/''/g")

    sqlite3 -batch "$DB_PATH" <<EOF 2>/dev/null
INSERT INTO scans (project_id, target_id, tool, command, output_file, status)
VALUES ($project_id, $target_id, '$tool', '$command', '$output_file', 'running');
SELECT last_insert_rowid();
EOF
}

db_scan_complete() {
    local scan_id="$1"
    local exit_code="$2"
    local status="completed"
    [ "$exit_code" -ne 0 ] && status="failed"

    sqlite3 "$DB_PATH" <<EOF
UPDATE scans
SET status = '$status', completed_at = CURRENT_TIMESTAMP, exit_code = $exit_code
WHERE id = $scan_id;
EOF
}

db_scan_list() {
    local project_id="$1"
    sqlite3 -header -column "$DB_PATH" <<EOF
SELECT id, tool, status, started_at,
       (SELECT hostname FROM targets WHERE id = scans.target_id) as target
FROM scans
WHERE project_id = $project_id
ORDER BY started_at DESC
LIMIT 50;
EOF
}

db_scan_get_recent() {
    local project_id="$1"
    local limit="${2:-10}"
    sqlite3 -header -column "$DB_PATH" <<EOF
SELECT id, tool, status, started_at FROM scans
WHERE project_id = $project_id
ORDER BY started_at DESC
LIMIT $limit;
EOF
}

# Finding operations
db_finding_add() {
    local scan_id="$1"
    local project_id="$2"
    local target_id="$3"
    local severity="$4"
    local type="$5"
    local title="$6"
    local description="$7"
    local evidence="$8"

    # Store original severity for notifications (before escaping)
    local original_severity="$severity"
    local original_title="$title"
    local original_description="$description"

    # Escape single quotes in text fields
    severity=$(echo "$severity" | sed "s/'/''/g")
    type=$(echo "$type" | sed "s/'/''/g")
    title=$(echo "$title" | sed "s/'/''/g")
    description=$(echo "$description" | sed "s/'/''/g")
    evidence=$(echo "$evidence" | sed "s/'/''/g")

    local finding_id=$(sqlite3 -batch "$DB_PATH" <<EOF 2>/dev/null
INSERT INTO findings (scan_id, project_id, target_id, severity, type, title, description, evidence)
VALUES ($scan_id, $project_id, $target_id, '$severity', '$type', '$title', '$description', '$evidence');
SELECT last_insert_rowid();
EOF
)

    # Send notification for critical/high findings
    if [[ "$original_severity" =~ ^(critical|high)$ ]]; then
        # Get target info for notification
        local target_info=$(sqlite3 "$DB_PATH" "SELECT COALESCE(hostname, ip, 'unknown') FROM targets WHERE id = $target_id LIMIT 1;" 2>/dev/null || echo "unknown")

        # Send notification asynchronously (don't block)
        (notify_all "$original_severity" "$original_title" "$original_description" "$target_info" &)
    fi

    echo "$finding_id"
}

db_finding_list() {
    local project_id="$1"
    local severity_filter="${2:-all}"

    local where_clause="project_id = $project_id"
    [ "$severity_filter" != "all" ] && where_clause="$where_clause AND severity = '$severity_filter'"

    sqlite3 -header -column "$DB_PATH" <<EOF
SELECT id, severity, type, title, status, created_at,
       (SELECT hostname FROM targets WHERE id = findings.target_id) as target
FROM findings
WHERE $where_clause
ORDER BY
    CASE severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
        ELSE 5
    END,
    created_at DESC;
EOF
}

db_finding_stats() {
    local project_id="$1"
    sqlite3 "$DB_PATH" <<EOF
SELECT
    SUM(CASE WHEN severity = 'critical' THEN 1 ELSE 0 END) as critical,
    SUM(CASE WHEN severity = 'high' THEN 1 ELSE 0 END) as high,
    SUM(CASE WHEN severity = 'medium' THEN 1 ELSE 0 END) as medium,
    SUM(CASE WHEN severity = 'low' THEN 1 ELSE 0 END) as low,
    SUM(CASE WHEN severity = 'info' THEN 1 ELSE 0 END) as info
FROM findings
WHERE project_id = $project_id;
EOF
}

# Credential operations
db_credential_add() {
    local project_id="$1"
    local target_id="$2"
    local username="$3"
    local password="$4"
    local hash="$5"
    local hash_type="$6"
    local service="$7"
    local source="$8"

    sqlite3 "$DB_PATH" <<EOF
INSERT INTO credentials (project_id, target_id, username, password, hash, hash_type, service, source)
VALUES ($project_id, $target_id, '$username', '$password', '$hash', '$hash_type', '$service', '$source');
SELECT last_insert_rowid();
EOF
}

db_credential_list() {
    local project_id="$1"
    sqlite3 -header -column "$DB_PATH" <<EOF
SELECT id, username, password, hash, service, source, created_at,
       (SELECT hostname FROM targets WHERE id = credentials.target_id) as target
FROM credentials
WHERE project_id = $project_id
ORDER BY created_at DESC;
EOF
}

# Workflow operations
db_workflow_create() {
    local project_id="$1"
    local workflow_name="$2"
    local target="$3"
    local total_steps="$4"

    sqlite3 "$DB_PATH" <<EOF
INSERT INTO workflow_runs (project_id, workflow_name, target, total_steps)
VALUES ($project_id, '$workflow_name', '$target', $total_steps);
SELECT last_insert_rowid();
EOF
}

db_workflow_update() {
    local workflow_id="$1"
    local progress="$2"
    local current_step="$3"

    sqlite3 "$DB_PATH" <<EOF
UPDATE workflow_runs
SET progress = $progress, current_step = '$current_step'
WHERE id = $workflow_id;
EOF
}

db_workflow_complete() {
    local workflow_id="$1"
    local status="$2"

    sqlite3 "$DB_PATH" <<EOF
UPDATE workflow_runs
SET status = '$status', completed_at = CURRENT_TIMESTAMP, progress = 100
WHERE id = $workflow_id;
EOF
}

# Statistics and dashboard data
db_project_stats() {
    local project_id="$1"

    echo "=== PROJECT STATISTICS ==="
    echo

    # Basic counts
    echo "Targets:"
    sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM targets WHERE project_id = $project_id;"

    echo "Scans:"
    sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM scans WHERE project_id = $project_id;"

    echo "Findings:"
    sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM findings WHERE project_id = $project_id;"

    echo "Credentials:"
    sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM credentials WHERE project_id = $project_id;"

    echo
    echo "=== FINDINGS BY SEVERITY ==="
    db_finding_stats "$project_id"
}

# Cleanup old data
db_cleanup() {
    local days="${1:-30}"
    sqlite3 "$DB_PATH" <<EOF
-- Delete old completed scans (but keep findings)
DELETE FROM scans
WHERE status = 'completed'
AND completed_at < datetime('now', '-$days days');

-- Vacuum database
VACUUM;
EOF
}

# Export data to JSON
db_export_json() {
    local project_id="$1"
    local output_file="$2"

    sqlite3 "$DB_PATH" <<EOF > "$output_file"
.mode json
.once $output_file
SELECT json_object(
    'project', (SELECT json_object('id', id, 'name', name, 'created_at', created_at) FROM projects WHERE id = $project_id),
    'targets', (SELECT json_group_array(json_object('id', id, 'hostname', hostname, 'ip', ip)) FROM targets WHERE project_id = $project_id),
    'findings', (SELECT json_group_array(json_object('severity', severity, 'title', title, 'description', description)) FROM findings WHERE project_id = $project_id),
    'credentials', (SELECT json_group_array(json_object('username', username, 'service', service)) FROM credentials WHERE project_id = $project_id)
);
EOF
}
