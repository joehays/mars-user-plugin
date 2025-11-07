#!/bin/bash
# =============================================================================
# install-ueberzugpp.sh
# Install ueberzug++ - Terminal image viewer with multiple backend support
# https://github.com/jstkdng/ueberzugpp
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
install_ueberzugpp() {
  log_info "Installing ueberzug++..."

  # Check if already installed
  if command -v ueberzug &>/dev/null; then
    log_info "ueberzug++ is already installed"
    return 0
  fi

  # Install dependencies
  log_info "Installing dependencies..."
  cond_apt_install cmake
  cond_apt_install libvips-dev
  cond_apt_install libsixel-dev
  cond_apt_install libchafa-dev
  cond_apt_install libtbb-dev

  # Download and install from GitHub releases
  log_info "Downloading ueberzug++ from GitHub..."
  local UEBERZUG_VERSION=$(curl -s https://api.github.com/repos/jstkdng/ueberzugpp/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
  local UEBERZUG_DEB="ueberzugpp_${UEBERZUG_VERSION}_amd64.deb"
  local UEBERZUG_URL="https://github.com/jstkdng/ueberzugpp/releases/download/v${UEBERZUG_VERSION}/${UEBERZUG_DEB}"

  wget -q "${UEBERZUG_URL}" -O "/tmp/${UEBERZUG_DEB}"

  # Install package
  log_info "Installing ueberzug++ package..."
  dpkg -i "/tmp/${UEBERZUG_DEB}" || apt-get install -f -y

  # Cleanup
  rm -f "/tmp/${UEBERZUG_DEB}"

  log_success "ueberzug++ installed successfully"
  log_info "Usage: ueberzug layer"
  log_info "Supports: X11, Wayland, and sixel terminals"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_ueberzugpp
fi
