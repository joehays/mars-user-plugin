#!/bin/bash
# =============================================================================
# hooks/container-startup.sh
# Container-startup hook: Create symlinks for multi-user plugin access
#
# Execution context:
#   - Runs INSIDE CONTAINER at startup (via entrypoint.sh)
#   - Working directory: /workspace/mars-v2
#   - MARS_PLUGIN_ROOT: Path to this plugin directory (container paths)
#   - MARS_REPO_ROOT: Path to MARS repository (/workspace/mars-v2)
#   - User: root (running as container root during entrypoint)
#
# Purpose:
#   Creates symlinks so plugin files mounted at /root/dev are accessible
#   to the non-root 'mars' user via /home/mars/dev
# =============================================================================
set -euo pipefail

# =============================================================================
# Setup
# =============================================================================

# Get the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities for consistent logging
source "${SCRIPT_DIR}/scripts/utils.sh"

# Source plugin configuration
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
source "${PLUGIN_ROOT}/config.sh"

# Override log function prefix for container-startup context
log_info() {
    echo -e "${BLUE}[joehays-plugin:container-startup]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[joehays-plugin:container-startup]${NC} ✅ $*"
}

log_warning() {
    echo -e "${YELLOW}[joehays-plugin:container-startup]${NC} ⚠️  $*"
}

# =============================================================================
# Configuration
# =============================================================================
# Paths that need to be symlinked for multi-user access
# Format: "source:target" where source is the real path, target is the symlink
declare -a SYMLINK_PAIRS=(
    "/root/dev:/home/mars/dev"
    "/root/docs:/home/mars/docs"
    "/workspace/mars-v2:/root/dev/mars-v2"
)

# =============================================================================
# Zellij Layout Symlink Setup (Root User Only)
# =============================================================================
setup_zellij_layout_symlink() {
    log_info "Setting up Zellij layout symlink..."

    local ZELLIJ_LAYOUT_SOURCE="/workspace/mars-v2/external/mars-user-plugin/mars-dev-zellij.kdl"
    local ZELLIJ_LAYOUT_TARGET="/root/.config/zellij/layouts/mars-dev-zellij.kdl"

    # Check if source layout exists
    if [ ! -f "${ZELLIJ_LAYOUT_SOURCE}" ]; then
        log_warning "Zellij layout not found at: ${ZELLIJ_LAYOUT_SOURCE}"
        log_warning "Skipping Zellij layout symlink setup"
        return 0
    fi

    # Create target directory if it doesn't exist
    mkdir -p "$(dirname "${ZELLIJ_LAYOUT_TARGET}")"

    # Check if symlink already exists and is correct
    if [ -L "${ZELLIJ_LAYOUT_TARGET}" ] && [ "$(readlink -f "${ZELLIJ_LAYOUT_TARGET}")" = "${ZELLIJ_LAYOUT_SOURCE}" ]; then
        log_info "Zellij layout symlink already correct: ${ZELLIJ_LAYOUT_TARGET}"
        return 0
    fi

    # Remove existing symlink/file if it exists
    rm -f "${ZELLIJ_LAYOUT_TARGET}"

    # Create symlink
    ln -s "${ZELLIJ_LAYOUT_SOURCE}" "${ZELLIJ_LAYOUT_TARGET}"

    log_success "Created Zellij layout symlink: ${ZELLIJ_LAYOUT_TARGET} → ${ZELLIJ_LAYOUT_SOURCE}"
}

# =============================================================================
# LazyVim First-Run Setup
# =============================================================================
setup_lazyvim_first_run() {
    # Only run if nvim config is mounted and nvim is installed
    if [ ! -d "/root/.config/nvim" ] || ! command -v nvim &>/dev/null; then
        return 0
    fi

    # Check if treesitter parsers are installed (marker for first run)
    # If parser directory doesn't exist or is empty, this is first launch
    if [ ! -d "$HOME/.local/share/nvim/lazy/nvim-treesitter/parser" ] || \
       [ -z "$(ls -A $HOME/.local/share/nvim/lazy/nvim-treesitter/parser 2>/dev/null)" ]; then
        log_info "First-run LazyVim setup detected"
        log_info "Installing Lazy plugins and treesitter parsers..."
        log_info "This may take 1-2 minutes on first launch..."

        # Clean up any stale temp directories from interrupted installations
        rm -rf ~/.local/share/nvim/lazy/nvim-treesitter/tree-sitter-*-tmp/ 2>/dev/null || true

        # Install all plugins and parsers (headless mode, non-interactive)
        nvim --headless "+Lazy! sync" "+TSUpdateSync" +qa 2>&1 | grep -v "^$" || true

        log_success "LazyVim plugins and treesitter parsers installed"
    fi
}

