#!/bin/bash
# =============================================================================
# install-npm.sh
# Install Node.js and NPM (Node Package Manager)
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
install_npm() {
  log_info "Installing Node.js and NPM..."

  # Check if already installed
  if command -v node &>/dev/null && command -v npm &>/dev/null; then
    local node_version=$(node --version)
    local npm_version=$(npm --version)
    log_info "Node.js ${node_version} and NPM ${npm_version} already installed"
    return 0
  fi

  # Install NodeSource repository for latest LTS
  log_info "Adding NodeSource repository..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -

  # Install Node.js and NPM
  log_info "Installing Node.js and NPM..."
  cond_apt_install nodejs

  # Verify installation
  if command -v node &>/dev/null && command -v npm &>/dev/null; then
    log_success "Node.js $(node --version) and NPM $(npm --version) installed successfully"
  else
    log_error "Node.js/NPM installation failed"
    return 1
  fi
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_npm
fi
