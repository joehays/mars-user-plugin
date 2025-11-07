#!/bin/bash
# =============================================================================
# install-wezterm.sh
# Install WezTerm - GPU-accelerated cross-platform terminal emulator
# https://wezfurlong.org/wezterm/
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
install_wezterm() {
  log_info "Installing WezTerm..."

  # Check if already installed
  if command -v wezterm &>/dev/null; then
    local version=$(wezterm --version | head -n1)
    log_info "WezTerm is already installed: ${version}"
    return 0
  fi

  # Detect Ubuntu version
  . /etc/os-release
  local UBUNTU_VERSION="${VERSION_ID}"

  # Download appropriate .deb package
  log_info "Downloading WezTerm for Ubuntu ${UBUNTU_VERSION}..."

  # Get latest release
  local WEZTERM_VERSION=$(curl -s https://api.github.com/repos/wez/wezterm/releases/latest | grep -Po '"tag_name": "\K[^"]*')
  local WEZTERM_URL="https://github.com/wez/wezterm/releases/download/${WEZTERM_VERSION}/wezterm-${WEZTERM_VERSION}.Ubuntu${UBUNTU_VERSION}.deb"

  wget -q "${WEZTERM_URL}" -O /tmp/wezterm.deb

  # Install package
  log_info "Installing WezTerm package..."
  dpkg -i /tmp/wezterm.deb || apt-get install -f -y

  # Cleanup
  rm -f /tmp/wezterm.deb

  log_success "WezTerm installed successfully"
  log_info "Run with: wezterm"
  log_info "Config: ~/.config/wezterm/wezterm.lua"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_wezterm
fi
