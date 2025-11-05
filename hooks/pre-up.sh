#!/bin/bash
# =============================================================================
# mars-plugin/hooks/pre-up.sh
# Pre-up hook: Copy user-specific docker-compose.override.yml before starting E6
#
# Execution context:
#   - Runs on HOST before 'mars-dev up' command
#   - Working directory: mars-dev/dev-environment/
#   - MARS_PLUGIN_ROOT: Path to this plugin directory
#   - MARS_REPO_ROOT: Path to MARS repository
# =============================================================================
set -euo pipefail

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[joehays-plugin:pre-up]${NC} $*"; }
log_success() { echo -e "${GREEN}[joehays-plugin:pre-up]${NC} ✅ $*"; }
log_warning() { echo -e "${YELLOW}[joehays-plugin:pre-up]${NC} ⚠️  $*"; }

# =============================================================================
# Configuration
# =============================================================================
ENABLE_CUSTOM_VOLUMES=true   # Set to false to disable custom volume mounting

# Paths
OVERRIDE_TEMPLATE="${MARS_PLUGIN_ROOT}/templates/docker-compose.override.yml.template"
OVERRIDE_TARGET="${MARS_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"

# =============================================================================
# Main: Copy docker-compose override if enabled
# =============================================================================
main() {
    log_info "Checking for custom volume configuration..."

    # Check if custom volumes are enabled
    if [ "${ENABLE_CUSTOM_VOLUMES}" != true ]; then
        log_info "Custom volumes disabled (skipping override file)"
        return 0
    fi

    # Check if template exists
    if [ ! -f "${OVERRIDE_TEMPLATE}" ]; then
        log_warning "Override template not found at: ${OVERRIDE_TEMPLATE}"
        log_warning "Skipping custom volume mount setup"
        return 0
    fi

    # Check if target already exists and is newer than template
    if [ -f "${OVERRIDE_TARGET}" ]; then
        if [ "${OVERRIDE_TARGET}" -nt "${OVERRIDE_TEMPLATE}" ]; then
            log_info "Override file is up-to-date (no changes needed)"
            return 0
        fi
    fi

    # Copy template to target location
    log_info "Copying volume override configuration..."
    cp "${OVERRIDE_TEMPLATE}" "${OVERRIDE_TARGET}"

    # Verify copy succeeded
    if [ -f "${OVERRIDE_TARGET}" ]; then
        log_success "Custom volume configuration ready"
        log_info "Edit ${OVERRIDE_TARGET} to customize volume mounts"
    else
        log_warning "Failed to create override file"
        return 1
    fi
}

# Run main function
main
