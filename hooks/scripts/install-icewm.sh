#!/bin/bash
# =============================================================================
# install-icewm.sh
# Install IceWM - A lightweight window manager
# https://ice-wm.org/
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
install_icewm() {
  log_info "Installing IceWM..."

  # Check if IceWM is already installed
  if dpkg -l | grep -q "^ii.*icewm"; then
    log_info "IceWM is already installed"
    return 0
  fi

  # Update package lists
  apt-get update -qq

  # Install IceWM and related packages
  log_info "Installing IceWM and components..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    icewm \
    icewm-themes \
    icewm-common \
    lightdm

  # Configure LightDM as display manager (if not already configured)
  if [ -f /etc/X11/default-display-manager ]; then
    if ! grep -q lightdm /etc/X11/default-display-manager; then
      log_info "Configuring LightDM as default display manager..."
      echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
    fi
  fi

  log_success "IceWM installed successfully"
  log_info "IceWM is a lightweight window manager (~10MB vs ~2-3GB for GNOME)"
  log_info "Reboot to start the desktop environment"
  log_info "Or start manually with: systemctl start lightdm"
  log_info ""
  log_info "Configuration files:"
  log_info "  - System: /etc/icewm/"
  log_info "  - User:   ~/.icewm/"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_icewm
fi
