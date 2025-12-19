#!/bin/bash
# =============================================================================
# hooks/pre-up.sh
# Pre-up hook: Generate docker-compose.override.yml in plugin directory
#
# Execution context:
#   - Runs on HOST before 'mars up' or 'mars-dev up' command
#   - Working directory: varies by CLI
#   - MARS_PLUGIN_ROOT: Path to this plugin directory
#   - MARS_REPO_ROOT: Path to MARS repository
#
# Two sources of volume mounts:
#   1. external-mounts.yml - Mounts for files OUTSIDE this plugin
#      (credentials repos, dotfiles repo, ~/.ssh, etc.)
#   2. mounted-files/ - Files that LIVE in this plugin (auto-mounted)
#
# Generated output:
#   - <plugin>/generated/docker-compose.override.yml
#   - Discovered via COMPOSE_FILE env var (see compose-file-discovery.sh)
# =============================================================================
set -euo pipefail

# =============================================================================
# Setup
# =============================================================================

# Get the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Self-detect MARS_PLUGIN_ROOT if not set (enables standalone execution)
# The plugin root is the parent directory of hooks/
if [ -z "${MARS_PLUGIN_ROOT:-}" ]; then
    export MARS_PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

# Source utilities for consistent logging
source "${SCRIPT_DIR}/scripts/utils.sh"

# Override log function prefix for pre-up context
log_info() {
    echo -e "${BLUE}[joehays-plugin:pre-up]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[joehays-plugin:pre-up]${NC} ✅ $*"
}

log_warning() {
    echo -e "${YELLOW}[joehays-plugin:pre-up]${NC} ⚠️  $*"
}

# Source plugin configuration for group settings
source "${MARS_PLUGIN_ROOT}/config.sh"

# =============================================================================
# Pre-flight Permission Checks
# =============================================================================

# Check if host permissions are set up correctly for E30 multi-instance access
# This catches permission issues BEFORE container startup fails silently
check_host_permissions() {
    local errors=0
    local current_user="$(id -un)"

    log_info "Checking host permissions for E30..."

    # Check 1: Group exists
    if ! getent group "${MARS_USER_CREDENTIALS_GROUP}" &>/dev/null; then
        log_warning "Group '${MARS_USER_CREDENTIALS_GROUP}' does not exist"
        errors=$((errors + 1))
    fi

    # Check 2: User is member of group (check /etc/group, not current session)
    if ! grep -q "^${MARS_USER_CREDENTIALS_GROUP}:.*:.*:.*${current_user}" /etc/group 2>/dev/null; then
        # Also check if user is primary group member
        local user_gid=$(id -g "$current_user" 2>/dev/null)
        local group_gid=$(getent group "${MARS_USER_CREDENTIALS_GROUP}" 2>/dev/null | cut -d: -f3)
        if [ "$user_gid" != "$group_gid" ]; then
            log_warning "User '${current_user}' is not a member of '${MARS_USER_CREDENTIALS_GROUP}' group"
            errors=$((errors + 1))
        fi
    fi

    # Check 3: Plugin directory has correct group
    local plugin_group=$(stat -c '%G' "${MARS_PLUGIN_ROOT}" 2>/dev/null || echo "unknown")
    if [ "$plugin_group" != "${MARS_USER_CREDENTIALS_GROUP}" ]; then
        log_warning "Plugin directory group is '${plugin_group}', expected '${MARS_USER_CREDENTIALS_GROUP}'"
        errors=$((errors + 1))
    fi

    # Check 4: Plugin directory has group write permission
    local plugin_perms=$(stat -c '%a' "${MARS_PLUGIN_ROOT}" 2>/dev/null || echo "000")
    local group_perm="${plugin_perms:1:1}"
    if [ $((group_perm & 2)) -eq 0 ]; then
        log_warning "Plugin directory missing group write permission"
        errors=$((errors + 1))
    fi

    # Report results
    if [ $errors -gt 0 ]; then
        echo ""
        log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_warning "Host permissions not configured for E30 multi-instance access"
        log_warning ""
        log_warning "Run this command to fix:"
        log_warning "  ${MARS_PLUGIN_ROOT}/hooks/host-permissions.sh"
        log_warning ""
        log_warning "Then log out/in (or: newgrp ${MARS_USER_CREDENTIALS_GROUP})"
        log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        # Don't fail - just warn. User may want to proceed anyway.
        # To make this a hard failure, uncomment: return 1
    else
        log_success "Host permissions OK (${MARS_USER_CREDENTIALS_GROUP} group configured)"
    fi

    return 0
}

