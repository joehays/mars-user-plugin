#!/bin/bash
# =============================================================================
# install-clipboard-tools.sh
# Install clipboard tools for X11 environments (autocutsel, xclip, xsel)
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
install_clipboard_tools() {
  log_info "Installing clipboard tools (autocutsel, xclip, xsel)..."

  local installed_tools=""

  # Install xclip - Command line interface to X clipboard
  if command -v xclip &>/dev/null; then
    log_info "xclip is already installed"
    installed_tools="${installed_tools}xclip "
  else
    log_info "Installing xclip..."
    cond_apt_install xclip && installed_tools="${installed_tools}xclip "
  fi

  # Install xsel - Command-line program for getting and setting X selection
  if command -v xsel &>/dev/null; then
    log_info "xsel is already installed"
    installed_tools="${installed_tools}xsel "
  else
    log_info "Installing xsel..."
    cond_apt_install xsel && installed_tools="${installed_tools}xsel "
  fi

  # Install autocutsel - Keep X clipboard and cutbuffer in sync
  if command -v autocutsel &>/dev/null; then
    log_info "autocutsel is already installed"
    installed_tools="${installed_tools}autocutsel "
  else
    log_info "Installing autocutsel..."
    cond_apt_install autocutsel && installed_tools="${installed_tools}autocutsel "
  fi

  # Summary
  if [ -n "${installed_tools}" ]; then
    log_success "Clipboard tools installed: ${installed_tools}"
    log_info ""
    log_info "Usage examples:"
    log_info "  xclip -selection clipboard < file    # Copy file to clipboard"
    log_info "  xclip -selection clipboard -o        # Paste from clipboard"
    log_info "  xsel --clipboard < file              # Copy file to clipboard"
    log_info "  xsel --clipboard                     # Paste from clipboard"
    log_info "  autocutsel -fork                     # Sync cutbuffer and clipboard"
    log_info ""
    log_info "Note: Requires X11 display (VNC or X forwarding)"
  else
    log_error "No clipboard tools were installed"
    return 1
  fi
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_clipboard_tools
fi
