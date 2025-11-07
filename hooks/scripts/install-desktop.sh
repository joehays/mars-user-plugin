#!/bin/bash
# =============================================================================
# install-desktop.sh
# Install desktop environment (XRDP + GNOME)
#
# WARNING: This is a large install (~2-3GB, 10-15 minutes)
# Only enable if you need GUI/RDP access to the container
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

    apt-get update

    # Remote desktop server
    log_info "Installing XRDP..."
    apt-get install -y xrdp

    # Full GNOME desktop environment
    log_info "Installing GNOME desktop..."
    apt-get install -y ubuntu-gnome-desktop

    # Optionally install the smaller ICEWM instead:
    # apt-get install -y icewm

    log_success "Desktop environment installed"
    log_info "You can now connect via RDP on port 3389"
}

# Run if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_desktop
fi
