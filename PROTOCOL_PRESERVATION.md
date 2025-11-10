# Protocol Preservation Feature

## Overview
LeKnight now respects user-specified protocols (http/https) when creating targets, instead of automatically detecting protocols. This ensures that if you specify `http://example.com` in your scope, LeKnight will test it over HTTP as you intended, not auto-switch to HTTPS.

## Changes Made

### 1. Database Schema Enhancement
**File:** `core/database.sh`

- Added `protocol` column to the `targets` table (line 38)
- Default value: `'http'`
- Updated `db_target_add()` function to accept and store protocol parameter (line 197)

```sql
CREATE TABLE IF NOT EXISTS targets (
    ...
    protocol TEXT DEFAULT 'http',
    ...
);
```

### 2. Project Target Management
**File:** `core/project.sh`

- Updated `project_add_target()` function (lines 348-382) to:
  - Extract protocol from URLs using `extract_protocol()`
  - Store protocol in database when adding targets
  - Default to `https` for port 443, `http` otherwise

**Before:**
```bash
local target_id=$(db_target_add "$project_id" "$hostname" "$ip" "$port" "$service" "$tags")
```

**After:**
```bash
protocol=$(extract_protocol "$target")
local target_id=$(db_target_add "$project_id" "$hostname" "$ip" "$port" "$service" "$tags" "$protocol")
```

### 3. Advanced Autopilot Protocol Handling
**File:** `workflows/autopilot_advanced.sh`

- Updated `autopilot_scan_domain_advanced()` function (lines 41-54)
- **Removed:** Automatic protocol detection via timeout check on port 443
- **Added:** Database query to retrieve user-specified protocol

**Before (Auto-detection):**
```bash
if timeout 10 bash -c "echo > /dev/tcp/$domain/443" 2>/dev/null; then
    target_url="https://$domain"
else
    target_url="http://$domain"
fi
```

**After (Database lookup):**
```bash
local protocol=$(sqlite3 "$DB_PATH" "SELECT protocol FROM targets WHERE id = $target_id LIMIT 1;" 2>/dev/null)
if [ -z "$protocol" ]; then
    protocol="http"
fi
local target_url="${protocol}://${domain}"
```

### 4. Standard Autopilot Protocol Handling
**File:** `workflows/autopilot.sh`

- Updated `autopilot_scan_domain()` function (lines 324-331)
- Queries database first, falls back to auto-detection only if not found

```bash
local protocol=$(sqlite3 "$DB_PATH" "SELECT protocol FROM targets WHERE id = $target_id LIMIT 1;" 2>/dev/null)
if [ -z "$protocol" ]; then
    protocol=$(smart_detect_protocol "$domain")
fi
```

### 5. Database Migration Script
**File:** `core/db_migration_protocol.sh` (New file)

- Automated migration script to add `protocol` column to existing databases
- Updates existing targets with port 443 to use `https`
- Safe to run multiple times (checks if column already exists)

**Usage:**
```bash
bash core/db_migration_protocol.sh
```

## How It Works

### New Target Creation Flow

1. **User specifies target:** `http://example.com`
2. **extract_protocol()** extracts: `"http"`
3. **project_add_target()** stores in database:
   - hostname: `"example.com"`
   - protocol: `"http"`
4. **Autopilot scans domain:**
   - Queries database: `SELECT protocol FROM targets WHERE id = X`
   - Uses stored protocol: `http://example.com`
   - **No auto-detection!**

### Protocol Detection Priority

1. **First:** Check database for stored protocol (user's explicit choice)
2. **Second:** If not in database, use `smart_detect_protocol()` (fallback)
3. **Third:** Default to `http` if everything fails

## Benefits

1. **Respects user intent:** If you specify HTTP, it tests over HTTP
2. **Bug bounty compliance:** Some programs require specific protocols
3. **Predictable behavior:** No surprising protocol changes
4. **Backward compatible:** Falls back to auto-detection for old targets

## Testing

### For New Databases
New installations automatically include the protocol column in the schema. No migration needed.

### For Existing Databases
Run the migration script:
```bash
bash core/db_migration_protocol.sh
```

### Verify Protocol Storage
After adding a target, verify the protocol was stored:
```bash
sqlite3 data/db/leknight.db "SELECT id, hostname, protocol FROM targets;"
```

### Test Autopilot Respect
```bash
# Create project with HTTP target
./leknight.sh project create "Test HTTP"
./leknight.sh project add-target "http://testphp.vulnweb.com"

# Run autopilot - should use HTTP
./leknight.sh autopilot

# Check logs - should show "Using protocol from database: http"
```

## Migration Guide

### For Existing Projects

1. **Backup your database:**
   ```bash
   cp data/db/leknight.db data/db/leknight.db.backup
   ```

2. **Run migration:**
   ```bash
   bash core/db_migration_protocol.sh
   ```

3. **Verify:**
   ```bash
   sqlite3 data/db/leknight.db "PRAGMA table_info(targets);" | grep protocol
   ```

### For New Projects
No action required - the protocol column is included automatically.

## Troubleshooting

### Issue: "Protocol column not found"
**Solution:** Run the migration script: `bash core/db_migration_protocol.sh`

### Issue: "Still auto-detecting HTTPS"
**Check:**
1. Protocol stored in database: `sqlite3 data/db/leknight.db "SELECT protocol FROM targets;"`
2. Target was created with explicit protocol: Use `http://` or `https://` prefix
3. Logs show "Using protocol from database" message

### Issue: "Migration says column already exists"
**This is normal:** The migration is idempotent and safe to run multiple times.

## Related Files

- `core/utils.sh` - Contains `extract_protocol()` function (lines 118-128)
- `core/http_helper.sh` - User-Agent handling for HTTP requests
- `core/protocol_detection.sh` - Auto-detection fallback functions

## Future Enhancements

- [ ] Add protocol column to project scope definition
- [ ] UI/TUI indicator showing which protocol is being used
- [ ] Protocol override command: `leknight target set-protocol <id> <http|https>`
- [ ] Bulk protocol update: `leknight project update-protocols`

## Changelog

**v2.0.2 - Protocol Preservation**
- Added protocol column to targets table
- Updated target creation to store user-specified protocols
- Modified autopilot to respect stored protocols instead of auto-detecting
- Created database migration script for existing installations
- Backward compatible with existing databases via fallback mechanism