# =============================================================================
# Configuration
# =============================================================================

ENABLE_CUSTOM_VOLUMES=true   # Set to false to disable custom volume mounting

# Paths (use parameter expansion to handle unbound variables)
# Generated file stays in plugin directory (mod-arch compliant)
# external-mounts.yml contains mounts for files OUTSIDE this plugin
# mounted-files/ contains files that LIVE in this plugin (auto-mounted by generate_auto_mounts)
EXTERNAL_MOUNTS="${MARS_PLUGIN_ROOT:-}/external-mounts.yml"
OVERRIDE_TARGET="${MARS_PLUGIN_ROOT:-}/generated/docker-compose.override.yml"

# Ensure generated directory exists
mkdir -p "${MARS_PLUGIN_ROOT:-}/generated"

# =============================================================================
# Auto-Mount Helper Functions (ADR-0011)
# =============================================================================

check_mount_mode() {
    local file="$1"
    local perms=$(stat -c '%a' "$file" 2>/dev/null)
    local owner_perm="${perms:0:1}"
    local group_perm="${perms:1:1}"

    # Check if owner OR group has write permission (bit 1 set)
    # Mount as rw if anyone can write, ro if nobody can write
    if [ $((owner_perm & 2)) -ne 0 ] || [ $((group_perm & 2)) -ne 0 ]; then
        echo "rw"
    else
        echo "ro"
    fi
}

