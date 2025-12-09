#!/bin/bash
# =============================================================================
# install-wezterm-linux.sh
# Install WezTerm (Linux-specific AppImage variant)
# Alternative to install-wezterm.sh that uses AppImage instead of .deb
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
install_wezterm_linux() {
  log_info "Installing WezTerm (AppImage)..."

  # Check if already installed
  if [ -f "${HOME}/.local/bin/wezterm" ]; then
    log_info "WezTerm AppImage is already installed"
    return 0
  fi

  # Ensure curl and wget are available for downloading
  ensure_curl || { log_error "Cannot check version without curl"; return 1; }
  ensure_wget || { log_error "Cannot download WezTerm without wget"; return 1; }

  # Create bin directory
  mkdir -p "${HOME}/.local/bin"

  # Download AppImage
  log_info "Downloading WezTerm AppImage..."
  local WEZTERM_VERSION=$(curl -s https://api.github.com/repos/wez/wezterm/releases/latest | grep -Po '"tag_name": "\K[^"]*')
  local WEZTERM_URL="https://github.com/wez/wezterm/releases/download/${WEZTERM_VERSION}/WezTerm-${WEZTERM_VERSION}-Ubuntu20.04.AppImage"

  wget -q "${WEZTERM_URL}" -O "${HOME}/.local/bin/wezterm"
  chmod +x "${HOME}/.local/bin/wezterm"

  # Add to PATH (backward compatibility)
  local TARGET_RC_FILE="$(get_rc_file)"
  cond_insert 'export PATH="${HOME}/.local/bin:${PATH}"' "${TARGET_RC_FILE}"

  # Register binary in system PATH (instant availability)
  if [ -f "${HOME}/.local/bin/wezterm" ]; then
    register_bin "${HOME}/.local/bin/wezterm"
  fi

  log_success "WezTerm AppImage installed successfully"
  log_info "Run with: wezterm"
  log_info "Config: ~/.config/wezterm/wezterm.lua"
  log_info "Note: AppImage provides portable installation"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_wezterm_linux
fi