# =============================================================================
# Credentials Group Setup (joe-docs)
# =============================================================================
setup_credentials_group() {
    log_info "Setting up credentials group for multi-instance access..."

    # Get HOST_UID from environment (set by mars-env.config or docker-compose)
    local host_uid="${HOST_UID:-10227}"

    # Calculate Sysbox-adjusted GID
    # Container GID = Host GID - HOST_UID (due to Sysbox offset mapping)
    local container_gid=$((MARS_USER_CREDENTIALS_GID - host_uid))

    log_info "Creating ${MARS_USER_CREDENTIALS_GROUP} group (container GID: ${container_gid}, maps to host GID: ${MARS_USER_CREDENTIALS_GID})..."

    # Check if group already exists
    if getent group "${MARS_USER_CREDENTIALS_GROUP}" &>/dev/null; then
        local existing_gid
        existing_gid=$(getent group "${MARS_USER_CREDENTIALS_GROUP}" | cut -d: -f3)

        if [ "$existing_gid" = "$container_gid" ]; then
            log_info "Group ${MARS_USER_CREDENTIALS_GROUP} already exists with correct GID"
        else
            log_warning "Group ${MARS_USER_CREDENTIALS_GROUP} exists with wrong GID: $existing_gid (expected $container_gid)"
            log_warning "Recreating group..."
            groupdel "${MARS_USER_CREDENTIALS_GROUP}" 2>/dev/null || true
            groupadd -g "$container_gid" "${MARS_USER_CREDENTIALS_GROUP}"
            log_success "Recreated group ${MARS_USER_CREDENTIALS_GROUP}"
        fi
    else
        # Create group with Sysbox-adjusted GID
        groupadd -g "$container_gid" "${MARS_USER_CREDENTIALS_GROUP}"
        log_success "Created group ${MARS_USER_CREDENTIALS_GROUP} (GID: ${container_gid})"
    fi

    # Add mars user to joe-docs group
    log_info "Adding mars user to ${MARS_USER_CREDENTIALS_GROUP} group..."

    if id mars &>/dev/null; then
        if groups mars | grep -q "\b${MARS_USER_CREDENTIALS_GROUP}\b"; then
            log_info "mars user already in ${MARS_USER_CREDENTIALS_GROUP} group"
        else
            usermod -a -G "${MARS_USER_CREDENTIALS_GROUP}" mars
            log_success "Added mars user to ${MARS_USER_CREDENTIALS_GROUP} group"
        fi
    else
        log_warning "mars user not found - skipping group membership"
    fi

    # Verify setup
    log_info "Verifying credentials group setup..."
    if getent group "${MARS_USER_CREDENTIALS_GROUP}" | grep -q mars; then
        log_success "Credentials group ready: mars user has access to mounted credential files"
    else
        log_warning "Credentials group verification incomplete"
    fi
}

# =============================================================================
# /root/dev Permissions Fix (Issue #3)
# =============================================================================
# Fix permissions on /root/dev directory for multi-user access
# Docker creates this directory during volume mounts with root:root ownership
# We need mars-dev group and group rwx permissions for mars user access
fix_root_dev_permissions() {
    if [ ! -d "/root/dev" ]; then
        log_info "/root/dev does not exist - skipping permission fix"
        return 0
    fi

    log_info "Fixing /root/dev permissions for multi-user access..."

    # Set group to mars-dev and add group write/execute
    if chgrp mars-dev /root/dev 2>/dev/null; then
        log_success "Changed /root/dev group to mars-dev"
    else
        log_warning "Failed to change group ownership on /root/dev"
        return 1
    fi

    if chmod g+rwx /root/dev 2>/dev/null; then
        log_success "Added group rwx permissions to /root/dev"
    else
        log_warning "Failed to set group permissions on /root/dev"
        return 1
    fi

    log_success "/root/dev now accessible to mars user via mars-dev group"
}

# =============================================================================
# Auto-Symlink Creation from mounted-files/ (ADR-0011)
# =============================================================================
create_auto_symlinks() {
    local symlink_script="/tmp/mars-plugin-symlinks.sh"

    # Check if symlink script exists
    if [ ! -f "$symlink_script" ]; then
        # No symlinks to create (not an error)
        return 0
    fi

    # Check if script is executable
    if [ ! -x "$symlink_script" ]; then
        chmod +x "$symlink_script"
    fi

    log_info "Creating auto-symlinks from mounted-files/..."

    # Execute symlink script
    if bash "$symlink_script"; then
        log_success "Auto-symlinks created successfully"
    else
        log_warning "Failed to create auto-symlinks (exit code: $?)"
        return 1
    fi

    # Verify symlinks were created
    local symlink_count=$(grep -c "^ln -sf" "$symlink_script" 2>/dev/null || echo "0")
    log_info "Created $symlink_count symlinks in container"

    return 0
}

