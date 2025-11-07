#!/bin/bash
# =============================================================================
# install-lazydocker.sh
# Install lazydocker - A simple terminal UI for docker and docker-compose
# https://github.com/jesseduffield/lazydocker
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
install_lazydocker() {
  log_info "Installing lazydocker..."

  # Check if already installed
  if command -v lazydocker &>/dev/null; then
    local version=$(lazydocker --version 2>&1 | head -n1)
    log_info "lazydocker is already installed: ${version}"
    return 0
  fi

  # Install via official script
  log_info "Installing lazydocker from GitHub releases..."

  # Download and run install script
  curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

  log_success "lazydocker installed successfully"
  log_info "Run 'lazydocker' to start the TUI"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_lazydocker
fi
