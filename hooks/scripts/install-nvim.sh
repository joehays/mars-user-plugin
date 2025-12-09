#!/bin/bash
# =============================================================================
# install-nvim.sh
# Download and install the latest Neovim binary
#
# Requirements: curl (auto-installed if missing)
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
install_latest_nvim() {
    log_info "Installing Neovim..."

    # Check if already installed
    if command -v nvim &>/dev/null; then
        local version=$(nvim --version | head -n1)
        log_info "Neovim is already installed: ${version}"
        return 0
    fi

    # Ensure curl is available (auto-install if missing)
    ensure_curl || {
        log_error "Cannot install nvim without curl"
        return 1
    }

    # Configuration
    local DIRNAME="nvim-linux-x86_64"
    local FILENAME="${DIRNAME}.tar.gz"
    local URL="https://github.com/neovim/neovim/releases/latest/download"
    local TARGET_DIR="/opt/nvim"
    local TARGET_RC_FILE="$(get_rc_file)"

    # Download
    local CWD=$(pwd)
    local DOWNLOAD_DIR="${HOME}/Downloads"
    mkdir -p "${DOWNLOAD_DIR}"

    log_info "Downloading Neovim into ${DOWNLOAD_DIR}..."

    cd "${DOWNLOAD_DIR}" || {
        log_error "Cannot change directory to ${DOWNLOAD_DIR}"
        return 1
    }

    if [ ! -f "./${FILENAME}" ]; then
        log_info "Downloading: ${URL}/${FILENAME}"
        curl -LO "${URL}/${FILENAME}"
    else
        log_info "Already downloaded: ${FILENAME}"
    fi

    # Install
    log_info "Installing Neovim..."

    # Clean up old installation
    rm -rf "${TARGET_DIR}"

    # Extract and install
    tar -C /opt -xzf "${FILENAME}"

    # Rename to 'nvim' for a cleaner path
    mv "/opt/${DIRNAME}" "${TARGET_DIR}"

    # Configure PATH (backward compatibility)
    local PATH_STRING="export PATH=\"\${PATH}:${TARGET_DIR}/bin\""
    cond_insert "${PATH_STRING}" "${TARGET_RC_FILE}"

    # Register binary in system PATH (instant availability)
    register_bin "${TARGET_DIR}/bin/nvim"

    # Add alias
    local ALIAS_STRING="alias nv=\"nvim\""
    cond_insert "${ALIAS_STRING}" "${TARGET_RC_FILE}"

    # Cleanup
    rm -f "${FILENAME}"

    cd "${CWD}"

    # Verify
    if [ -x "${TARGET_DIR}/bin/nvim" ]; then
        log_success "Neovim installed successfully"
    else
        log_error "Neovim installation failed"
        return 1
    fi
}

# Run if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_latest_nvim
fi
