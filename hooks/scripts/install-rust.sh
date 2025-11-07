#!/bin/bash
# =============================================================================
# install-rust.sh
# Install Rust programming language and Cargo package manager via rustup
#
# Requirements: curl, bash
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
install_rust() {
    echo
    echo '============================================================'
    echo 'Installing Rust & Cargo'
    echo '============================================================'

    # Configuration
    export RUSTUP_HOME="${HOME}/.rustup"
    export CARGO_HOME="${HOME}/.cargo"
    export RUSTUP_TOOLCHAIN="stable"
    export RUSTUP_DEFAULT_HOST="x86_64-unknown-linux-gnu"
    export RUSTUP_DEFAULT_TARGET="x86_64-unknown-linux-gnu"

    local TARGET_RC_FILE="$(get_rc_file)"

    # --- CHECK IF ALREADY INSTALLED ---
    if command -v rustc &>/dev/null; then
        log_info "Rust is already installed"
        rustc --version
        cargo --version
        return 0
    fi

    # --- DOWNLOAD AND INSTALL ---
    echo
    echo '------------------------------'
    echo 'Downloading and Installing Rust via rustup'
    echo '------------------------------'

    local CWD=$(pwd)
    local DOWNLOAD_DIR="${HOME}/Downloads"
    mkdir -p "${DOWNLOAD_DIR}"

    cd "${DOWNLOAD_DIR}" || {
        log_error "Cannot change directory to ${DOWNLOAD_DIR}"
        return 1
    }

    # Download and run rustup installer
    log_info "Running rustup installer..."
    bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'

    if [ $? -ne 0 ]; then
        log_error "Rustup installation failed"
        cd "${CWD}"
        return 1
    fi

    # --- CONFIGURE ENVIRONMENT ---
    echo
    echo '------------------------------'
    echo 'Configuring Environment'
    echo '------------------------------'

    # Add cargo environment sourcing to RC file
    local CARGO_ENV_STRING="source \${HOME}/.cargo/env"
    log_info "Adding cargo env to ${TARGET_RC_FILE}"
    cond_insert "${CARGO_ENV_STRING}" "${TARGET_RC_FILE}"

    # Add cargo bin to PATH (alternative if sourcing doesn't work)
    local PATH_STRING="export PATH=\"\${HOME}/.cargo/bin:\${PATH}\""
    log_info "Adding cargo bin to PATH in ${TARGET_RC_FILE}"
    cond_insert "${PATH_STRING}" "${TARGET_RC_FILE}"

    # --- VERIFY INSTALLATION ---
    echo
    echo '------------------------------'
    echo 'Verifying Installation'
    echo '------------------------------'

    # Source cargo env for current session
    if [ -f "${HOME}/.cargo/env" ]; then
        source "${HOME}/.cargo/env"
    fi

    # Verify installation
    if command -v rustc &>/dev/null && command -v cargo &>/dev/null; then
        log_success "Rust installation complete!"
        echo "Rust version: $(rustc --version)"
        echo "Cargo version: $(cargo --version)"
    else
        log_warning "Rust installed but not found in PATH"
        log_info "You may need to restart your shell or run: source ${HOME}/.cargo/env"
    fi

    cd "${CWD}"
}

# Run if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_rust
fi
