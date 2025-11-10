#!/bin/bash
# =============================================================================
# hooks/setup-host-permissions.sh
# Setup joe-docs group and permissions on host for multi-instance access
#
# This script creates a dedicated group for personal credential files,
# allowing multiple container instances (mars-dev, mars-rt-*) to access
# mounted credentials via group permissions (no o+rwx needed).
#
# Execution context:
#   - Runs on HOST (not in container)
#   - Requires sudo for group creation
#   - Idempotent (safe to run multiple times)
#   - Called automatically by mars-env.config
# =============================================================================
set -euo pipefail

# =============================================================================
# Setup
# =============================================================================

# Get the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source plugin configuration
source "${PLUGIN_ROOT}/config.sh"

# Get current username reliably (works even if $USER is not set)
CURRENT_USER="$(id -un)"

# Source utilities for consistent logging
source "${SCRIPT_DIR}/scripts/utils.sh"

# Override log prefix
log_info() {
    echo -e "${BLUE}[joehays-plugin:host-permissions]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[joehays-plugin:host-permissions]${NC} ✅ $*"
}

log_warning() {
    echo -e "${YELLOW}[joehays-plugin:host-permissions]${NC} ⚠️  $*"
}

log_error() {
    echo -e "${RED}[joehays-plugin:host-permissions]${NC} ❌ $*"
}

# =============================================================================
# Main Setup Functions
# =============================================================================

# Create joe-docs group if it doesn't exist
setup_group() {
    log_info "Checking ${MARS_USER_CREDENTIALS_GROUP} group (GID ${MARS_USER_CREDENTIALS_GID})..."

    # Check if group already exists
    if getent group "${MARS_USER_CREDENTIALS_GROUP}" &>/dev/null; then
        local existing_gid
        existing_gid=$(getent group "${MARS_USER_CREDENTIALS_GROUP}" | cut -d: -f3)

        if [ "$existing_gid" = "${MARS_USER_CREDENTIALS_GID}" ]; then
            log_info "Group ${MARS_USER_CREDENTIALS_GROUP} already exists with correct GID ${MARS_USER_CREDENTIALS_GID}"
            return 0
        else
            log_error "Group ${MARS_USER_CREDENTIALS_GROUP} exists with wrong GID: $existing_gid (expected ${MARS_USER_CREDENTIALS_GID})"
            log_error "Please manually fix: sudo groupmod -g ${MARS_USER_CREDENTIALS_GID} ${MARS_USER_CREDENTIALS_GROUP}"
            return 1
        fi
    fi

    # Create group (requires sudo)
    log_info "Creating group ${MARS_USER_CREDENTIALS_GROUP} with GID ${MARS_USER_CREDENTIALS_GID}..."

    if sudo -n groupadd -g "${MARS_USER_CREDENTIALS_GID}" "${MARS_USER_CREDENTIALS_GROUP}" 2>/dev/null; then
        log_success "Created group ${MARS_USER_CREDENTIALS_GROUP}"
    elif sudo groupadd -g "${MARS_USER_CREDENTIALS_GID}" "${MARS_USER_CREDENTIALS_GROUP}"; then
        log_success "Created group ${MARS_USER_CREDENTIALS_GROUP}"
    else
        log_error "Failed to create group (sudo access required)"
        log_info "Manual setup: sudo groupadd -g ${MARS_USER_CREDENTIALS_GID} ${MARS_USER_CREDENTIALS_GROUP}"
        return 1
    fi
}

