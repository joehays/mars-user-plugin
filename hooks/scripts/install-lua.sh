#!/bin/bash
# =============================================================================
# install-lua.sh
# Install Lua programming language from source
# https://www.lua.org/
#
# Requirements: build-essential, libreadline-dev, curl (auto-installed if missing)
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
install_lua() {
  log_info "Installing Lua..."

  # Check if already installed
  if command -v lua &>/dev/null; then
    local version=$(lua -v 2>&1 | head -n1)
    log_info "Lua is already installed: ${version}"
    return 0
  fi

  # Ensure curl is available (auto-install if missing)
  ensure_curl || {
    log_error "Cannot install lua without curl"
    return 1
  }

  # Install build dependencies
  log_info "Installing build dependencies..."
  cond_apt_install build-essential libreadline-dev

  # Download and build Lua
  LUA_VERSION="5.4.6"
  log_info "Downloading Lua ${LUA_VERSION}..."

  cd /tmp
  curl -R -O "http://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz"
  tar -zxf "lua-${LUA_VERSION}.tar.gz"
  cd "lua-${LUA_VERSION}"

  log_info "Building Lua..."
  make linux

  log_info "Installing Lua..."
  make install

  # Cleanup
  cd /tmp
  rm -rf "lua-${LUA_VERSION}" "lua-${LUA_VERSION}.tar.gz"

  # Verify
  if command -v lua &>/dev/null; then
    log_success "Lua ${LUA_VERSION} installed successfully"
  else
    log_error "Lua installation failed"
    return 1
  fi
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_lua
fi
