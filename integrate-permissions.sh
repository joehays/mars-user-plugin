#!/bin/bash
# =============================================================================
# integrate-permissions.sh
# Quick integration script for user plugin permission system
#
# This script automates the integration process:
# 1. Sets up credential group and permissions on host (via plugin hooks)
# 2. Rebuilds mars-dev container with new GID calculations
# 3. Verifies container can access credentials
# 4. Runs regression tests
# =============================================================================
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }

# =============================================================================
# Configuration
# =============================================================================
MARS_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_DIR="${MARS_REPO_ROOT}/external/mars-user-plugin"

# Source plugin configuration to get group name and paths
source "${PLUGIN_DIR}/config.sh"

log_info "Starting user plugin permission system integration..."
log_info "Plugin: ${PLUGIN_DIR}"
log_info "Credential group: ${MARS_USER_CREDENTIALS_GROUP}"
echo ""

# =============================================================================
# Phase 1: Host Setup
# =============================================================================
log_info "Phase 1: Host Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check plugin exists
if [ ! -d "$PLUGIN_DIR" ]; then
    log_error "Plugin not found: $PLUGIN_DIR"
    exit 1
fi

# Run host permissions setup
log_info "Running host-permissions.sh..."
if [ -f "$PLUGIN_DIR/hooks/host-permissions.sh" ]; then
    if "$PLUGIN_DIR/hooks/host-permissions.sh"; then
        log_success "Host permissions configured"
    else
        log_error "Host permissions setup failed"
        exit 1
    fi
else
    log_error "host-permissions.sh not found at $PLUGIN_DIR/hooks/"
    exit 1
fi

echo ""

# Verify host setup
log_info "Verifying host setup..."

# Check user in credential group
if groups | grep -q "\b${MARS_USER_CREDENTIALS_GROUP}\b"; then
    log_success "User is in ${MARS_USER_CREDENTIALS_GROUP} group"
else
    log_warning "User NOT in ${MARS_USER_CREDENTIALS_GROUP} group yet"
    log_warning "You may need to log out/in or run: newgrp ${MARS_USER_CREDENTIALS_GROUP}"
fi

# Check credential group exists
if getent group "${MARS_USER_CREDENTIALS_GROUP}" &>/dev/null; then
    gid=$(getent group "${MARS_USER_CREDENTIALS_GROUP}" | cut -d: -f3)
    log_success "${MARS_USER_CREDENTIALS_GROUP} group exists (GID: $gid)"
else
    log_error "${MARS_USER_CREDENTIALS_GROUP} group not created"
    exit 1
fi

# Check credential file permissions (check first file in credentials dir)
if [ -d "${MARS_USER_CREDENTIALS_DIR}" ]; then
    # Find first file in credentials directory
    first_file=$(find "${MARS_USER_CREDENTIALS_DIR}" -type f | head -1)
    if [ -n "$first_file" ]; then
        file_group=$(stat -c '%G' "$first_file" 2>/dev/null || echo "unknown")
        if [ "$file_group" = "${MARS_USER_CREDENTIALS_GROUP}" ]; then
            log_success "Credential files have ${MARS_USER_CREDENTIALS_GROUP} group"
        else
            log_warning "Credential files have group: $file_group (expected ${MARS_USER_CREDENTIALS_GROUP})"
        fi
    fi
else
    log_warning "Credentials directory not found: ${MARS_USER_CREDENTIALS_DIR}"
fi

echo ""

# =============================================================================
# Phase 2: Container Rebuild
# =============================================================================
log_info "Phase 2: Container Rebuild"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$MARS_REPO_ROOT"

# Stop existing container
log_info "Stopping existing mars-dev container..."
if mars-dev down 2>&1; then
    log_success "Container stopped"
else
    log_warning "No existing container to stop"
fi

echo ""

# Rebuild container
log_info "Rebuilding mars-dev container (this may take 2-5 minutes)..."
if mars-dev build --no-cache 2>&1; then
    log_success "Container rebuilt successfully"
else
    log_error "Container rebuild failed"
    exit 1
fi

echo ""

# Start container
log_info "Starting mars-dev container..."
if mars-dev up -d 2>&1; then
    log_success "Container started"
else
    log_error "Container start failed"
    exit 1
fi

# Wait for container to be ready
log_info "Waiting for container to initialize (5 seconds)..."
sleep 5

echo ""

# =============================================================================
# Phase 3: Container Verification
# =============================================================================
log_info "Phase 3: Container Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check container is running
if mars-dev ps 2>&1 | grep -q mars-dev; then
    log_success "Container is running"
