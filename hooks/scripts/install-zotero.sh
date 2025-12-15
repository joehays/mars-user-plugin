#!/bin/bash
# =============================================================================
# install-zotero.sh
# Install Zotero Desktop - Reference management software
# https://www.zotero.org/
#
# NOTE: This script is DISABLED by default in user-setup.sh
# Zotero is now installed by E6/E30 Dockerfiles with version pinning.
# This script is kept for standalone/manual use with matching version pin.
#
# VERSION PINNING: We pin to match E6/E30 Dockerfiles because MARS docs
# describe JAR modifications (omni.ja) for self-hosted server connection.
# These modifications may not be compatible with future versions.
# See:
#   - core/docs/USE_CASE_HOW_TO_GUIDE.md (UC1 Desktop Client Setup)
#   - modules/services/lit-manager/docs/setup/DESKTOP_CLIENT_SETUP.md
#
# Requirements: wget (auto-installed if missing)
# =============================================================================
set -euo pipefail

# VERSION PIN - Keep in sync with:
#   - mars-dev/dev-environment/Dockerfile (E6)
#   - core/runtime-environment/Dockerfile (E30)
ZOTERO_VERSION="7.0.9"

# Source utilities
_LOCAL_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "${_LOCAL_SCRIPT_DIR}/utils.sh"

# Detect environment
detect_environment

# =============================================================================
# Installation Function
# =============================================================================
install_zotero() {
  log_info "Installing Zotero Desktop v${ZOTERO_VERSION} (version-pinned)..."

  # Check if already installed via apt
  if command -v zotero &>/dev/null; then
    local installed_version
    installed_version=$(zotero --version 2>/dev/null | head -1 || echo "unknown")
    log_info "Zotero is already installed: ${installed_version}"
    return 0
  fi

  # Check if already installed at /opt/zotero
  if [ -d "/opt/zotero" ] && [ -x "/opt/zotero/zotero" ]; then
    log_info "Zotero is already installed at /opt/zotero"
    return 0
  fi

  # Ensure wget is available (auto-install if missing)
  ensure_wget || {
    log_error "Cannot install Zotero without wget"
    return 1
  }

  # Install via zotero-deb repository (matches E6/E30 Dockerfiles)
  log_info "Adding zotero-deb repository..."
  wget -qO- https://raw.githubusercontent.com/retorquere/zotero-deb/master/install.sh | bash

  log_info "Installing Zotero v${ZOTERO_VERSION} via apt..."
  apt-get update
  apt-get install -y "zotero=${ZOTERO_VERSION}"

  # Hold package to prevent automatic upgrades
  apt-mark hold zotero
  log_info "Zotero package held to prevent automatic upgrades"

  # Verify installation
  if command -v zotero &>/dev/null; then
    log_success "Zotero v${ZOTERO_VERSION} installed successfully"
    log_info "Start with: zotero"
    log_info "Note: Requires X11 display (VNC or X forwarding)"
    log_warning "Version is pinned - JAR modifications may break on version changes"
  else
    log_error "Zotero installation failed"
    return 1
  fi
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_zotero
fi
