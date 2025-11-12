#!/bin/bash
# =============================================================================
# install-turbovnc.sh
# Install TurboVNC - High-performance VNC server
# https://www.turbovnc.org/
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
install_turbovnc() {
  log_info "Installing TurboVNC..."

  # Check if already installed
  if command -v vncserver &>/dev/null && vncserver -version 2>&1 | grep -q "TurboVNC"; then
    log_info "TurboVNC is already installed"
    return 0
  fi

  # Download TurboVNC from GitHub releases
  log_info "Downloading TurboVNC..."
  local TURBOVNC_VERSION="3.2.1"
  local TURBOVNC_DEB="turbovnc_${TURBOVNC_VERSION}_amd64.deb"
  local TURBOVNC_URL="https://github.com/TurboVNC/turbovnc/releases/download/${TURBOVNC_VERSION}/${TURBOVNC_DEB}"

  wget -q "${TURBOVNC_URL}" -O "/tmp/${TURBOVNC_DEB}"

  # Install package
  log_info "Installing TurboVNC package..."
  dpkg -i "/tmp/${TURBOVNC_DEB}" || apt-get install -f -y

  # Cleanup
  rm -f "/tmp/${TURBOVNC_DEB}"

  # Add TurboVNC to PATH (backward compatibility)
  local TARGET_RC_FILE="$(get_rc_file)"
  cond_insert 'export PATH="/opt/TurboVNC/bin:${PATH}"' "${TARGET_RC_FILE}"

  # Register TurboVNC binaries in system PATH (instant availability)
  if [ -d "/opt/TurboVNC/bin" ]; then
    log_info "Registering TurboVNC binaries in /usr/local/bin"
    for bin in /opt/TurboVNC/bin/*; do
      if [ -f "$bin" ] && [ -x "$bin" ]; then
        register_bin "$bin"
      fi
    done
  fi

  log_success "TurboVNC installed successfully"
  log_info "Start server: vncserver"
  log_info "Connect with VNC viewer to: <hostname>:<display>"
  log_info "Note: Requires X11 environment (desktop) to be installed"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_turbovnc
fi