else
    log_error "Container not running"
    exit 1
fi

# Check mars-dev group in container
log_info "Checking mars-dev group in container..."
if mars-dev exec mars-dev getent group mars-dev &>/dev/null; then
    container_gid=$(mars-dev exec mars-dev getent group mars-dev | cut -d: -f3)
    expected_gid=$((55555 - $(id -u)))
    if [ "$container_gid" = "$expected_gid" ]; then
        log_success "mars-dev group GID correct: $container_gid"
    else
        log_warning "mars-dev group GID mismatch: $container_gid (expected $expected_gid)"
    fi
else
    log_error "mars-dev group not found in container"
fi

# Check credential group in container
log_info "Checking ${MARS_USER_CREDENTIALS_GROUP} group in container..."
if mars-dev exec mars-dev getent group "${MARS_USER_CREDENTIALS_GROUP}" &>/dev/null; then
    container_gid=$(mars-dev exec mars-dev getent group "${MARS_USER_CREDENTIALS_GROUP}" | cut -d: -f3)
    expected_gid=$((${MARS_USER_CREDENTIALS_GID} - $(id -u)))
    if [ "$container_gid" = "$expected_gid" ]; then
        log_success "${MARS_USER_CREDENTIALS_GROUP} group GID correct: $container_gid"
    else
        log_warning "${MARS_USER_CREDENTIALS_GROUP} group GID mismatch: $container_gid (expected $expected_gid)"
    fi
else
    log_error "${MARS_USER_CREDENTIALS_GROUP} group not found in container"
fi

# Check mars user groups
log_info "Checking mars user group membership..."
if mars-dev exec mars-dev id mars | grep -q "${MARS_USER_CREDENTIALS_GROUP}"; then
    log_success "mars user is member of ${MARS_USER_CREDENTIALS_GROUP} group"
else
    log_error "mars user NOT in ${MARS_USER_CREDENTIALS_GROUP} group"
fi

echo ""

# Test credential access (check if credentials directory is accessible)
log_info "Testing mars user credential access..."
if mars-dev exec -u mars mars-dev test -d "${MARS_USER_CREDENTIALS_DIR}" &>/dev/null; then
    log_success "mars user CAN access credentials directory: ${MARS_USER_CREDENTIALS_DIR}"

    # Try to read a file if it exists
    first_file=$(mars-dev exec -u mars mars-dev find "${MARS_USER_CREDENTIALS_DIR}" -type f 2>/dev/null | head -1)
    if [ -n "$first_file" ]; then
        if mars-dev exec -u mars mars-dev cat "$first_file" &>/dev/null; then
            log_success "mars user CAN read credential files"
        else
            log_warning "mars user CANNOT read credential files (permission denied)"
        fi
    fi
else
    log_error "mars user CANNOT access credentials directory (permission denied)"
    log_error "This may require fixing host permissions or rebuilding container"
fi

echo ""

# Test environment variables
log_info "Testing environment variable exports..."
result=$(mars-dev exec -u mars mars-dev bash -c "cd /workspace/mars-v2 && source mars-env.config 2>/dev/null && printenv | grep -E '(CURL_CA_BUNDLE|MARS_.*_CA_BUNDLE)' | head -1")
if [ -n "$result" ]; then
    log_success "Environment variables exported: $result"
else
    log_warning "Environment variables not exported (may need to source mars-env.config)"
fi

echo ""

# =============================================================================
# Phase 4: Run Tests
# =============================================================================
log_info "Phase 4: Run Regression Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$MARS_REPO_ROOT/mars-dev"

log_info "Running plugin permission tests..."
if python3 -m pytest tests/test_user_plugin_permissions.py -v --tb=short 2>&1 | tee /tmp/pytest-output.txt | grep -E "(PASSED|FAILED|ERROR|passed|failed)"; then
    if grep -q "20 passed" /tmp/pytest-output.txt; then
        log_success "All 20 tests passed!"
    else
        log_warning "Some tests may have failed - check output above"
    fi
else
    log_error "Test execution failed"
fi

echo ""

# =============================================================================
# Summary
# =============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "Integration complete!"
echo ""
echo "Next steps:"
echo "  1. Verify credentials work: mars-dev attach (or mars-dev exec -u mars mars-dev bash)"
echo "  2. Test credential access inside container"
echo "  3. Commit changes to git"
echo ""
echo "Documentation:"
echo "  - Full guide: external/mars-user-plugin/INTEGRATION_GUIDE.md"
echo "  - Test results: /tmp/pytest-output.txt"
echo ""
log_info "Done!"
