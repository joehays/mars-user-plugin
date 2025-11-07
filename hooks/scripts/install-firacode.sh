#!/bin/bash
# =============================================================================
# install-firacode.sh
# Install Fira Code font - Monospaced font with programming ligatures
# https://github.com/tonsky/FiraCode
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
install_firacode() {
  log_info "Installing Fira Code font..."

  # Check if already installed
  if fc-list | grep -i "Fira Code" &>/dev/null; then
    log_info "Fira Code font is already installed"
    return 0
  fi

  # Install fontconfig if needed
  cond_apt_install fontconfig

  # Create fonts directory
  FONTS_DIR="${HOME}/.local/share/fonts"
  mkdir -p "${FONTS_DIR}"

  # Download and install Fira Code
  log_info "Downloading Fira Code from GitHub releases..."

  FIRA_VERSION=$(curl -s "https://api.github.com/repos/tonsky/FiraCode/releases/latest" | grep -Po '"tag_name": "\K[^"]*')

  curl -Lo /tmp/FiraCode.zip "https://github.com/tonsky/FiraCode/releases/download/${FIRA_VERSION}/Fira_Code_${FIRA_VERSION#v}.zip"

  unzip -o /tmp/FiraCode.zip "ttf/*" -d /tmp/FiraCode
  cp /tmp/FiraCode/ttf/*.ttf "${FONTS_DIR}/"

  # Cleanup
  rm -rf /tmp/FiraCode /tmp/FiraCode.zip

  # Refresh font cache
  log_info "Refreshing font cache..."
  fc-cache -fv "${FONTS_DIR}"

  log_success "Fira Code font installed successfully"
  log_info "Font installed to: ${FONTS_DIR}"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_firacode
fi
