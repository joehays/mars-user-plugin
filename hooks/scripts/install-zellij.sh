#!/bin/bash
# =============================================================================
# install-zellij.sh
# Install Zellij - A terminal workspace with batteries included
# https://zellij.dev/
#
# Requirements: wget (auto-installed if missing)
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
install_zellij() {
  log_info "Installing Zellij terminal multiplexer..."

  # Check if already installed
  if command -v zellij &>/dev/null; then
    local zellij_version=$(zellij --version 2>/dev/null || echo "unknown")
    log_info "Zellij is already installed (${zellij_version})"
    return 0
  fi

  # Ensure wget is available (auto-install if missing)
  ensure_wget || {
    log_error "Cannot install zellij without wget"
    return 1
  }

  # Download latest Zellij release
  log_info "Downloading Zellij..."
  local ZELLIJ_VERSION="0.43.1"
  local ZELLIJ_TAR="zellij-x86_64-unknown-linux-musl.tar.gz"
  local ZELLIJ_URL="https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/${ZELLIJ_TAR}"

  wget -q "${ZELLIJ_URL}" -O "/tmp/${ZELLIJ_TAR}"

  # Extract and install
  log_info "Installing Zellij binary..."
  cd /tmp
  tar -xzf "${ZELLIJ_TAR}"
  mv zellij /usr/local/bin/
  chmod +x /usr/local/bin/zellij

  # Cleanup
  rm -f "/tmp/${ZELLIJ_TAR}"

  # Verify installation
  if command -v zellij &>/dev/null; then
    local zellij_version=$(zellij --version 2>/dev/null || echo "unknown")
    log_success "Zellij installed successfully (${zellij_version})"
    log_info "Start with: zellij"
    log_info "Default keybind: Ctrl+P for pane management, Ctrl+T for tab management"
  else
    log_error "Zellij installation failed"
    return 1
  fi
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_zellij
fi
