#!/bin/bash
# =============================================================================
# install-nerdfonts.sh
# Install Nerd Fonts - Patched fonts with icons for terminal/IDE
# https://github.com/ryanoasis/nerd-fonts
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
install_nerdfonts() {
  log_info "Installing Nerd Fonts..."

  # Ensure dependencies are available
  cond_apt_install fontconfig
  ensure_curl || { log_error "Cannot download fonts without curl"; return 1; }
  ensure_unzip || { log_error "Cannot extract fonts without unzip"; return 1; }

  # Create fonts directory
  FONTS_DIR="${HOME}/.local/share/fonts"
  mkdir -p "${FONTS_DIR}"

  # List of popular Nerd Fonts to install
  # Adjust this list based on preferences
  FONTS=(
    "FiraCode"
    "Hack"
    "JetBrainsMono"
    "Meslo"
    "UbuntuMono"
  )

  for font in "${FONTS[@]}"; do
    # Check if already installed
    if fc-list | grep -i "${font} Nerd Font" &>/dev/null; then
      log_info "${font} Nerd Font is already installed"
      continue
    fi

    log_info "Installing ${font} Nerd Font..."

    # Download font
    curl -fLo "/tmp/${font}.zip" \
      "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font}.zip"

    # Extract to fonts directory
    unzip -o "/tmp/${font}.zip" -d "${FONTS_DIR}/${font}" \
      -x "*.txt" -x "*.md" 2>/dev/null || true

    # Cleanup
    rm -f "/tmp/${font}.zip"
  done

  # Refresh font cache
  log_info "Refreshing font cache..."
  fc-cache -fv "${FONTS_DIR}"

  log_success "Nerd Fonts installed successfully"
  log_info "Installed fonts: ${FONTS[*]}"
  log_info "Font directory: ${FONTS_DIR}"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_nerdfonts
fi
