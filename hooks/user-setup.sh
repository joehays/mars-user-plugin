#!/bin/bash
# =============================================================================
# mars-plugin/hooks/user-setup.sh
# Joe's work environment customizations for MARS E6 container
#
# Execution context:
#   - Runs as root during E6 container build (Dockerfile RUN command)
#   - Environment: Ubuntu 22.04, Python 3.10 (pyenv mars virtualenv)
#   - MARS_PLUGIN_ROOT: Path to this plugin directory
#   - MARS_REPO_ROOT: Path to MARS repository
# =============================================================================
set -euo pipefail

# Colors for logging
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[joehays-plugin]${NC} $*"; }
log_success() { echo -e "${GREEN}[joehays-plugin]${NC} ✅ $*"; }
log_warning() { echo -e "${YELLOW}[joehays-plugin]${NC} ⚠️  $*"; }

# =============================================================================
# Configuration: Enable/Disable Installation Categories
# =============================================================================
INSTALL_PERSONAL_TOOLS=true      # passwordsafe, etc.
INSTALL_DESKTOP=false            # xrdp, ubuntu-gnome-desktop (headless by default)
INSTALL_PYTHON_LIBS=false        # Already in E6 Dockerfile (skip to avoid duplication)
INSTALL_TEXLIVE=false            # Large install (~7GB, 30-60 min) - disabled by default

# =============================================================================
# 1. Personal Tools (passwordsafe)
# =============================================================================
install_personal_tools() {
    log_info "Installing personal tools..."

    apt-get update

    # Password manager
    if apt-cache show passwordsafe &>/dev/null; then
        apt-get install -y passwordsafe
        log_success "passwordsafe installed"
    else
        log_warning "passwordsafe not available in Ubuntu 22.04 repos (skipping)"
    fi

    # Add other personal tools here as needed
    # apt-get install -y <your-tool>

    log_success "Personal tools installation complete"
}

# =============================================================================
# 2. Desktop Environment (Optional - Large Install)
# =============================================================================
install_desktop() {
    log_info "Installing desktop environment (this will take 10-15 minutes)..."

    apt-get update

    # Remote desktop server
    apt-get install -y xrdp

    # Full GNOME desktop environment
    apt-get install -y ubuntu-gnome-desktop

    log_success "Desktop environment installed"
}

# =============================================================================
# 3. Python Development Libraries
# =============================================================================
# NOTE: These are already installed in E6 Dockerfile (lines 85-99)
# This function is provided for reference/documentation purposes
install_python_dev_libs() {
    log_info "Installing Python development libraries..."

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

# =============================================================================
# 4. TexLive (Optional - Very Large Install)
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
        log_warning "TexLive already installed at ${texlive_install_dir} (skipping)"
        return 0
    fi

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

    # Add to PATH in container's bashrc
    log_info "Adding TexLive to PATH..."
    cat >> /root/.bashrc <<EOF

# TexLive paths
export PATH="${bin_dir}:\${PATH}"
export MANPATH="/usr/local/texlive/texmf-dist/doc/man:\${MANPATH}"
export INFOPATH="/usr/local/texlive/texmf-dist/doc/info:\${INFOPATH}"
EOF

    # Install additional packages
    log_info "Installing additional TeX packages..."
    local package_list="newtx xpatch xstring mweights fontaxes microtype textcase chngcntr iftex xcolor xkeyval etoolbox latexmk"
    ${bin_dir}/tlmgr install ${package_list}

    # Cleanup
    cd /tmp
    rm -rf install-tl-* "${filename}"

    log_success "TexLive installation complete"
}

# =============================================================================
# Main Execution
# =============================================================================
main() {
    log_info "Starting joehays-work-customizations setup..."
    echo ""

    # Update package lists once at start
    log_info "Updating apt package lists..."
    apt-get update -qq

    # Execute enabled installation functions
    if [ "${INSTALL_PERSONAL_TOOLS}" = true ]; then
        install_personal_tools
        echo ""
    fi

    if [ "${INSTALL_DESKTOP}" = true ]; then
        install_desktop
        echo ""
    fi

    if [ "${INSTALL_PYTHON_LIBS}" = true ]; then
        install_python_dev_libs
        echo ""
    fi

    if [ "${INSTALL_TEXLIVE}" = true ]; then
        install_texlive
        echo ""
    fi

    # Cleanup
    log_info "Cleaning up apt cache..."
    apt-get autoremove -y
    apt-get clean
    rm -rf /var/lib/apt/lists/*

    echo ""
    log_success "joehays-work-customizations setup complete!"

    # Summary
    echo ""
    echo "======================================"
    echo "Installation Summary"
    echo "======================================"
    echo "Personal Tools:   $([ "${INSTALL_PERSONAL_TOOLS}" = true ] && echo "✅ Installed" || echo "⏭️  Skipped")"
    echo "Desktop Env:      $([ "${INSTALL_DESKTOP}" = true ] && echo "✅ Installed" || echo "⏭️  Skipped")"
    echo "Python Dev Libs:  $([ "${INSTALL_PYTHON_LIBS}" = true ] && echo "✅ Installed" || echo "⏭️  Skipped (already in E6)")"
    echo "TexLive:          $([ "${INSTALL_TEXLIVE}" = true ] && echo "✅ Installed" || echo "⏭️  Skipped")"
    echo "======================================"
}

# Run main function
main