validate_symlink() {
    local symlink="$1"
    local mounted_files_base="$2"
    local target=$(readlink "$symlink" 2>/dev/null)

    # Reject absolute paths (security risk)
    if [[ "$target" = /* ]]; then
        log_warning "Skipping absolute symlink: $symlink → $target"
        return 1
    fi

    # Resolve target and check if within mounted-files/
    local symlink_dir=$(dirname "$symlink")
    local target_abs=$(realpath -m "$symlink_dir/$target" 2>/dev/null)

    # Target must be within mounted-files/
    if [[ "$target_abs" != "$mounted_files_base"* ]]; then
        log_warning "Skipping symlink with external target: $symlink → $target"
        return 1
    fi

    # Check if target exists
    if [ ! -e "$target_abs" ]; then
        log_warning "Skipping symlink with missing target: $symlink → $target"
        return 1
    fi

    return 0
}

generate_symlink_command() {
    local symlink="$1"
    local mounted_files_base="$2"
    local target=$(readlink "$symlink")

    # Calculate absolute paths
    local symlink_dir=$(dirname "$symlink")
    local target_abs=$(realpath -m "$symlink_dir/$target")

    # Calculate container paths (strip mounted-files/ prefix)
    local container_symlink="/${symlink#$mounted_files_base/}"
    local container_target="/${target_abs#$mounted_files_base/}"

    # Generate command
    echo "ln -sf $container_target $container_symlink"
}

generate_auto_mounts() {
    local mounted_files_dir="$MARS_PLUGIN_ROOT/mounted-files"
    local symlink_script="/tmp/mars-plugin-symlinks.sh"

    # Check if mounted-files/ directory exists
    if [ ! -d "$mounted_files_dir" ]; then
        log_info "No mounted-files/ directory found - skipping auto-mount generation"
        return 0
    fi

    log_info "Scanning mounted-files/ for auto-mounts..."

    # Create temporary file for new mounts
    local temp_mounts="/tmp/mars-auto-mounts-$$.yml"
    echo "      # Auto-generated mounts from mounted-files/ (ADR-0011)" > "$temp_mounts"

    # Track which paths are already mounted (to avoid duplicate mounts)
    declare -A mounted_paths

    local mount_count=0

    # PHASE 1: Mount DIRECTORIES that contain files
    # This ensures file edits propagate (directory inodes don't change when files inside are edited)
    #
    # Strategy:
    # - "root/" and "home/*" are safe to mount entirely (user home directories)
    # - "usr/" should NOT be mounted entirely (would overlay system files)
    # - For other paths, mount at depth 2+ (e.g., usr/share/pixmaps/)
    while IFS= read -r -d '' dir; do
        # Skip the base mounted-files directory itself
        if [ "$dir" = "$mounted_files_dir" ]; then
            continue
        fi

        # Calculate relative path and container path
        local rel_path="${dir#$mounted_files_dir/}"
        local container_path="/$rel_path"

        # Determine if this directory should be mounted
        local should_mount=false

        # Special case: "root" directory - mount entirely (user's home)
        if [ "$rel_path" = "root" ]; then
            should_mount=true
        # Special case: "home/*" directories - mount user homes entirely
        elif [[ "$rel_path" =~ ^home/[^/]+$ ]]; then
            should_mount=true
        else
            # For other paths (like usr/), only mount at depth 2+
            local depth=$(echo "$rel_path" | tr -cd '/' | wc -c)
            if [ "$depth" -ge 2 ]; then
                # Check if directory has any regular files (not just subdirectories)
                local file_count=$(find "$dir" -maxdepth 1 -type f ! -name ".gitkeep" 2>/dev/null | wc -l)
                if [ "$file_count" -gt 0 ]; then
                    should_mount=true
                fi
            fi
        fi

        if [ "$should_mount" = true ]; then
            # Add directory mount
            echo "      - $dir:$container_path:rw" >> "$temp_mounts"
            mounted_paths["$rel_path"]=1
            mount_count=$((mount_count + 1))
            log_info "  Directory mount: $container_path"
        fi
    done < <(find "$mounted_files_dir" -type d -print0 2>/dev/null)

    # PHASE 2: Mount individual FILES that aren't inside already-mounted directories
    while IFS= read -r -d '' file; do
        # Skip .gitkeep files
        if [[ "$(basename "$file")" == ".gitkeep" ]]; then
            continue
        fi

        # Calculate relative path and container path
        local rel_path="${file#$mounted_files_dir/}"
        local container_path="/$rel_path"

        # Check if this file is inside an already-mounted directory
        local parent_dir=$(dirname "$rel_path")
        local skip=false
        while [ "$parent_dir" != "." ]; do
            if [ -n "${mounted_paths[$parent_dir]:-}" ]; then
                skip=true
                break
            fi
            parent_dir=$(dirname "$parent_dir")
        done

        if [ "$skip" = true ]; then
            continue
        fi

        # Determine mount mode
        local mode=$(check_mount_mode "$file")

        # Add mount line to temp file
        echo "      - $file:$container_path:$mode" >> "$temp_mounts"
        mount_count=$((mount_count + 1))
        log_info "  File mount: $container_path"
    done < <(find "$mounted_files_dir" -type f -print0 2>/dev/null)

    # Insert auto-generated mounts at the marker (before mars-runtime section)
    if [ $mount_count -gt 0 ]; then
        # Remove old auto-generated section if exists
        sed -i '/# Auto-generated mounts from mounted-files/,/^$/d' "$OVERRIDE_TARGET" 2>/dev/null || true

        # Insert new mounts at the marker position
        # This ensures mounts are part of mars-dev volumes (the YAML anchor source)
        if grep -q "# --- AUTO-MOUNTS-MARKER" "$OVERRIDE_TARGET"; then
            # Insert before the marker
            sed -i "/# --- AUTO-MOUNTS-MARKER/r $temp_mounts" "$OVERRIDE_TARGET"
            log_success "Generated $mount_count auto-mounts (inserted at marker)"
        else
            # Fallback: append to end (legacy behavior for old templates)
            cat "$temp_mounts" >> "$OVERRIDE_TARGET"
            log_success "Generated $mount_count auto-mounts (appended)"
        fi
    else
        log_info "No files found in mounted-files/ for auto-mounting"
    fi

    # Generate symlink creation script
    echo "#!/bin/bash" > "$symlink_script"
    echo "# Auto-generated symlink creation script (ADR-0011)" >> "$symlink_script"
    echo "# Generated at $(date)" >> "$symlink_script"
    echo "" >> "$symlink_script"

    # Find all symlinks
    local symlink_count=0
    while IFS= read -r -d '' symlink; do
        # Validate symlink
        if validate_symlink "$symlink" "$mounted_files_dir"; then
            # Generate symlink command
            generate_symlink_command "$symlink" "$mounted_files_dir" >> "$symlink_script"
            symlink_count=$((symlink_count + 1))
        fi
    done < <(find "$mounted_files_dir" -type l -print0 2>/dev/null)

    if [ $symlink_count -gt 0 ]; then
        # Make script executable
        chmod +x "$symlink_script"

        # Add symlink script mount to override file
        local symlink_mount="      - $symlink_script:/tmp/mars-plugin-symlinks.sh:ro"

        # For E6 template: insert before "# E30:" comment (volumes section belongs to mars-dev)
        # For E30 template: append to end (volumes section belongs to mars-runtime)
        if grep -q "# E30:" "$OVERRIDE_TARGET"; then
            # E6 template: insert before the E30 section
            sed -i "/# E30:/i\\$symlink_mount" "$OVERRIDE_TARGET"
        else
            # E30 template: append to volumes list
            echo "$symlink_mount" >> "$OVERRIDE_TARGET"
        fi
        log_success "Generated $symlink_count symlink commands"
    else
        log_info "No symlinks found in mounted-files/"
        # Clean up empty script
        rm -f "$symlink_script"
    fi

    # Cleanup temp files
    rm -f "$temp_mounts"

    log_success "Auto-mount generation complete"
}

# =============================================================================
# Main: Copy docker-compose override if enabled
# =============================================================================

main() {
    # Pre-flight: Check host permissions are configured
    # Skip if running inside container (container-startup handles that)
    if [ ! -f "/.dockerenv" ] && ! grep -q "docker\|lxc" /proc/1/cgroup 2>/dev/null; then
        check_host_permissions
    fi

    log_info "Checking for custom volume configuration..."

    # Check if custom volumes are enabled
    if [ "${ENABLE_CUSTOM_VOLUMES}" != true ]; then
        log_info "Custom volumes disabled (skipping override file)"
        return 0
    fi

    # Check if external-mounts.yml exists
    if [ ! -f "${EXTERNAL_MOUNTS}" ]; then
        log_warning "external-mounts.yml not found at: ${EXTERNAL_MOUNTS}"
        log_warning "Skipping external volume mount setup"
        return 0
    fi

    # Check if target already exists and is newer than source
    local skip_copy=false
    if [ -f "${OVERRIDE_TARGET}" ]; then
        if [ "${OVERRIDE_TARGET}" -nt "${EXTERNAL_MOUNTS}" ]; then
            log_info "Override file is up-to-date (no changes needed)"
            skip_copy=true
        fi
    fi

    # Copy external-mounts.yml to generated location if needed
    if [ "$skip_copy" = false ]; then
        log_info "Generating volume override configuration..."
        cp "${EXTERNAL_MOUNTS}" "${OVERRIDE_TARGET}"

        # Verify copy succeeded
        if [ -f "${OVERRIDE_TARGET}" ]; then
            log_success "Custom volume configuration generated"
            log_info "Generated: ${OVERRIDE_TARGET}"
            log_info "Edit to customize: ${EXTERNAL_MOUNTS}"
        else
            log_warning "Failed to create override file"
            return 1
        fi

    fi

    # Generate auto-mounts from mounted-files/ directory (ADR-0011)
    # Always run this, regardless of whether template was copied
    generate_auto_mounts
}

# Run main function
main
