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
#
# Usage:
#   ./integrate-permissions.sh              # Auto-detect plugin location
#   ./integrate-permissions.sh /path/to/plugin  # Explicit plugin path
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
# Configuration - Auto-detect or use argument
# =============================================================================

# Get the directory containing this script (plugin root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Plugin directory: use argument, or script location, or MARS_PLUGIN_ROOT
PLUGIN_DIR="${1:-${MARS_PLUGIN_ROOT:-$SCRIPT_DIR}}"

# Find MARS repo root by searching upward for mars-env.config
find_mars_root() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/mars-env.config" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Try to find MARS repo root
if [ -n "${MARS_REPO_ROOT:-}" ]; then
    # Use existing MARS_REPO_ROOT if set
    :
elif MARS_REPO_ROOT=$(find_mars_root "$PLUGIN_DIR"); then
    # Found by searching upward
    :
else
    log_error "Cannot find MARS repository root"
    log_error "Run this script from within a MARS repository or set MARS_REPO_ROOT"
    exit 1
fi

# Verify plugin directory exists
if [ ! -d "$PLUGIN_DIR" ]; then
    log_error "Plugin directory not found: $PLUGIN_DIR"
    exit 1
fi

# Verify plugin has config.sh
if [ ! -f "$PLUGIN_DIR/config.sh" ]; then
    log_error "Plugin config.sh not found: $PLUGIN_DIR/config.sh"
    log_error "Create config.sh with MARS_USER_CREDENTIALS_GROUP and MARS_USER_CREDENTIALS_GID"
    exit 1
fi

# Source plugin configuration to get group name and paths
source "${PLUGIN_DIR}/config.sh"

# Verify required variables are set
if [ -z "${MARS_USER_CREDENTIALS_GROUP:-}" ]; then
    log_error "MARS_USER_CREDENTIALS_GROUP not set in config.sh"
    exit 1
fi

if [ -z "${MARS_USER_CREDENTIALS_GID:-}" ]; then
    log_error "MARS_USER_CREDENTIALS_GID not set in config.sh"
    exit 1
fi

log_info "Starting user plugin permission system integration..."
log_info "MARS repo:         ${MARS_REPO_ROOT}"
log_info "Plugin:            ${PLUGIN_DIR}"
log_info "Credential group:  ${MARS_USER_CREDENTIALS_GROUP}"
log_info "Credential GID:    ${MARS_USER_CREDENTIALS_GID}"
echo ""

# =============================================================================
# Phase 1: Host Setup
# =============================================================================
log_info "Phase 1: Host Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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
if [ -n "${MARS_USER_CREDENTIALS_DIR:-}" ] && [ -d "${MARS_USER_CREDENTIALS_DIR}" ]; then
    # Find first file in credentials directory
    first_file=$(find "${MARS_USER_CREDENTIALS_DIR}" -type f 2>/dev/null | head -1)
    if [ -n "$first_file" ]; then
        file_group=$(stat -c '%G' "$first_file" 2>/dev/null || echo "unknown")
        if [ "$file_group" = "${MARS_USER_CREDENTIALS_GROUP}" ]; then
            log_success "Credential files have ${MARS_USER_CREDENTIALS_GROUP} group"
        else
            log_warning "Credential files have group: $file_group (expected ${MARS_USER_CREDENTIALS_GROUP})"
        fi
    fi
else
    log_warning "Credentials directory not set or not found: ${MARS_USER_CREDENTIALS_DIR:-<not set>}"
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
if [ -n "${MARS_USER_CREDENTIALS_DIR:-}" ]; then
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
fi

echo ""

# Test environment variables
log_info "Testing environment variable exports..."
result=$(mars-dev exec -u mars mars-dev bash -c "cd /workspace/mars-v2 && source mars-env.config 2>/dev/null && printenv | grep -E '(CURL_CA_BUNDLE|MARS_.*_CA_BUNDLE)' | head -1" 2>/dev/null || echo "")
if [ -n "$result" ]; then
    log_success "Environment variables exported: $result"
else
    log_warning "Environment variables not exported (may need to source mars-env.config)"
fi

echo ""

# =============================================================================
# Phase 4: Run Tests (if available)
# =============================================================================
log_info "Phase 4: Run Regression Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TEST_FILE="$MARS_REPO_ROOT/mars-dev/tests/test_user_plugin_permissions.py"

if [ -f "$TEST_FILE" ]; then
    cd "$MARS_REPO_ROOT/mars-dev"

    log_info "Running plugin permission tests..."
    if python3 -m pytest tests/test_user_plugin_permissions.py -v --tb=short 2>&1 | tee /tmp/pytest-output.txt | grep -E "(PASSED|FAILED|ERROR|passed|failed)"; then
        if grep -qE "[0-9]+ passed" /tmp/pytest-output.txt; then
            passed_count=$(grep -oE "[0-9]+ passed" /tmp/pytest-output.txt | grep -oE "[0-9]+")
            log_success "Tests passed: ${passed_count}"
        else
            log_warning "Some tests may have failed - check output above"
        fi
    else
        log_error "Test execution failed"
    fi
else
    log_warning "Test file not found: $TEST_FILE"
    log_warning "Skipping regression tests"
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
echo "  - Full guide: ${PLUGIN_DIR}/INTEGRATION_GUIDE.md"
if [ -f /tmp/pytest-output.txt ]; then
    echo "  - Test results: /tmp/pytest-output.txt"
fi
echo ""
log_info "Done!"