# =============================================================================
# TurboVNC IceWM Desktop File Symlink
# =============================================================================
# TurboVNC's -wm option looks for <wm_name>.desktop in /usr/share/xsessions/
# When using -wm icewm-session, it looks for icewm.desktop (strips -session)
# but the actual file is icewm-session.desktop. Create symlink to fix this.
setup_icewm_desktop_symlink() {
    local xsessions_dir="/usr/share/xsessions"
    local source_desktop="${xsessions_dir}/icewm-session.desktop"
    local target_desktop="${xsessions_dir}/icewm.desktop"

    # Skip if xsessions directory doesn't exist (VNC not installed)
    if [ ! -d "$xsessions_dir" ]; then
        return 0
    fi

    # Skip if source doesn't exist
    if [ ! -f "$source_desktop" ]; then
        return 0
    fi

    # Skip if symlink already exists and is correct
    if [ -L "$target_desktop" ] && [ "$(readlink -f "$target_desktop")" = "$source_desktop" ]; then
        log_info "IceWM desktop symlink already correct"
        return 0
    fi

    # Create symlink
    ln -sf "$source_desktop" "$target_desktop"
    log_success "Created IceWM desktop symlink: icewm.desktop -> icewm-session.desktop"
}

# =============================================================================
# SSH Authorized Keys Setup
# =============================================================================
setup_authorized_keys() {
    local ssh_dir="/root/.ssh"
    local authorized_keys="${ssh_dir}/authorized_keys"
    local public_key="${ssh_dir}/my_remote_id_ed25519.pub"  # Auto-mounted from mounted-files/

    # Check if public key file exists
    if [ ! -f "$public_key" ]; then
        log_info "No public key found at $public_key (skipping authorized_keys setup)"
        return 0
    fi

    log_info "Setting up authorized_keys for SSH access..."

    # Create .ssh directory if it doesn't exist
    if [ ! -d "$ssh_dir" ]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        log_info "Created $ssh_dir directory"
    fi

    # Create authorized_keys if it doesn't exist
    if [ ! -f "$authorized_keys" ]; then
        touch "$authorized_keys"
        chmod 600 "$authorized_keys"
        log_info "Created $authorized_keys file"
    fi

    # Read the public key content
    local key_content=$(cat "$public_key")

    # Check if key already exists (idempotency)
    if grep -Fq "$key_content" "$authorized_keys" 2>/dev/null; then
        log_info "Public key already in authorized_keys"
        return 0
    fi

    # Append public key to authorized_keys
    echo "$key_content" >> "$authorized_keys"
    chmod 600 "$authorized_keys"

    log_success "Added public key from my_remote_id_ed25519.pub to authorized_keys"
}

