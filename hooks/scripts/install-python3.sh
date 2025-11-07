#!/bin/bash
# =============================================================================
# install-python3.sh
# Install Python 3 with pyenv for version management
# https://github.com/pyenv/pyenv
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
install_python3() {
  log_info "Installing Python 3 with pyenv..."

  # Check if pyenv is already installed
  if command -v pyenv &>/dev/null; then
    local version=$(pyenv --version)
    log_info "pyenv is already installed: ${version}"
    return 0
  fi

  # Install build dependencies
  log_info "Installing build dependencies..."
  cond_apt_install build-essential
  cond_apt_install libssl-dev
  cond_apt_install zlib1g-dev
  cond_apt_install libbz2-dev
  cond_apt_install libreadline-dev
  cond_apt_install libsqlite3-dev
  cond_apt_install curl
  cond_apt_install libncursesw5-dev
  cond_apt_install xz-utils
  cond_apt_install tk-dev
  cond_apt_install libxml2-dev
  cond_apt_install libxmlsec1-dev
  cond_apt_install libffi-dev
  cond_apt_install liblzma-dev

  # Install pyenv
  log_info "Installing pyenv..."
  curl https://pyenv.run | bash

  # Add pyenv to PATH
  local TARGET_RC_FILE="$(get_rc_file)"

  local PYENV_CONFIG='# pyenv configuration
export PYENV_ROOT="${HOME}/.pyenv"
export PATH="${PYENV_ROOT}/bin:${PATH}"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"'

  cond_insert "${PYENV_CONFIG}" "${TARGET_RC_FILE}"

  # Source pyenv for current session
  export PYENV_ROOT="${HOME}/.pyenv"
  export PATH="${PYENV_ROOT}/bin:${PATH}"
  eval "$(pyenv init -)"

  log_success "pyenv installed successfully"
  log_info "Install Python versions with: pyenv install 3.11.0"
  log_info "Set global version with: pyenv global 3.11.0"
  log_info "Note: You may need to restart your shell for changes to take effect"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_python3
fi