# Add current user to joe-docs group
setup_user_membership() {
    log_info "Checking user membership in ${MARS_USER_CREDENTIALS_GROUP}..."

    # Check if user is already in group
    if groups | grep -q "\b${MARS_USER_CREDENTIALS_GROUP}\b"; then
        log_info "User already in ${MARS_USER_CREDENTIALS_GROUP} group"
        return 0
    fi

    # Add user to group
    log_info "Adding ${CURRENT_USER} to ${MARS_USER_CREDENTIALS_GROUP} group..."

    # Check if user is local (in /etc/passwd) or Centrified (AD/LDAP)
    # Must check /etc/passwd directly, not getent (which queries all sources)
    if grep -q "^${CURRENT_USER}:" /etc/passwd; then
        # Local user - use usermod
        if sudo -n usermod -a -G "${MARS_USER_CREDENTIALS_GROUP}" "${CURRENT_USER}" 2>/dev/null; then
            log_success "Added ${CURRENT_USER} to ${MARS_USER_CREDENTIALS_GROUP} group (via usermod)"
            log_warning "Group membership activated on next login (or run: newgrp ${MARS_USER_CREDENTIALS_GROUP})"
        elif sudo usermod -a -G "${MARS_USER_CREDENTIALS_GROUP}" "${CURRENT_USER}"; then
            log_success "Added ${CURRENT_USER} to ${MARS_USER_CREDENTIALS_GROUP} group (via usermod)"
            log_warning "Group membership activated on next login (or run: newgrp ${MARS_USER_CREDENTIALS_GROUP})"
        else
            log_error "Failed to add user to group (sudo access required)"
            log_info "Manual setup: sudo usermod -a -G ${MARS_USER_CREDENTIALS_GROUP} ${CURRENT_USER}"
            return 1
        fi
    else
        # Centrified/AD user - directly edit /etc/group
        log_info "Detected Centrified/AD user - editing /etc/group directly..."

        # Get current group line
        local group_line
        group_line=$(getent group "${MARS_USER_CREDENTIALS_GROUP}")

        if [ -z "$group_line" ]; then
            log_error "Group ${MARS_USER_CREDENTIALS_GROUP} not found"
            return 1
        fi

        # Check if user is already in the group line
        if echo "$group_line" | grep -q ":${CURRENT_USER}\$\|:${CURRENT_USER},\|,${CURRENT_USER},\|,${CURRENT_USER}\$"; then
            log_info "User already in ${MARS_USER_CREDENTIALS_GROUP} group (in /etc/group)"
            return 0
        fi

        # Add user to group line
        # Group format: groupname:x:GID:user1,user2,user3
        if echo "$group_line" | grep -q ":[^:]*\$"; then
            # Group has existing members
            if sudo sed -i "s/^\(${MARS_USER_CREDENTIALS_GROUP}:[^:]*:[^:]*:\)\(.*\)$/\1\2,${CURRENT_USER}/" /etc/group; then
                log_success "Added ${CURRENT_USER} to ${MARS_USER_CREDENTIALS_GROUP} group (via /etc/group)"
                log_warning "Group membership activated on next login (or run: newgrp ${MARS_USER_CREDENTIALS_GROUP})"
            else
                log_error "Failed to edit /etc/group (sudo access required)"
                log_info "Manual setup: sudo sed -i 's/^\\(${MARS_USER_CREDENTIALS_GROUP}:[^:]*:[^:]*:\\)\\(.*\\)$/\\1\\2,${CURRENT_USER}/' /etc/group"
                return 1
            fi
        else
            # Group has no members yet
            if sudo sed -i "s/^\(${MARS_USER_CREDENTIALS_GROUP}:[^:]*:[^:]*:\)$/\1${CURRENT_USER}/" /etc/group; then
                log_success "Added ${CURRENT_USER} to ${MARS_USER_CREDENTIALS_GROUP} group (via /etc/group)"
                log_warning "Group membership activated on next login (or run: newgrp ${MARS_USER_CREDENTIALS_GROUP})"
            else
                log_error "Failed to edit /etc/group (sudo access required)"
                log_info "Manual setup: sudo sed -i 's/^\\(${MARS_USER_CREDENTIALS_GROUP}:[^:]*:[^:]*:\\)$/\\1${CURRENT_USER}/' /etc/group"
                return 1
            fi
        fi
    fi
}