# =============================================================================
# Fix SSH File Permissions and Ownership
# =============================================================================
fix_ssh_permissions() {
    log_info "Fixing SSH file permissions and ownership for strict SSH policy compliance..."

    local fixed_count=0

    # Check both root and mars .ssh directories
    for ssh_dir in "/root/.ssh" "/home/mars/.ssh"; do
        if [ ! -d "$ssh_dir" ]; then
            continue
        fi

        # Determine correct owner for this directory
        local owner="root"
        if [[ "$ssh_dir" == "/home/mars/.ssh" ]]; then
            owner="mars"
        fi

        # Fix directory permissions (must be 700) and ownership
        # Note: chown may fail on bind-mounted files from host - that's OK
        chown "$owner:$owner" "$ssh_dir" 2>/dev/null || true
        if [ "$(stat -c %a "$ssh_dir")" != "700" ]; then
            chmod 700 "$ssh_dir" 2>/dev/null && {
                log_success "Fixed $ssh_dir directory permissions to 700"
                fixed_count=$((fixed_count + 1))
            }
        fi

        # Fix config file (must be 600 and owned by user)
        if [ -f "$ssh_dir/config" ]; then
            chown "$owner:$owner" "$ssh_dir/config" 2>/dev/null || true
            if [ "$(stat -c %a "$ssh_dir/config")" != "600" ]; then
                chmod 600 "$ssh_dir/config" 2>/dev/null && {
                    log_success "Fixed $ssh_dir/config permissions to 600"
                    fixed_count=$((fixed_count + 1))
                }
            fi
        fi

        # Fix authorized_keys (must be 600 and owned by user)
        if [ -f "$ssh_dir/authorized_keys" ]; then
            chown "$owner:$owner" "$ssh_dir/authorized_keys" 2>/dev/null || true
            if [ "$(stat -c %a "$ssh_dir/authorized_keys")" != "600" ]; then
                chmod 600 "$ssh_dir/authorized_keys" 2>/dev/null && {
                    log_success "Fixed $ssh_dir/authorized_keys permissions to 600"
                    fixed_count=$((fixed_count + 1))
                }
            fi
        fi

        # Fix any private keys (must be 600 and owned by user)
        # Use nullglob to avoid literal glob strings if no files match
        shopt -s nullglob
        for key in "$ssh_dir"/*_id_* "$ssh_dir"/id_*; do
            # Skip if key is a public key file
            case "$key" in
                *.pub) continue ;;
            esac

            if [ -f "$key" ]; then
                chown "$owner:$owner" "$key" 2>/dev/null || true
                if [ "$(stat -c %a "$key")" != "600" ]; then
                    chmod 600 "$key" 2>/dev/null && {
                        log_success "Fixed $(basename "$key") permissions to 600"
                        fixed_count=$((fixed_count + 1))
                    }
                fi
            fi
        done
        shopt -u nullglob
    done

    if [ $fixed_count -gt 0 ]; then
        log_success "Fixed $fixed_count SSH permission issues"
    else
        log_info "All SSH permissions already correct"
    fi
}

# =============================================================================
# Main: Create symlinks for multi-user access
# =============================================================================
main() {
    log_info "Setting up multi-user plugin access..."

    # Setup credentials group first (needed for file access)
    setup_credentials_group
    echo ""

    # Fix /root/dev permissions (Issue #3)
    fix_root_dev_permissions
    echo ""

    # Check if mars user exists
    if ! id mars &>/dev/null; then
        log_warning "mars user not found - skipping symlink creation"
        return 0
    fi

    local created_count=0
    local skipped_count=0

    # Process each symlink pair
    for pair in "${SYMLINK_PAIRS[@]}"; do
        local source="${pair%%:*}"
        local target="${pair##*:}"

        # Skip if source doesn't exist
        if [ ! -e "$source" ]; then
            log_info "Source does not exist: $source (skipping)"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        # Skip if target already exists and points to correct location
        if [ -L "$target" ]; then
            local current_target
            current_target=$(readlink "$target")
            if [ "$current_target" = "$source" ]; then
                log_info "Symlink already correct: $target → $source"
                skipped_count=$((skipped_count + 1))
                continue
            else
                log_warning "Symlink exists but points to wrong location: $target → $current_target"
                log_info "Removing incorrect symlink..."
                rm -f "$target"
            fi
        elif [ -e "$target" ]; then
            log_warning "Target exists as regular file/directory: $target"
            log_warning "Skipping (manual intervention required)"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        # Create parent directory if needed
        local target_dir
        target_dir=$(dirname "$target")
        if [ ! -d "$target_dir" ]; then
            mkdir -p "$target_dir"
            log_info "Created directory: $target_dir"
        fi

        # Create symlink
        ln -s "$source" "$target"

        # Fix ownership (symlinks should be owned by mars:mars-dev for proper group access)
        chown -h mars:mars-dev "$target" 2>/dev/null || true

        log_success "Created symlink: $target → $source"
        created_count=$((created_count + 1))
    done

    # Fix ownership on all symlinks (including pre-existing ones)
    log_info "Ensuring correct ownership on all symlinks..."
    for pair in "${SYMLINK_PAIRS[@]}"; do
        local target="${pair##*:}"
        if [ -L "$target" ]; then
            chown -h mars:mars-dev "$target" 2>/dev/null || true
        fi
    done

    # Summary
    if [ $created_count -gt 0 ]; then
        log_success "Created $created_count symlink(s) for multi-user access"
    fi
    if [ $skipped_count -gt 0 ]; then
        log_info "Skipped $skipped_count symlink(s) (already exist or source missing)"
    fi

    # Verify accessibility
    log_info "Verifying plugin accessibility..."
    if [ -d "/root/dev" ] && [ -L "/home/mars/dev" ]; then
        log_success "Plugin files accessible to both root and mars users"
    else
        log_warning "Plugin accessibility verification failed"
    fi

    # Setup Zellij layout symlink
    setup_zellij_layout_symlink

    # Run LazyVim first-run setup if needed
    setup_lazyvim_first_run

    # Create auto-symlinks from mounted-files/ directory (ADR-0011)
    echo ""
    create_auto_symlinks

    # Setup SSH authorized_keys for remote access
    echo ""
    setup_authorized_keys

    # Fix SSH file permissions for strict SSH policy compliance
    echo ""
    fix_ssh_permissions

    # Setup IceWM desktop symlink for TurboVNC
    echo ""
    setup_icewm_desktop_symlink
}

# Run main function
main
