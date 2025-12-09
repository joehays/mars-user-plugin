#!/bin/bash
# =============================================================================
# install-firefox.sh
# Install Firefox ESR (Extended Support Release)
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
install_firefox() {
  log_info "Installing Firefox ESR..."

  # Check if already installed
  if command -v firefox &>/dev/null || command -v firefox-esr &>/dev/null; then
    local firefox_version=$(firefox --version 2>/dev/null || firefox-esr --version 2>/dev/null || echo "unknown")
    log_info "Firefox is already installed (${firefox_version})"
    return 0
  fi

  # Install Firefox ESR via apt
  log_info "Installing Firefox ESR via apt..."
  cond_apt_install firefox-esr

  # If firefox-esr not available, try regular firefox
  if ! command -v firefox &>/dev/null && ! command -v firefox-esr &>/dev/null; then
    log_info "firefox-esr not available, trying firefox..."
    cond_apt_install firefox
  fi

  # Verify installation
  if command -v firefox &>/dev/null || command -v firefox-esr &>/dev/null; then
    local firefox_version=$(firefox --version 2>/dev/null || firefox-esr --version 2>/dev/null || echo "unknown")
    log_success "Firefox installed successfully (${firefox_version})"
    log_info "Start with: firefox or firefox-esr"
  else
    log_error "Firefox installation failed"
    return 1
  fi
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_firefox
fi
