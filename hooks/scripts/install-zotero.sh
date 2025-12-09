#!/bin/bash
# =============================================================================
# install-zotero.sh
# Install Zotero Desktop - Reference management software
# https://www.zotero.org/
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
install_zotero() {
  log_info "Installing Zotero Desktop..."

  # Check if already installed
  if [ -d "/opt/zotero" ] && [ -x "/opt/zotero/zotero" ]; then
    log_info "Zotero is already installed at /opt/zotero"
    return 0
  fi

  if command -v zotero &>/dev/null; then
    log_info "Zotero is already available on PATH"
    return 0
  fi

  # Download Zotero tarball
  log_info "Downloading Zotero..."
  local ZOTERO_URL="https://www.zotero.org/download/client/dl?channel=release&platform=linux-x86_64"
  local ZOTERO_TAR="/tmp/zotero.tar.bz2"

  wget -q "${ZOTERO_URL}" -O "${ZOTERO_TAR}"

  # Extract to /opt
  log_info "Extracting Zotero to /opt..."
  cd /opt
  tar -xjf "${ZOTERO_TAR}"

  # The extracted directory is usually named Zotero_linux-x86_64
  # Rename to /opt/zotero for consistency
  if [ -d "/opt/Zotero_linux-x86_64" ]; then
    mv /opt/Zotero_linux-x86_64 /opt/zotero
  fi

  # Cleanup download
  rm -f "${ZOTERO_TAR}"

  # Create symlink in /usr/local/bin
  if [ -x "/opt/zotero/zotero" ]; then
    register_bin "/opt/zotero/zotero"
  fi

  # Create desktop entry (for GUI launchers)
  if [ -d "/usr/share/applications" ]; then
    log_info "Creating desktop entry..."
    cat > /usr/share/applications/zotero.desktop << 'EOF'
[Desktop Entry]
Name=Zotero
Comment=Reference Management
Exec=/opt/zotero/zotero %U
Icon=/opt/zotero/chrome/icons/default/default256.png
Type=Application
Terminal=false
Categories=Office;Education;Science;
MimeType=text/plain;x-scheme-handler/zotero;
StartupNotify=true
EOF
  fi

  # Verify installation
  if [ -x "/opt/zotero/zotero" ]; then
    log_success "Zotero installed successfully at /opt/zotero"
    log_info "Start with: zotero"
    log_info "Note: Requires X11 display (VNC or X forwarding)"
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
