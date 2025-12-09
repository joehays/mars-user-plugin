#!/bin/bash
# =============================================================================
# install-rust.sh
# Install Rust programming language and Cargo package manager via rustup
#
# Supports two installation modes:
#   --system : Install to /opt/rust for multi-user access (root + mars)
#   (default): Install to $HOME/.cargo and $HOME/.rustup (single user)
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
    local SYSTEM_INSTALL=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --system)
                SYSTEM_INSTALL=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    echo
    if [ "$SYSTEM_INSTALL" = true ]; then
        echo '============================================================'
        echo 'Installing Rust & Cargo (system-level at /opt/rust)'
        echo '============================================================'
        _install_rust_system
    else
        echo '============================================================'
        echo 'Installing Rust & Cargo (user-level)'
        echo '============================================================'
        _install_rust_user
    fi
}

# =============================================================================
# System-level installation to /opt/rust
# =============================================================================
_install_rust_system() {
    # System-level installation paths (shared between root and mars users)
    local SYSTEM_RUSTUP_HOME="/opt/rust/rustup"
    local SYSTEM_CARGO_HOME="/opt/rust/cargo"

    # Set environment for installation
    export RUSTUP_HOME="${SYSTEM_RUSTUP_HOME}"
    export CARGO_HOME="${SYSTEM_CARGO_HOME}"
    export RUSTUP_TOOLCHAIN="stable"
    export RUSTUP_DEFAULT_HOST="x86_64-unknown-linux-gnu"
    export RUSTUP_DEFAULT_TARGET="x86_64-unknown-linux-gnu"

    # --- CHECK IF ALREADY INSTALLED ---
    if [ -x "${SYSTEM_CARGO_HOME}/bin/rustc" ]; then
        log_info "Rust is already installed at /opt/rust"
        "${SYSTEM_CARGO_HOME}/bin/rustc" --version
        "${SYSTEM_CARGO_HOME}/bin/cargo" --version
        return 0
    fi

    # --- CREATE INSTALLATION DIRECTORY ---
    echo
    echo '------------------------------'
    echo 'Creating /opt/rust directory'
    echo '------------------------------'

    mkdir -p "${SYSTEM_RUSTUP_HOME}" "${SYSTEM_CARGO_HOME}"

    # --- DOWNLOAD AND INSTALL ---
    echo
    echo '------------------------------'
    echo 'Downloading and Installing Rust via rustup'
    echo '------------------------------'

    local CWD=$(pwd)
    cd /tmp || return 1

    # Ensure curl is available for downloading
    ensure_curl || { log_error "Cannot download rustup without curl"; return 1; }

    # Download and run rustup installer
    log_info "Running rustup installer..."
    curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

    if [ $? -ne 0 ]; then
        log_error "Rustup installation failed"
        cd "${CWD}"
        return 1
    fi

    # --- SET PERMISSIONS FOR MULTI-USER ACCESS ---
    echo
    echo '------------------------------'
    echo 'Setting permissions for multi-user access'
    echo '------------------------------'

    # If mars-dev group exists, use it (same pattern as /opt/pyenv)
    if getent group mars-dev > /dev/null 2>&1; then
        log_info "Setting /opt/rust ownership to root:mars-dev"
        chgrp -R mars-dev /opt/rust
        chmod -R g+rwX /opt/rust
        # Set setgid so new files inherit group
        find /opt/rust -type d -exec chmod g+s {} \;
    else
        log_info "mars-dev group not found, setting world-readable permissions"
        chmod -R a+rX /opt/rust
        chmod -R a+w "${SYSTEM_CARGO_HOME}/bin" 2>/dev/null || true
    fi

    # --- CONFIGURE ENVIRONMENT ---
    echo
    echo '------------------------------'
    echo 'Configuring Environment for all users'
    echo '------------------------------'

    # Environment setup lines
    local RUSTUP_HOME_LINE='export RUSTUP_HOME="/opt/rust/rustup"'
    local CARGO_HOME_LINE='export CARGO_HOME="/opt/rust/cargo"'
    local PATH_LINE='export PATH="/opt/rust/cargo/bin:${PATH}"'

    # Add to all RC files (root and mars user)
    log_info "Adding Rust environment to all RC files"
    cond_insert_all_rc "${RUSTUP_HOME_LINE}"
    cond_insert_all_rc "${CARGO_HOME_LINE}"
    cond_insert_all_rc "${PATH_LINE}"

    # Register cargo binaries in system PATH (instant availability without sourcing RC)
    if [ -d "${SYSTEM_CARGO_HOME}/bin" ]; then
        log_info "Registering cargo binaries in /usr/local/bin"
        for bin in "${SYSTEM_CARGO_HOME}/bin"/*; do
            if [ -f "$bin" ] && [ -x "$bin" ]; then
                register_bin "$bin"
            fi
        done
    fi

    # --- VERIFY INSTALLATION ---
    echo
    echo '------------------------------'
    echo 'Verifying Installation'
    echo '------------------------------'

    export PATH="${SYSTEM_CARGO_HOME}/bin:${PATH}"

    if [ -x "${SYSTEM_CARGO_HOME}/bin/rustc" ] && [ -x "${SYSTEM_CARGO_HOME}/bin/cargo" ]; then
        log_success "Rust installation complete (system-level at /opt/rust)!"
        echo "Rust version: $("${SYSTEM_CARGO_HOME}/bin/rustc" --version)"
        echo "Cargo version: $("${SYSTEM_CARGO_HOME}/bin/cargo" --version)"
        echo ""
        log_info "Both root and mars users can now use Rust/Cargo"
    else
        log_warning "Rust installed but binaries not found"
        log_info "Check /opt/rust/cargo/bin for binaries"
    fi

    cd "${CWD}"
}

# =============================================================================
# User-level installation to $HOME/.cargo
# =============================================================================
_install_rust_user() {
    # User-level installation paths
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

    # Ensure curl is available for downloading
    ensure_curl || { log_error "Cannot download rustup without curl"; return 1; }

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

    # Add cargo bin to PATH
    local PATH_STRING="export PATH=\"\${HOME}/.cargo/bin:\${PATH}\""
    log_info "Adding cargo bin to PATH in ${TARGET_RC_FILE}"
    cond_insert "${PATH_STRING}" "${TARGET_RC_FILE}"

    # Register cargo binaries in system PATH (instant availability)
    if [ -d "${HOME}/.cargo/bin" ]; then
        log_info "Registering cargo binaries in /usr/local/bin"
        for bin in "${HOME}/.cargo/bin"/*; do
            if [ -f "$bin" ] && [ -x "$bin" ]; then
                register_bin "$bin"
            fi
        done
    fi

    # --- VERIFY INSTALLATION ---
    echo
    echo '------------------------------'
    echo 'Verifying Installation'
    echo '------------------------------'

    # Source cargo env for current session
    if [ -f "${HOME}/.cargo/env" ]; then
        source "${HOME}/.cargo/env"
    fi

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
