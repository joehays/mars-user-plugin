#!/bin/bash
# =============================================================================
# install-wezterm-linux.sh
# Install WezTerm GPU-accelerated terminal emulator via apt repository
# https://wezfurlong.org/wezterm/
#
# Uses the official apt repository from https://apt.fury.io/wez/
# This provides stable releases with proper dependency management.
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
install_wezterm_linux() {
  log_info "Installing WezTerm..."

  # Check if already installed
  if command -v wezterm &>/dev/null; then
    local version=$(wezterm --version 2>/dev/null | head -n1 || echo "unknown")
    log_info "WezTerm is already installed: ${version}"
    return 0
  fi

  # Ensure curl is available
  ensure_curl || { log_error "Cannot install WezTerm without curl"; return 1; }

  # Add WezTerm apt repository
  # FROM: https://wezfurlong.org/wezterm/install/linux.html#using-the-apt-repo
  log_info "Adding WezTerm apt repository..."

  # Add GPG key
  curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
  chmod 644 /usr/share/keyrings/wezterm-fury.gpg

  # Add repository
  echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' > /etc/apt/sources.list.d/wezterm.list

  # Update and install
  log_info "Installing WezTerm package..."
  apt-get update -qq
  apt-get install -y wezterm

  # Verify installation
  if command -v wezterm &>/dev/null; then
    local version=$(wezterm --version 2>/dev/null | head -n1 || echo "unknown")
    log_success "WezTerm installed successfully: ${version}"
    log_info "Run with: wezterm"
    log_info "Config: ~/.config/wezterm/wezterm.lua"
  else
    log_error "WezTerm installation failed - binary not found"
    return 1
  fi
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_wezterm_linux "$@"
fi
