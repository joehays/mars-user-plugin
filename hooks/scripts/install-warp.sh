#!/bin/bash
# =============================================================================
# install-warp.sh
# Install Warp terminal - Modern terminal with AI features
# https://www.warp.dev/
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
install_warp() {
  log_info "Installing Warp terminal..."

  # Check if already installed
  if command -v warp-terminal &>/dev/null; then
    log_info "Warp terminal is already installed"
    return 0
  fi

  # Note: Warp currently only supports macOS and Linux (x86_64)
  # Check architecture
  if [ "$(uname -m)" != "x86_64" ]; then
    log_error "Warp terminal only supports x86_64 architecture"
    return 1
  fi

  # Ensure wget is available for downloading
  ensure_wget || { log_error "Cannot download Warp without wget"; return 1; }

  # Download latest .deb package
  log_info "Downloading Warp terminal..."
  local WARP_URL="https://releases.warp.dev/stable/v0.2024.10.29.08.02.stable_00/warp-terminal_0.2024.10.29.08.02.stable.00_amd64.deb"
  wget -q "${WARP_URL}" -O /tmp/warp-terminal.deb

  # Install package
  log_info "Installing Warp terminal package..."
  dpkg -i /tmp/warp-terminal.deb || apt-get install -f -y

  # Cleanup
  rm -f /tmp/warp-terminal.deb

  log_success "Warp terminal installed successfully"
  log_info "Run with: warp-terminal"
  log_warning "Note: Warp requires login and is primarily designed for desktop use"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_warp
fi
