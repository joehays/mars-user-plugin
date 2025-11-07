#!/bin/bash
# =============================================================================
# install-python-libs.sh
# Install Python development libraries
#
# NOTE: These are already installed in E6 Dockerfile (lines 85-99)
# This script is provided for reference/standalone installations only
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
install_python_dev_libs() {
    log_info "Installing Python development libraries..."

    # Check if running as MARS plugin
    if [ "${IS_MARS_PLUGIN}" = true ]; then
        log_warning "Python dev libraries are already installed in E6 Dockerfile"
        log_info "Skipping installation to avoid duplication"
        return 0
    fi

    apt-get update
    apt-get install -y \
        build-essential \
        tk-dev \
        libffi-dev \
        liblzma-dev \
        libssl-dev \
        zlib1g-dev \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        llvm \
        libncurses5-dev \
        libncursesw5-dev \
        xz-utils

    # Note: python-openssl is deprecated in Ubuntu 22.04
    # Use python3-openssl instead, or install via pip
    apt-get install -y python3-openssl || true

    log_success "Python dev libraries installed"
}

# Run if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_python_dev_libs
fi
