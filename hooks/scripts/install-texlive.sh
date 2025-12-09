#!/bin/bash
# =============================================================================
# install-texlive.sh
# Install TexLive distribution (scheme-full)
#
# WARNING: This is a VERY large install (~7GB, 30-60 minutes)
# Only enable if you need LaTeX document compilation
#
# Requirements: wget, perl (auto-installed if missing)
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
install_texlive() {
    log_info "Installing TexLive (scheme-full: ~7GB, 30-60 minutes)..."

    local texlive_install_dir="/usr/local/texlive"
    local bin_dir="${texlive_install_dir}/bin/x86_64-linux"
    local filename="install-tl-unx.tar.gz"
    local url="https://mirror.ctan.org/systems/texlive/tlnet/${filename}"
    local texlive_scheme="scheme-full"

    # Check if already installed
    if [ -d "${texlive_install_dir}" ]; then
        log_info "TexLive already installed at ${texlive_install_dir} (skipping)"
        return 0
    fi

    # Ensure wget is available (auto-install if missing)
    ensure_wget || {
        log_error "Cannot install TexLive without wget"
        return 1
    }

    # Ensure perl is available (needed by installer)
    cond_apt_install perl

    # Download installer
    cd /tmp
    log_info "Downloading TexLive installer..."
    wget -q "${url}"
    zcat < "${filename}" | tar xf -

    # Install TexLive
    cd "$(ls -d install-tl-*/ | head -1)"
    log_info "Installing TexLive (this will take 30-60 minutes)..."
    perl ./install-tl \
        --no-interaction \
        --paper=letter \
        --no-doc-install \
        --no-src-install \
        --scheme="${texlive_scheme}" \
        --texdir="${texlive_install_dir}"

    # Add to PATH (backward compatibility)
    log_info "Adding TexLive to PATH..."
    local TARGET_RC_FILE="$(get_rc_file)"

    cat >> "${TARGET_RC_FILE}" <<EOF

# TexLive paths
export PATH="${bin_dir}:\${PATH}"
export MANPATH="/usr/local/texlive/texmf-dist/doc/man:\${MANPATH}"
export INFOPATH="/usr/local/texlive/texmf-dist/doc/info:\${INFOPATH}"
EOF

    # Register TeXLive binaries in system PATH (instant availability)
    if [ -d "${bin_dir}" ]; then
        log_info "Registering TeXLive binaries in /usr/local/bin"
        for bin in "${bin_dir}"/*; do
            if [ -f "$bin" ] && [ -x "$bin" ]; then
                register_bin "$bin"
            fi
        done
    fi

    # Install additional packages
    log_info "Installing additional TeX packages..."
    local package_list="newtx xpatch xstring mweights fontaxes microtype textcase chngcntr iftex xcolor xkeyval etoolbox latexmk"
    ${bin_dir}/tlmgr install ${package_list}

    # Cleanup
    cd /tmp
    rm -rf install-tl-* "${filename}"

    log_success "TexLive installation complete"
}

# Run if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_texlive
fi
