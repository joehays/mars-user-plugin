#!/bin/bash
# =============================================================================
# install-kiwix.sh
# Install Kiwix - Offline Wikipedia and content reader
# https://www.kiwix.org/
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
install_kiwix() {
  log_info "Installing Kiwix..."

  # Check if already installed
  if command -v kiwix-serve &>/dev/null; then
    local version=$(kiwix-serve --version 2>&1 | head -n1)
    log_info "Kiwix is already installed: ${version}"
    return 0
  fi

  # Ensure wget is available for downloading
  ensure_wget || { log_error "Cannot download Kiwix without wget"; return 1; }

  # Download Kiwix tools
  log_info "Downloading Kiwix tools..."
  local KIWIX_VERSION="3.6.0"
  local KIWIX_ARCH="x86_64"
  local KIWIX_TAR="kiwix-tools_linux-${KIWIX_ARCH}-${KIWIX_VERSION}.tar.gz"
  local KIWIX_URL="https://download.kiwix.org/release/kiwix-tools/${KIWIX_TAR}"

  wget -q "${KIWIX_URL}" -O "/tmp/${KIWIX_TAR}"

  # Extract and install
  log_info "Extracting and installing Kiwix..."
  tar -xzf "/tmp/${KIWIX_TAR}" -C /tmp/
  cp /tmp/kiwix-tools_linux-${KIWIX_ARCH}-${KIWIX_VERSION}/kiwix-* /usr/local/bin/
  chmod +x /usr/local/bin/kiwix-*

  # Cleanup
  rm -rf "/tmp/${KIWIX_TAR}" "/tmp/kiwix-tools_linux-${KIWIX_ARCH}-${KIWIX_VERSION}"

  log_success "Kiwix installed successfully"
  log_info "Download content: https://library.kiwix.org/"
  log_info "Serve content: kiwix-serve <file.zim>"
  log_info "Example: kiwix-serve wikipedia_en_all.zim --port 8080"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_kiwix
fi
