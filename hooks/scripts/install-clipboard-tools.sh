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

  # Check if all tools are already installed
  if command -v xclip &>/dev/null && command -v xsel &>/dev/null && command -v autocutsel &>/dev/null; then
    log_info "All clipboard tools are already installed (xclip, xsel, autocutsel)"
    return 0
  fi

  # Install all clipboard tools via apt (cond_apt_install handles skip-if-installed)
  cond_apt_install xclip xsel autocutsel

  # Summary
  local installed_tools=""
  command -v xclip &>/dev/null && installed_tools="${installed_tools}xclip "
  command -v xsel &>/dev/null && installed_tools="${installed_tools}xsel "
  command -v autocutsel &>/dev/null && installed_tools="${installed_tools}autocutsel "

  if [ -n "${installed_tools}" ]; then
    log_success "Clipboard tools available: ${installed_tools}"
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
