#!/bin/bash
# =============================================================================
# install-kitty.sh
# Install Kitty terminal emulator
# https://sw.kovidgoyal.net/kitty/
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
install_kitty() {
  log_info "Installing Kitty terminal..."

  # Check if already installed
  if command -v kitty &>/dev/null; then
    local version=$(kitty --version | head -n1)
    log_info "Kitty is already installed: ${version}"
    return 0
  fi

  # Install via official installer
  log_info "Downloading and installing Kitty..."
  curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin

  # Create symlinks
  log_info "Creating symlinks..."
  mkdir -p ~/.local/bin
  ln -sf ~/.local/kitty.app/bin/kitty ~/.local/bin/kitty
  ln -sf ~/.local/kitty.app/bin/kitten ~/.local/bin/kitten

  # Add to PATH (backward compatibility)
  local TARGET_RC_FILE="$(get_rc_file)"
  cond_insert 'export PATH="${HOME}/.local/bin:${PATH}"' "${TARGET_RC_FILE}"

  # Register binaries in system PATH (instant availability)
  if [ -f "${HOME}/.local/bin/kitty" ]; then
    register_bin "${HOME}/.local/bin/kitty"
  fi
  if [ -f "${HOME}/.local/bin/kitten" ]; then
    register_bin "${HOME}/.local/bin/kitten"
  fi

  # Create desktop integration (if on host with desktop)
  if [ -d /usr/share/applications ]; then
    cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/ 2>/dev/null || true
    cp ~/.local/kitty.app/share/applications/kitty-open.desktop ~/.local/share/applications/ 2>/dev/null || true
    sed -i "s|Icon=kitty|Icon=${HOME}/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" \
      ~/.local/share/applications/kitty*.desktop 2>/dev/null || true
  fi

  log_success "Kitty terminal installed successfully"
  log_info "Run with: kitty"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_kitty
fi
