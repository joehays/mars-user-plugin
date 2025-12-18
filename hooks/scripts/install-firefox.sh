#!/bin/bash
# =============================================================================
# install-firefox.sh
# Install Firefox from Mozilla Team PPA (not snap)
#
# Ubuntu 22.04 replaced the firefox apt package with a snap redirect stub.
# For containers where snap doesn't work, we use the Mozilla Team PPA.
# =============================================================================
set -euo pipefail

# Source utilities
_LOCAL_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "${_LOCAL_SCRIPT_DIR}/utils.sh"

# Detect environment
detect_environment

# =============================================================================
# Check if real Firefox is installed (not the snap stub)
# =============================================================================
is_real_firefox_installed() {
  # Check if firefox binary exists and is NOT the snap stub
  if command -v firefox &>/dev/null; then
    local firefox_path=$(command -v firefox)
    # The snap stub is a shell script that tells you to install snap
    if file "$firefox_path" 2>/dev/null | grep -q "ELF"; then
      return 0  # Real binary
    elif [ -x /snap/bin/firefox ]; then
      return 0  # Snap is actually installed
    fi
  fi

  # Check for firefox-esr
  if command -v firefox-esr &>/dev/null; then
    return 0
  fi

  return 1
}

# =============================================================================
# Installation Function
# =============================================================================
install_firefox() {
  log_info "Installing Firefox from Mozilla Team PPA..."

  # Check if already installed (real Firefox, not snap stub)
  if is_real_firefox_installed; then
    local firefox_version=$(firefox --version 2>/dev/null || firefox-esr --version 2>/dev/null || echo "unknown")
    log_info "Firefox is already installed (${firefox_version})"
    return 0
  fi

  # Add Mozilla Team PPA for real Firefox (not snap)
  log_info "Adding Mozilla Team PPA..."
  if ! grep -q "mozillateam/ppa" /etc/apt/sources.list.d/*.list 2>/dev/null; then
    add-apt-repository -y ppa:mozillateam/ppa
  fi

  # Set apt preferences to prioritize PPA over snap stub
  log_info "Configuring apt preferences for Firefox..."
  cat > /etc/apt/preferences.d/mozilla-firefox << 'EOF'
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001

Package: firefox
Pin: version 1:1snap*
Pin-Priority: -1
EOF

  # Remove the snap stub if present
  if [ -f /usr/bin/firefox ] && file /usr/bin/firefox | grep -q "shell script"; then
    log_info "Removing Firefox snap stub..."
    apt-get remove -y firefox 2>/dev/null || true
  fi

  # Update apt cache
  apt-get update -qq

  # Install Firefox from PPA
  log_info "Installing Firefox from PPA..."
  apt-get install -y firefox

  # Verify installation
  if is_real_firefox_installed; then
    local firefox_version=$(firefox --version 2>/dev/null || echo "installed")
    log_success "Firefox installed successfully (${firefox_version})"
    log_info "Start with: firefox"
  else
    log_error "Firefox installation failed"
    return 1
  fi
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_firefox
fi
