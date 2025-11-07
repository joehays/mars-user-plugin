#!/bin/bash
# =============================================================================
# install-open-webui.sh
# Install Open WebUI - Web interface for Ollama and other LLMs
# https://github.com/open-webui/open-webui
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
install_open_webui() {
  log_info "Installing Open WebUI..."

  # Check if Docker is installed
  if ! command -v docker &>/dev/null; then
    log_error "Docker is not installed - Open WebUI requires Docker"
    log_info "Please install Docker first with install-docker.sh"
    return 1
  fi

  # Check if container already exists
  if docker ps -a --format '{{.Names}}' | grep -q '^open-webui$'; then
    log_info "Open WebUI container already exists"
    log_info "Start with: docker start open-webui"
    log_info "Access at: http://localhost:3000"
    return 0
  fi

  # Run Open WebUI container
  log_info "Starting Open WebUI container..."
  docker run -d \
    --name open-webui \
    -p 3000:8080 \
    --add-host=host.docker.internal:host-gateway \
    -v open-webui:/app/backend/data \
    --restart always \
    ghcr.io/open-webui/open-webui:main

  log_success "Open WebUI installed and started successfully"
  log_info "Access at: http://localhost:3000"
  log_info "Stop with: docker stop open-webui"
  log_info "Start with: docker start open-webui"
  log_info "Note: Ensure Ollama is running to use local models"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_open_webui
fi
