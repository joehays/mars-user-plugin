#!/bin/bash
# =============================================================================
# install-glow.sh
# Install glow - Render markdown on the CLI with pizzazz
# https://github.com/charmbracelet/glow
# =============================================================================
set -euo pipefail

# Source utilities
_LOCAL_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "${_LOCAL_SCRIPT_DIR}/utils.sh"

# Detect environment
detect_environment

# =============================================================================
# Installation Function
# =============================================================================
install_glow() {
  log_info "Installing glow..."

  # Check if already installed
  if command -v glow &>/dev/null; then
    local version=$(glow --version 2>&1 | head -n1)
    log_info "glow is already installed: ${version}"
    return 0
  fi

  # Ensure curl is available for downloading GPG key
  ensure_curl || { log_error "Cannot add glow repository without curl"; return 1; }

  # Install via apt repository
  log_info "Adding glow repository and installing..."

  # Add charm repository
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg
  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | tee /etc/apt/sources.list.d/charm.list

  # Update and install (force apt update since we added new repository)
  _APT_UPDATED=false
  cond_apt_install glow

  log_success "glow installed successfully"
  log_info "Run 'glow file.md' to render markdown files"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_glow
fi
