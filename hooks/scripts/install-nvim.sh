#!/bin/bash
# =============================================================================
# install-nvim.sh
# Download and install the latest Neovim binary
#
# Requirements: curl
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
    echo
    echo '============================================================'
    echo 'Installing Neovim (NVIM)'
    echo '============================================================'

    # --- CONFIGURATION ---
    local DIRNAME="nvim-linux-x86_64"
    local FILENAME="${DIRNAME}.tar.gz"
    local URL="https://github.com/neovim/neovim/releases/latest/download"
    local TARGET_DIR="/opt/nvim"
    local TARGET_RC_FILE="$(get_rc_file)"

    # --- DOWNLOAD ---
    local CWD=$(pwd)
    local DOWNLOAD_DIR="${HOME}/Downloads"
    mkdir -p "${DOWNLOAD_DIR}"

    echo
    echo "------------------------------"
    echo "Downloading NVIM into ${DOWNLOAD_DIR}"
    echo "------------------------------"

    cd "${DOWNLOAD_DIR}" || {
        log_error "Cannot change directory to ${DOWNLOAD_DIR}"
        return 1
    }

    if [ ! -f "./${FILENAME}" ]; then
        echo "Downloading: ${URL}/${FILENAME}"
        curl -LO "${URL}/${FILENAME}"
    else
        echo "ALREADY DOWNLOADED: ${URL}/${FILENAME}"
    fi

    # --- INSTALL ---
    echo
    echo "------------------------------"
    echo "Installing NVIM"
    echo "------------------------------"

    # Clean up old installation
    echo "Removing old installation: rm -rf ${TARGET_DIR}"
    rm -rf "${TARGET_DIR}"

    # Extract and install
    echo "Extracting: tar -C /opt -xzf ${FILENAME}"
    tar -C /opt -xzf "${FILENAME}"

    # Rename to 'nvim' for a cleaner path
    echo "Renaming /opt/${DIRNAME} to ${TARGET_DIR}"
    mv "/opt/${DIRNAME}" "${TARGET_DIR}"

    # --- CONFIGURE PATH AND ALIAS ---
    echo
    echo "------------------------------"
    echo "Configuring PATH and Alias"
    echo "------------------------------"

    # Add binary path
    local PATH_STRING="export PATH=\"\${PATH}:${TARGET_DIR}/bin\""
    echo "Adding PATH: ${PATH_STRING} to ${TARGET_RC_FILE}"
    cond_insert "${PATH_STRING}" "${TARGET_RC_FILE}"

    # Add alias
    local ALIAS_STRING="alias nv=\"nvim\""
    echo "Adding Alias: ${ALIAS_STRING} to ${TARGET_RC_FILE}"
    cond_insert "${ALIAS_STRING}" "${TARGET_RC_FILE}"

    # --- CLEANUP ---
    echo "Deleting downloaded file: ${FILENAME}"
    rm -f "${FILENAME}"

    cd "${CWD}"
    log_success "Neovim installation complete. Source your RC file to update PATH."
}

# Run if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_latest_nvim
fi
