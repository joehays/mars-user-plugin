#!/bin/bash
# =============================================================================
# install-ubuntu-gnome-desktop.sh
# Install Ubuntu GNOME Desktop environment
# Note: This is a variant of install-desktop.sh specifically for GNOME
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
install_ubuntu_gnome_desktop() {
  log_info "Installing Ubuntu GNOME Desktop..."

  # Check if GNOME is already installed
  if dpkg -l | grep -q ubuntu-gnome-desktop; then
    log_info "Ubuntu GNOME Desktop is already installed"
    return 0
  fi

  # Install ubuntu-gnome-desktop (using cond_apt_install for consistency)
  log_info "Installing ubuntu-gnome-desktop package..."
  log_warning "This will download ~2-3GB and take 10-15 minutes"

  cond_apt_install ubuntu-gnome-desktop

  # Install display manager (gdm3)
  log_info "Configuring GDM3 display manager..."
  cond_apt_install gdm3

  log_success "Ubuntu GNOME Desktop installed successfully"
  log_info "Reboot to start the desktop environment"
  log_info "Or start manually with: systemctl start gdm3"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_ubuntu_gnome_desktop
fi
