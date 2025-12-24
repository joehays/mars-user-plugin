#!/bin/bash
# =============================================================================
# install-icewm.sh
# Install IceWM - A lightweight window manager
# https://ice-wm.org/
#
# APT dependencies are auto-installed
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

  # Install IceWM and related packages
  log_info "Installing IceWM and components..."
  cond_apt_install icewm icewm-common lightdm

  # Configure LightDM as display manager (if not already configured)
  if [ -f /etc/X11/default-display-manager ]; then
    if ! grep -q lightdm /etc/X11/default-display-manager; then
      log_info "Configuring LightDM as default display manager..."
      echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
    fi
  fi

  # Create symlink for TurboVNC compatibility
  # TurboVNC's -wm flag strips "-session" suffix, so "icewm-session" looks for "icewm.desktop"
  # but Ubuntu 22.04's icewm package installs icewm-session.desktop. Create symlink to fix this.
  if [ -f /usr/share/xsessions/icewm-session.desktop ] && [ ! -e /usr/share/xsessions/icewm.desktop ]; then
    log_info "Creating icewm.desktop symlink for TurboVNC compatibility..."
    ln -sf /usr/share/xsessions/icewm-session.desktop /usr/share/xsessions/icewm.desktop
    log_success "Created symlink: icewm.desktop -> icewm-session.desktop"
  fi

  log_success "IceWM installed successfully"
  log_info "IceWM is a lightweight window manager (~10MB vs ~2-3GB for GNOME)"
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
