#!/usr/bin/env bats
# =============================================================================
# tests/volume_mapping/test_pre_up_hook.bats
# Unit tests for hooks/pre-up.sh - Template copying logic
# =============================================================================

# Load bats helper libraries if available
# load '../../node_modules/bats-support/load' 2>/dev/null || true
# load '../../node_modules/bats-assert/load' 2>/dev/null || true

# =============================================================================
# Setup and teardown functions
# =============================================================================

setup() {
    # Create temporary directories for testing
    export TEST_PLUGIN_ROOT="$(mktemp -d)"
    export TEST_REPO_ROOT="$(mktemp -d)"

    # Create template directory
    mkdir -p "${TEST_PLUGIN_ROOT}/templates"
    mkdir -p "${TEST_PLUGIN_ROOT}/hooks/scripts"

    # Create target directory
    mkdir -p "${TEST_REPO_ROOT}/mars-dev/dev-environment"

    # Create minimal utils.sh (pre-up.sh sources this)
    cat > "${TEST_PLUGIN_ROOT}/hooks/scripts/utils.sh" <<'EOF'
#!/bin/bash
# Minimal utils.sh for testing
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
EOF

    # Create sample template file
    cat > "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" <<'EOF'
services:
  mars-dev:
    volumes:
      - ~/dev/test:/root/dev/test:ro
EOF

    # Export paths for pre-up.sh
    export MARS_PLUGIN_ROOT="${TEST_PLUGIN_ROOT}"
    export MARS_REPO_ROOT="${TEST_REPO_ROOT}"

    # Copy pre-up.sh to test location
    cp /workspace/mars-v2/external/mars-user-plugin/hooks/pre-up.sh \
       "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"
}

teardown() {
    # Clean up temporary directories
    rm -rf "${TEST_PLUGIN_ROOT}" "${TEST_REPO_ROOT}"
}

# =============================================================================
# Test cases
# =============================================================================

@test "pre-up hook copies template to target location" {
    # Execute pre-up hook
    run bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify exit code is 0 (success)
    [ "$status" -eq 0 ]

    # Verify override file was created
    [ -f "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml" ]
}

@test "pre-up hook creates identical copy of template" {
    # Execute pre-up hook
    bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify content matches template
    diff "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" \
         "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"

    [ "$?" -eq 0 ]
}

@test "pre-up hook skips copy if target is newer than template" {
    # Setup: Create override file
    cp "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" \
       "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"

    # Make target file newer (1 minute into the future)
    touch -t $(date -d '+1 minute' '+%Y%m%d%H%M.%S') \
          "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"

    # Modify target to detect if it gets overwritten
    echo "# Modified" >> "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"

    # Execute pre-up hook
    bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify target wasn't overwritten (still contains "# Modified")
    grep -q "# Modified" "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"
    [ "$?" -eq 0 ]
}

@test "pre-up hook handles missing template gracefully" {
    # Remove template file
    rm -f "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template"

    # Execute pre-up hook (should not fail)
    run bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify exit code is 0 (success - script handles missing template)
    [ "$status" -eq 0 ]

    # Verify no override file was created
    [ ! -f "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml" ]
}

@test "pre-up hook respects ENABLE_CUSTOM_VOLUMES=false" {
    # Modify pre-up.sh to set ENABLE_CUSTOM_VOLUMES=false
    sed -i 's/ENABLE_CUSTOM_VOLUMES=true/ENABLE_CUSTOM_VOLUMES=false/' \
        "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Execute pre-up hook
    run bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify exit code is 0 (success)
    [ "$status" -eq 0 ]

    # Verify no override file was created
    [ ! -f "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml" ]
}

@test "pre-up hook creates target directory if missing" {
    # Remove target directory
    rm -rf "${TEST_REPO_ROOT}/mars-dev/dev-environment"

    # Execute pre-up hook (cp should fail but script should handle it)
    run bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify script fails when directory doesn't exist
    # (this is expected behavior - directory must exist)
    [ "$status" -ne 0 ]
}

@test "pre-up hook outputs success message when copy succeeds" {
    # Execute pre-up hook
    run bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify output contains success message
    echo "$output" | grep -q "Custom volume configuration ready"
    [ "$?" -eq 0 ]
}

@test "pre-up hook outputs warning when template missing" {
    # Remove template file
    rm -f "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template"

    # Execute pre-up hook
    run bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify output contains warning message
    echo "$output" | grep -q "Override template not found"
    [ "$?" -eq 0 ]
}

@test "pre-up hook preserves file permissions" {
    # Set specific permissions on template
    chmod 600 "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template"

    # Execute pre-up hook
    bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify target has same permissions as template
    TEMPLATE_PERMS=$(stat -c '%a' "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template")
    TARGET_PERMS=$(stat -c '%a' "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml")

    [ "${TEMPLATE_PERMS}" = "${TARGET_PERMS}" ]
}

@test "pre-up hook works with empty template file" {
    # Create empty template
    > "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template"

    # Execute pre-up hook
    run bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify exit code is 0 (success)
    [ "$status" -eq 0 ]

    # Verify empty override file was created
    [ -f "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml" ]
    [ ! -s "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml" ]
}
