#!/bin/bash
# =============================================================================
# install-docker-buildx.sh
# Install Docker Buildx plugin for multi-platform builds
# https://github.com/docker/buildx
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
install_docker_buildx() {
  log_info "Installing Docker Buildx..."

  # Check if Docker is installed
  if ! command -v docker &>/dev/null; then
    log_error "Docker is not installed - buildx requires Docker Engine"
    log_info "Please install Docker first with install-docker.sh"
    return 1
  fi

  # Check if buildx is already available
  if docker buildx version &>/dev/null; then
    local version=$(docker buildx version)
    log_info "Docker Buildx is already installed: ${version}"
    return 0
  fi

  # Install buildx plugin (usually included with modern Docker)
  log_info "Installing Docker Buildx plugin..."
  cond_apt_install docker-buildx-plugin 2>/dev/null || {
    # Manual installation if apt package not available
    log_info "Installing buildx manually from GitHub..."

    local BUILDX_VERSION=$(curl -s https://api.github.com/repos/docker/buildx/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
    local BUILDX_URL="https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-amd64"

    mkdir -p ~/.docker/cli-plugins
    curl -Lo ~/.docker/cli-plugins/docker-buildx "${BUILDX_URL}"
    chmod +x ~/.docker/cli-plugins/docker-buildx
  }

  # Verify installation
  if docker buildx version &>/dev/null; then
    log_success "Docker Buildx installed successfully"
    log_info "Version: $(docker buildx version)"
    log_info "Create builder: docker buildx create --name mybuilder --use"
  else
    log_error "Docker Buildx installation failed"
    return 1
  fi
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_docker_buildx
fi
