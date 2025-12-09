#!/bin/bash
# =============================================================================
# install-vsc.sh
# Install Visual Studio Code
# https://code.visualstudio.com/
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
install_vsc() {
  log_info "Installing Visual Studio Code..."

  # Check if already installed
  if command -v code &>/dev/null; then
    local version=$(code --version | head -n1)
    log_info "VS Code is already installed: ${version}"
    return 0
  fi

  # Install dependencies
  log_info "Installing dependencies..."
  cond_apt_install gpg
  ensure_wget || { log_error "Cannot download VS Code without wget"; return 1; }

  # Add Microsoft GPG key
  log_info "Adding Microsoft GPG key..."
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
  install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg

  # Add VS Code repository
  log_info "Adding VS Code repository..."
  echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list

  # Update and install (force apt update since we added new repository)
  _APT_UPDATED=false
  cond_apt_install code

  # Cleanup
  rm -f /tmp/packages.microsoft.gpg

  log_success "Visual Studio Code installed successfully"
  log_info "Run with: code"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_vsc
fi
