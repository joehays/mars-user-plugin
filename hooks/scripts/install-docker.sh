#!/bin/bash
# =============================================================================
# install-docker.sh
# Install Docker Engine
# https://docs.docker.com/engine/install/ubuntu/
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
install_docker() {
  log_info "Installing Docker Engine..."

  # Check if already installed
  if command -v docker &>/dev/null; then
    local version=$(docker --version)
    log_info "Docker is already installed: ${version}"
    return 0
  fi

  # Remove old versions
  log_info "Removing old Docker versions..."
  apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

  # Install prerequisites
  log_info "Installing prerequisites..."
  cond_apt_install ca-certificates
  cond_apt_install curl
  cond_apt_install gnupg

  # Add Docker's official GPG key
  log_info "Adding Docker GPG key..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  # Add Docker repository
  log_info "Adding Docker repository..."
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Install Docker Engine
  apt-get update
  cond_apt_install docker-ce
  cond_apt_install docker-ce-cli
  cond_apt_install containerd.io
  cond_apt_install docker-buildx-plugin
  cond_apt_install docker-compose-plugin

  # Add current user to docker group (if not root)
  if [ "${USER}" != "root" ] && [ -n "${USER:-}" ]; then
    log_info "Adding ${USER} to docker group..."
    usermod -aG docker "${USER}"
  fi

  log_success "Docker Engine installed successfully"
  log_info "Version: $(docker --version)"
  log_info "Note: You may need to log out and back in for group changes to take effect"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_docker
fi
