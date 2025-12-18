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
)

# =============================================================================
# Zellij Layout Symlink Setup (Root User Only)
# =============================================================================
setup_zellij_layout_symlink() {
  log_info "Setting up Zellij layout symlink..."

  local ZELLIJ_LAYOUT_SOURCE="/workspace/mars-user-plugin/mars-dev-zellij.kdl"
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
  if [ ! -d "$HOME/.local/share/nvim/lazy/nvim-treesitter/parser" ] ||
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
# SSH Authorized Keys Setup
# =============================================================================
setup_authorized_keys() {
  local ssh_dir="/root/.ssh"
  local authorized_keys="${ssh_dir}/authorized_keys"
  local public_key="${ssh_dir}/my_remote_id_ed25519.pub" # Auto-mounted from mounted-files/

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
  echo "$key_content" >>"$authorized_keys"
  chmod 600 "$authorized_keys"

  log_success "Added public key from my_remote_id_ed25519.pub to authorized_keys"
}

# =============================================================================
# Setup XDG_RUNTIME_DIR for mars user
# =============================================================================
# Creates /run/user/<uid> directory for the mars user.
# Required by applications that use XDG_RUNTIME_DIR (like mars-claude wrapper).
# This directory is normally created by systemd-logind on login, but containers
# don't have systemd-logind running.
setup_xdg_runtime_dir() {
  log_info "Setting up XDG_RUNTIME_DIR for mars user..."

  # Get mars user UID
  local mars_uid
  if ! mars_uid=$(id -u mars 2>/dev/null); then
    log_warning "mars user not found - skipping XDG_RUNTIME_DIR setup"
    return 0
  fi

  local runtime_dir="/run/user/${mars_uid}"

  # Create directory if it doesn't exist
  if [ -d "$runtime_dir" ]; then
    log_info "XDG_RUNTIME_DIR already exists: $runtime_dir"
  else
    mkdir -p "$runtime_dir"
    chown mars:mars-dev "$runtime_dir"
    chmod 700 "$runtime_dir"
    log_success "Created XDG_RUNTIME_DIR: $runtime_dir"
  fi

  # Also create for root user (UID 0)
  local root_runtime_dir="/run/user/0"
  if [ ! -d "$root_runtime_dir" ]; then
    mkdir -p "$root_runtime_dir"
    chown root:root "$root_runtime_dir"
    chmod 700 "$root_runtime_dir"
    log_success "Created XDG_RUNTIME_DIR for root: $root_runtime_dir"
  fi
}

# =============================================================================
# Copy SSH Keys from /root/.ssh to /home/mars/.ssh with Correct Ownership
# =============================================================================
# Bind mounts cannot change ownership (kernel limitation).
# Solution: Copy SSH keys from /root/.ssh to /home/mars/.ssh at startup.
# This creates mars-owned copies for SSH to work with StrictModes.
#
# The mars user will use these copies for SSH operations.
# Root can still use the original bind-mounted files in /root/.ssh.
copy_ssh_keys_for_mars_user() {
  log_info "Copying SSH keys from /root/.ssh to /home/mars/.ssh with correct ownership..."

  local root_ssh="/root/.ssh"
  local mars_ssh="/home/mars/.ssh"
  local copied_count=0

  # Check if source SSH directory exists
  if [ ! -d "$root_ssh" ]; then
    log_info "No /root/.ssh directory - skipping SSH key copy"
    return 0
  fi

  # Check if mars user exists
  if ! id mars &>/dev/null; then
    log_warning "mars user not found - skipping SSH key copy"
    return 0
  fi

  # Create /home/mars/.ssh if it doesn't exist
  if [ ! -d "$mars_ssh" ]; then
    mkdir -p "$mars_ssh"
    chown mars:mars-dev "$mars_ssh"
    chmod 700 "$mars_ssh"
    log_info "Created $mars_ssh directory"
  fi

  # Copy SSH private keys
  shopt -s nullglob
  for key_file in "$root_ssh"/id_* "$root_ssh"/*_id_*; do
    # Skip if not a file
    [ -f "$key_file" ] || continue
    # Skip public keys
    [[ "$key_file" == *.pub ]] && continue

    local key_name=$(basename "$key_file")
    local target_key="$mars_ssh/$key_name"

    # Copy the key file
    cp "$key_file" "$target_key"
    chown mars:mars-dev "$target_key"
    chmod 600 "$target_key"
    log_success "Copied $key_name to $mars_ssh (mars-owned)"
    copied_count=$((copied_count + 1))

    # Also copy the public key if it exists
    if [ -f "${key_file}.pub" ]; then
      cp "${key_file}.pub" "${target_key}.pub"
      chown mars:mars-dev "${target_key}.pub"
      chmod 644 "${target_key}.pub"
    fi
  done
  shopt -u nullglob

  # Copy SSH config if it exists
  if [ -f "$root_ssh/config" ]; then
    cp "$root_ssh/config" "$mars_ssh/config"
    chown mars:mars-dev "$mars_ssh/config"
    chmod 600 "$mars_ssh/config"
    log_success "Copied SSH config to $mars_ssh (mars-owned)"
    copied_count=$((copied_count + 1))
  fi

  # Copy known_hosts if it exists
  if [ -f "$root_ssh/known_hosts" ]; then
    cp "$root_ssh/known_hosts" "$mars_ssh/known_hosts"
    chown mars:mars-dev "$mars_ssh/known_hosts"
    chmod 644 "$mars_ssh/known_hosts"
    log_info "Copied known_hosts to $mars_ssh"
  fi

  if [ $copied_count -gt 0 ]; then
    log_success "Copied $copied_count SSH items to /home/mars/.ssh with mars ownership"
  else
    log_info "No SSH keys found to copy"
  fi
}

# =============================================================================
# Setup /home/mars Symlinks to /root/
# =============================================================================
# Instead of bind-mounting files to /home/mars (which have wrong ownership due
# to Sysbox UID mapping), we mount to /root/ and create symlinks.
#
# Architecture:
# - Host files mounted to /root/.bashrc, /root/.zshrc, /root/.ssh/, etc.
# - Symlinks: /home/mars/.bashrc -> /root/.bashrc, etc.
# - mars user follows symlinks to access the (root-owned) files
# - This works because file content is accessed, not ownership checked
#
# Note: SSH is special - it requires strict ownership. For SSH, we either:
# - Accept that mars user uses /root/.ssh (via symlink)
# - Or copy files with correct ownership (loses sync with host)
setup_home_mars_symlinks() {
  log_info "Setting up /home/mars symlinks to /root/ files..."

  local created_count=0

  # Ensure /home/mars exists
  if [ ! -d "/home/mars" ]; then
    log_warning "/home/mars does not exist - skipping symlink setup"
    return 0
  fi

  # RC files to symlink
  local rc_files=(".bashrc" ".zshrc" ".common_shrc" ".local_rc" ".vimrc" ".Xresources")

  for rc_file in "${rc_files[@]}"; do
    local source="/root/${rc_file}"
    local target="/home/mars/${rc_file}"

    # Skip if source doesn't exist
    if [ ! -e "$source" ]; then
      continue
    fi

    # Skip if target is already a correct symlink
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
      continue
    fi

    # Remove existing file/symlink if it exists
    if [ -e "$target" ] || [ -L "$target" ]; then
      rm -f "$target"
    fi

    # Create symlink
    ln -s "$source" "$target"
    chown -h mars:mars-dev "$target" 2>/dev/null || true
    log_success "Created symlink: $target -> $source"
    created_count=$((created_count + 1))
  done

  # SSH directory - special handling
  # For SSH to work with mars user, we need mars to own the key files
  # But bind mounts from host appear as root. Solution options:
  # 1. Symlink /home/mars/.ssh -> /root/.ssh (mars accesses root's SSH)
  # 2. Copy files to /home/mars/.ssh with correct ownership
  #
  # We use option 1 (symlink) for simplicity - mars uses root's SSH config
  if [ -d "/root/.ssh" ]; then
    local ssh_target="/home/mars/.ssh"

    # If /home/mars/.ssh exists as a directory (not symlink), we have bind mounts
    # Don't replace with symlink - the files are already mounted there
    if [ -d "$ssh_target" ] && [ ! -L "$ssh_target" ]; then
      log_info "/home/mars/.ssh exists as directory (bind mounts) - not replacing with symlink"
    elif [ ! -e "$ssh_target" ]; then
      # No .ssh dir - create symlink to /root/.ssh
      ln -s "/root/.ssh" "$ssh_target"
      chown -h mars:mars-dev "$ssh_target" 2>/dev/null || true
      log_success "Created symlink: $ssh_target -> /root/.ssh"
      created_count=$((created_count + 1))
    fi
  fi

  # Config directories
  for config_dir in ".config" ".local" ".cache"; do
    local source="/root/${config_dir}"
    local target="/home/mars/${config_dir}"

    # Skip if source doesn't exist
    if [ ! -d "$source" ]; then
      continue
    fi

    # Skip if target exists (may have bind mounts or real files)
    if [ -e "$target" ]; then
      continue
    fi

    # Create symlink
    ln -s "$source" "$target"
    chown -h mars:mars-dev "$target" 2>/dev/null || true
    log_success "Created symlink: $target -> $source"
    created_count=$((created_count + 1))
  done

  if [ $created_count -gt 0 ]; then
    log_success "Created $created_count symlinks from /home/mars/ to /root/"
  else
    log_info "All /home/mars symlinks already in place"
  fi
}

# =============================================================================
# Fix /home/mars Directory Ownership
# =============================================================================
# Bind-mounted files from host retain their host UID due to Sysbox UID mapping.
# Host UID 1000 (joehays) -> Container UID 0 (root) due to Sysbox offset.
# This means bind-mounted files appear as root:root inside the container.
#
# For /home/mars to work properly for the mars user, we need to:
# 1. Fix ownership on directories we can modify
# 2. Accept that bind-mounted files will remain root-owned (SSH will still work
#    if permissions are correct and config allows)
# 3. Create copies of critical files that MUST be mars-owned (like .ssh/config)
fix_home_mars_ownership() {
  log_info "Fixing /home/mars directory ownership for mars user..."

  local fixed_count=0

  # Ensure /home/mars exists
  if [ ! -d "/home/mars" ]; then
    log_warning "/home/mars does not exist - skipping ownership fix"
    return 0
  fi

  # Fix ownership on /home/mars directory itself
  if chown mars:mars-dev /home/mars 2>/dev/null; then
    log_success "Fixed /home/mars ownership"
    fixed_count=$((fixed_count + 1))
  fi

  # Fix ownership on subdirectories that we can modify
  # Note: bind-mounted files/dirs will fail silently - that's expected
  for subdir in .ssh .config .local .cache; do
    local dir="/home/mars/$subdir"
    if [ -d "$dir" ]; then
      # Try to chown the directory - may fail for bind mounts
      chown mars:mars-dev "$dir" 2>/dev/null && {
        fixed_count=$((fixed_count + 1))
      }
    fi
  done

  # For SSH to work with mars user, we need special handling:
  # SSH requires that ~/.ssh and files inside are owned by the user
  # For bind-mounted files, we create a COPY that is properly owned
  local mars_ssh="/home/mars/.ssh"
  if [ -d "$mars_ssh" ]; then
    # Ensure directory permissions are correct
    chmod 700 "$mars_ssh" 2>/dev/null || true

    # Handle SSH config - if bind-mounted and wrong owner, create a copy
    if [ -f "$mars_ssh/config" ]; then
      local owner
      owner=$(stat -c '%U' "$mars_ssh/config" 2>/dev/null || echo "unknown")
      if [ "$owner" != "mars" ]; then
        # Check if this is a bind mount by trying to chown
        if ! chown mars:mars-dev "$mars_ssh/config" 2>/dev/null; then
          # It's a bind mount - create a copy
          log_info "SSH config is bind-mounted as root - creating mars-owned copy"
          local config_content
          config_content=$(cat "$mars_ssh/config")
          # Create temp file, write content, move into place
          local temp_config="/tmp/mars-ssh-config-$$"
          echo "$config_content" > "$temp_config"
          # Unmount the bind mount by overlaying with a new file
          # This requires we copy to a temp location first, then back
          cp "$mars_ssh/config" "$temp_config"
          # We can't unmount, but we can create a separate config
          # SSH uses StrictModes which requires owner match
          # Best solution: document this limitation
          log_warning "Cannot fix bind-mounted SSH config ownership"
          log_warning "SSH as mars user may fail with StrictModes enabled"
          log_warning "Workaround: Add 'StrictModes no' to sshd_config, or"
          log_warning "mount the config file to /root/.ssh/config only"
          rm -f "$temp_config"
        else
          chmod 600 "$mars_ssh/config" 2>/dev/null || true
          log_success "Fixed /home/mars/.ssh/config ownership"
          fixed_count=$((fixed_count + 1))
        fi
      fi
    fi

    # Handle SSH keys - same approach
    for key_file in "$mars_ssh"/id_* "$mars_ssh"/*_id_*; do
      [ -f "$key_file" ] || continue
      [[ "$key_file" == *.pub ]] && continue  # Skip public keys

      local owner
      owner=$(stat -c '%U' "$key_file" 2>/dev/null || echo "unknown")
      if [ "$owner" != "mars" ]; then
        if chown mars:mars-dev "$key_file" 2>/dev/null; then
          chmod 600 "$key_file" 2>/dev/null || true
          log_success "Fixed $(basename "$key_file") ownership"
          fixed_count=$((fixed_count + 1))
        else
          log_warning "Cannot fix bind-mounted SSH key: $(basename "$key_file")"
        fi
      fi
    done
  fi

  if [ $fixed_count -gt 0 ]; then
    log_success "Fixed ownership on $fixed_count items in /home/mars"
  else
    log_info "No ownership changes needed (or files are bind-mounted)"
  fi
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

  # Setup XDG_RUNTIME_DIR for mars user (required by mars-claude wrapper)
  setup_xdg_runtime_dir
  echo ""

  # Copy SSH keys from /root/.ssh to /home/mars/.ssh with correct ownership
  # This is the ONLY way to give mars user SSH keys with correct ownership
  # because bind mounts cannot change ownership
  copy_ssh_keys_for_mars_user
  echo ""

  # Setup /home/mars symlinks to /root/ (for RC files, etc.)
  setup_home_mars_symlinks
  echo ""

  # Fix /home/mars directory ownership (for any remaining issues)
  fix_home_mars_ownership
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
}

# Run main function
main
