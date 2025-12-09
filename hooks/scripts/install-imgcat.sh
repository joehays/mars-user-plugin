#!/bin/bash
# =============================================================================
# install-imgcat.sh
# Install imgcat - Display images in terminal (iTerm2 protocol)
# https://github.com/eddieantonio/imgcat
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
install_imgcat() {
  log_info "Installing imgcat..."

  # Check if already installed
  if command -v imgcat &>/dev/null; then
    log_info "imgcat is already installed"
    return 0
  fi

  # Ensure curl is available for downloading
  ensure_curl || { log_error "Cannot download imgcat without curl"; return 1; }

  # Install via curl (simple script)
  log_info "Downloading imgcat script..."
  curl -fsSL https://iterm2.com/utilities/imgcat -o /usr/local/bin/imgcat
  chmod +x /usr/local/bin/imgcat

  log_success "imgcat installed successfully"
  log_info "Usage: imgcat <image-file>"
  log_info "Note: Works best with iTerm2 or compatible terminals"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_imgcat
fi