# Set group ownership and permissions on credential files
setup_file_permissions() {
    log_info "Setting up credential file permissions..."

    # Check if credentials directory exists
    if [ ! -d "${MARS_USER_CREDENTIALS_DIR}" ]; then
        log_warning "Credentials directory not found: ${MARS_USER_CREDENTIALS_DIR}"
        log_warning "Skipping file permissions setup"
        return 0
    fi

    # List of credential files to update
    local files=(
        "${MARS_USER_CREDENTIALS_DIR}/get_capra_access_token.sh"
        "${MARS_USER_CREDENTIALS_DIR}/capra_access_token"
        "${MARS_USER_CREDENTIALS_DIR}/capra-api-key"
        "${MARS_USER_CREDENTIALS_DIR}/Certificates_PKCS7_v5_14_DoD/DoD_PKE_CA_chain.pem"
    )

    local updated_count=0
    local skipped_count=0

    for file in "${files[@]}"; do
        if [ ! -e "$file" ]; then
            log_info "File not found: $file (skipping)"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        # Check current group
        local current_group
        current_group=$(stat -c '%G' "$file" 2>/dev/null || echo "unknown")

        if [ "$current_group" = "${MARS_USER_CREDENTIALS_GROUP}" ]; then
            log_info "$(basename "$file"): already ${MARS_USER_CREDENTIALS_GROUP} group"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        # Update group ownership
        log_info "$(basename "$file"): setting group to ${MARS_USER_CREDENTIALS_GROUP}..."

        if sudo chgrp "${MARS_USER_CREDENTIALS_GROUP}" "$file" 2>/dev/null; then
            # Set appropriate permissions based on file type
            if [[ "$file" == *.sh ]]; then
                sudo chmod 750 "$file"  # Scripts: -rwxr-x---
                log_success "$(basename "$file"): updated (executable)"
            elif [[ "$file" == *_token || "$file" == *-key ]]; then
                sudo chmod 640 "$file"  # Secrets: -rw-r-----
                log_success "$(basename "$file"): updated (secret)"
            else
                sudo chmod 644 "$file"  # Certs/others: -rw-r--r--
                log_success "$(basename "$file"): updated (readable)"
            fi
            updated_count=$((updated_count + 1))
        else
            log_warning "$(basename "$file"): failed to update (permission denied)"
            skipped_count=$((skipped_count + 1))
        fi
    done

    # Summary
    if [ $updated_count -gt 0 ]; then
        log_success "Updated $updated_count credential file(s)"
    fi
    if [ $skipped_count -gt 0 ]; then
        log_info "Skipped $skipped_count file(s) (already correct or missing)"
    fi
}

# =============================================================================
# Quick Check (for mars-env.config fast path)
# =============================================================================
quick_check() {
    # If user is already in the credentials group IN /etc/group, everything is likely set up
    # Check /etc/group directly, not current shell session (which may not have activated group)
    if grep -q "^${MARS_USER_CREDENTIALS_GROUP}:.*:.*:.*${CURRENT_USER}" /etc/group 2>/dev/null; then
        return 0  # Already setup
    fi
    return 1  # Needs setup
}

# =============================================================================
# Main
# =============================================================================
main() {
    # Skip if running inside container (this hook is for host only)
    if [ -f "/.dockerenv" ] || grep -q "docker\|lxc" /proc/1/cgroup 2>/dev/null; then
        # Inside container - skip host permissions setup
        return 0
    fi

    # Quick check: If already set up, exit silently (fast path for mars-env.config)
    if quick_check; then
        # Silently exit - already configured
        return 0
    fi

    log_info "Setting up host permissions for multi-instance credential access..."
    echo ""

    # Step 1: Create group
    if ! setup_group; then
        log_error "Group setup failed"
        return 1
    fi
    echo ""

    # Step 2: Add user to group
    if ! setup_user_membership; then
        log_error "User membership setup failed"
        return 1
    fi
    echo ""

    # Step 3: Set file permissions
    if ! setup_file_permissions; then
        log_warning "File permissions setup incomplete (some files may need manual updates)"
    fi
    echo ""

    log_success "Host permissions setup complete!"
    echo ""
    log_info "Summary:"
    log_info "  - Group: ${MARS_USER_CREDENTIALS_GROUP} (GID ${MARS_USER_CREDENTIALS_GID})"
    log_info "  - Member: ${USER}"
    log_info "  - Files: ${MARS_USER_CREDENTIALS_DIR}"
    echo ""
    log_info "Containers will create joe-docs group with Sysbox-adjusted GID"
    log_info "Container mars user will have access to mounted credential files"
}

# Run main function
main "$@"
