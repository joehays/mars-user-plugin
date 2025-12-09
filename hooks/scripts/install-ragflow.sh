#!/bin/bash
# =============================================================================
# install-ragflow.sh
# Install RAGFlow - Open-source RAG engine for deep document understanding
# https://github.com/infiniflow/ragflow
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
install_ragflow() {
  log_info "Installing RAGFlow..."

  # Check if Docker is installed (auto-install if missing)
  ensure_docker || {
    log_error "Cannot install RAGFlow without Docker"
    return 1
  }

  # Ensure git is available for cloning
  ensure_git || { log_error "Cannot clone RAGFlow without git"; return 1; }

  # Check if RAGFlow directory already exists
  local RAGFLOW_DIR="${HOME}/ragflow"
  if [ -d "${RAGFLOW_DIR}" ]; then
    log_info "RAGFlow directory already exists at ${RAGFLOW_DIR}"
    log_info "Start with: cd ${RAGFLOW_DIR} && docker compose up -d"
    return 0
  fi

  # Clone RAGFlow repository
  log_info "Cloning RAGFlow repository..."
  git clone https://github.com/infiniflow/ragflow.git "${RAGFLOW_DIR}"

  # Copy environment file
  log_info "Configuring RAGFlow..."
  cd "${RAGFLOW_DIR}"
  cp docker/.env.example docker/.env

  # Build and start RAGFlow
  log_info "Building and starting RAGFlow containers..."
  docker compose -f docker/docker-compose.yml up -d

  log_success "RAGFlow installed and started successfully"
  log_info "Installation directory: ${RAGFLOW_DIR}"
  log_info "Access at: http://localhost:9380"
  log_info "Stop with: cd ${RAGFLOW_DIR} && docker compose -f docker/docker-compose.yml down"
  log_info "Note: First startup may take several minutes to download models"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_ragflow
fi
