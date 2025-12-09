#!/bin/bash
# =============================================================================
# install-bats.sh
# Install Bats (Bash Automated Testing System) testing framework
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
install_bats() {
  log_info "Installing Bats testing framework..."

  # Check if already installed
  if command -v bats &>/dev/null; then
    local bats_version=$(bats --version 2>/dev/null || echo "unknown")
    log_info "Bats is already installed (${bats_version})"
    return 0
  fi

  # Install from git
  log_info "Cloning bats-core..."
  cd /tmp
  rm -rf bats-core
  git clone https://github.com/bats-core/bats-core.git
  cd bats-core
  ./install.sh /usr/local
  cd /
  rm -rf /tmp/bats-core

  # Verify installation
  if command -v bats &>/dev/null; then
    local bats_version=$(bats --version 2>/dev/null || echo "unknown")
    log_success "Bats installed successfully (${bats_version})"
  else
    log_error "Bats installation failed"
    return 1
  fi
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_bats
fi
