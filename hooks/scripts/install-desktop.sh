#!/bin/bash
# =============================================================================
# install-desktop.sh
# Install desktop environment (XRDP + GNOME)
#
# WARNING: This is a large install (~2-3GB, 10-15 minutes)
# Only enable if you need GUI/RDP access to the container
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
# Main Installation
# =============================================================================
install_desktop() {
    log_info "Installing desktop environment (this will take 10-15 minutes)..."

    # Check if already installed
    if dpkg -l | grep -q "^ii.*ubuntu-gnome-desktop"; then
        log_info "Ubuntu GNOME desktop is already installed"
        return 0
    fi

    # Remote desktop server
    log_info "Installing XRDP..."
    cond_apt_install xrdp

    # Full GNOME desktop environment
    log_info "Installing GNOME desktop..."
    cond_apt_install ubuntu-gnome-desktop

    log_success "Desktop environment installed"
    log_info "You can now connect via RDP on port 3389"
}

# Run if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_desktop
fi
