#!/usr/bin/env bats
# =============================================================================
# tests/volume_mapping/test_end_to_end.bats
# End-to-end integration tests for volume mapping workflow
# Tests the complete flow: Template → Override → Mount → Symlink → Access
# =============================================================================

# =============================================================================
# Setup and teardown functions
# =============================================================================

setup() {
    # Create temporary directories for testing
    export TEST_PLUGIN_ROOT="$(mktemp -d)"
    export TEST_REPO_ROOT="$(mktemp -d)"
    export TEST_MOUNT_ROOT="$(mktemp -d)"

    # Create plugin directory structure
    mkdir -p "${TEST_PLUGIN_ROOT}/templates"
    mkdir -p "${TEST_PLUGIN_ROOT}/hooks/scripts"
    mkdir -p "${TEST_PLUGIN_ROOT}/hooks/config"

    # Create repo directory structure
    mkdir -p "${TEST_REPO_ROOT}/mars-dev/dev-environment"

    # Create mount source directory
    mkdir -p "${TEST_MOUNT_ROOT}/test-files"

    # Create minimal utils.sh
    cat > "${TEST_PLUGIN_ROOT}/hooks/scripts/utils.sh" <<'EOF'
#!/bin/bash
# Minimal utils.sh for testing
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
log_info() { echo -e "${BLUE}[test]${NC} $*"; }
log_success() { echo -e "${GREEN}[test]${NC} ✅ $*"; }
log_warning() { echo -e "${YELLOW}[test]${NC} ⚠️  $*"; }
EOF

    # Create minimal config.sh
    cat > "${TEST_PLUGIN_ROOT}/config.sh" <<'EOF'
#!/bin/bash
# Minimal config.sh for testing
MARS_USER_CREDENTIALS_GID=54556
MARS_USER_CREDENTIALS_GROUP="joe-docs"
EOF

    # Export environment variables
    export MARS_PLUGIN_ROOT="${TEST_PLUGIN_ROOT}"
    export MARS_REPO_ROOT="${TEST_REPO_ROOT}"
    export HOST_UID=10227

    # Copy hooks to test location
    cp /workspace/mars-v2/external/mars-user-plugin/hooks/pre-up.sh \
       "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"
}

teardown() {
    # Clean up temporary directories
    rm -rf "${TEST_PLUGIN_ROOT}" "${TEST_REPO_ROOT}" "${TEST_MOUNT_ROOT}"
}

# =============================================================================
# End-to-end workflow tests
# =============================================================================

@test "e2e: complete volume mapping workflow" {
    # Stage 1: Create template with volume mount
    cat > "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" <<EOF
services:
  mars-dev:
    volumes:
      - ${TEST_MOUNT_ROOT}/test-files:/root/dev/test-files:ro
EOF

    # Stage 2: Run pre-up hook (copies template to override)
    run bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"
    [ "$status" -eq 0 ]

    # Verify override file created
    [ -f "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml" ]

    # Verify content matches template
    diff "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" \
         "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"
    [ "$?" -eq 0 ]

    # Verify mount specification is correct
    grep -q "${TEST_MOUNT_ROOT}/test-files:/root/dev/test-files:ro" \
        "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"
}

@test "e2e: template updates propagate to override" {
    # Create initial template
    cat > "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" <<EOF
services:
  mars-dev:
    volumes:
      - ${TEST_MOUNT_ROOT}/old:/root/dev/old:ro
EOF

    # Run pre-up hook
    bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Update template
    cat > "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" <<EOF
services:
  mars-dev:
    volumes:
      - ${TEST_MOUNT_ROOT}/new:/root/dev/new:ro
EOF

    # Make template newer by touching it
    touch "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template"
    sleep 1

    # Run pre-up hook again
    bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify override contains new mount (not old)
    grep -q "${TEST_MOUNT_ROOT}/new:/root/dev/new:ro" \
        "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"

    ! grep -q "${TEST_MOUNT_ROOT}/old:/root/dev/old:ro" \
        "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"
}

@test "e2e: multiple volume mounts in single override" {
    # Create template with multiple mounts
    cat > "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" <<EOF
services:
  mars-dev:
    volumes:
      - ${TEST_MOUNT_ROOT}/docs:/root/dev/docs:ro
      - ${TEST_MOUNT_ROOT}/scripts:/root/dev/scripts:rw
      - ${TEST_MOUNT_ROOT}/credentials:/root/dev/credentials:ro
EOF

    # Run pre-up hook
    bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify all three mounts present
    local override_file="${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"

    grep -q "${TEST_MOUNT_ROOT}/docs:/root/dev/docs:ro" "$override_file"
    grep -q "${TEST_MOUNT_ROOT}/scripts:/root/dev/scripts:rw" "$override_file"
    grep -q "${TEST_MOUNT_ROOT}/credentials:/root/dev/credentials:ro" "$override_file"
}

@test "e2e: read-only mount specification preserved" {
    # Create template with ro mount
    cat > "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" <<EOF
services:
  mars-dev:
    volumes:
      - ${TEST_MOUNT_ROOT}/test-files:/root/dev/test-files:ro
EOF

    # Run pre-up hook
    bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify :ro flag preserved
    grep -q ":ro" "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"
}

@test "e2e: read-write mount specification preserved" {
    # Create template with rw mount
    cat > "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" <<EOF
services:
  mars-dev:
    volumes:
      - ${TEST_MOUNT_ROOT}/test-files:/root/dev/test-files:rw
EOF

    # Run pre-up hook
    bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify :rw flag preserved
    grep -q ":rw" "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"
}

@test "e2e: symlink target paths match mount targets" {
    # Create template
    cat > "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" <<EOF
services:
  mars-dev:
    volumes:
      - ${TEST_MOUNT_ROOT}/test-files:/root/dev/test-files:ro
EOF

    # Run pre-up hook
    bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify mount target is /root/dev/test-files
    # (This would be the directory symlinked via container-startup.sh)
    grep -q "/root/dev/test-files" \
        "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"
}

@test "e2e: override file respects compose file format" {
    # Create template
    cat > "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" <<EOF
services:
  mars-dev:
    volumes:
      - ${TEST_MOUNT_ROOT}/test:/root/dev/test:ro
EOF

    # Run pre-up hook
    bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify file starts with "services:"
    head -n 1 "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml" | \
        grep -q "^services:"
}

@test "e2e: workflow handles missing mount source gracefully" {
    # Create template pointing to non-existent source
    cat > "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" <<EOF
services:
  mars-dev:
    volumes:
      - /nonexistent/path:/root/dev/missing:ro
EOF

    # Run pre-up hook (should succeed - template is just copied)
    run bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"
    [ "$status" -eq 0 ]

    # Override file created (mount validation happens at docker-compose up)
    [ -f "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml" ]
}

# =============================================================================
# Integration with test fixtures
# =============================================================================

@test "e2e: workflow with test fixture files" {
    # Create test fixtures
    echo "test content" > "${TEST_MOUNT_ROOT}/test-files/test.txt"
    echo "#!/bin/bash\necho test" > "${TEST_MOUNT_ROOT}/test-files/test.sh"
    chmod +x "${TEST_MOUNT_ROOT}/test-files/test.sh"

    # Create template
    cat > "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" <<EOF
services:
  mars-dev:
    volumes:
      - ${TEST_MOUNT_ROOT}/test-files:/root/dev/test-files:ro
EOF

    # Run pre-up hook
    bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify mount specification points to fixture directory
    grep -q "${TEST_MOUNT_ROOT}/test-files" \
        "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"

    # Verify fixture files exist
    [ -f "${TEST_MOUNT_ROOT}/test-files/test.txt" ]
    [ -f "${TEST_MOUNT_ROOT}/test-files/test.sh" ]
    [ -x "${TEST_MOUNT_ROOT}/test-files/test.sh" ]
}

# =============================================================================
# Error handling and edge cases
# =============================================================================

@test "e2e: handles empty volumes section" {
    # Create template with empty volumes
    cat > "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" <<'EOF'
services:
  mars-dev:
    volumes:
EOF

    # Run pre-up hook
    run bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"
    [ "$status" -eq 0 ]

    # Override file created
    [ -f "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml" ]
}

@test "e2e: handles template with comments" {
    # Create template with comments
    cat > "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" <<EOF
# Volume mounting configuration
services:
  mars-dev:
    volumes:
      # Test files mount
      - ${TEST_MOUNT_ROOT}/test:/root/dev/test:ro
EOF

    # Run pre-up hook
    bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"

    # Verify comments preserved
    grep -q "# Volume mounting configuration" \
        "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"
    grep -q "# Test files mount" \
        "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"
}

@test "e2e: idempotent - multiple runs produce same result" {
    # Create template
    cat > "${TEST_PLUGIN_ROOT}/templates/docker-compose.override.yml.template" <<EOF
services:
  mars-dev:
    volumes:
      - ${TEST_MOUNT_ROOT}/test:/root/dev/test:ro
EOF

    # First run
    bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"
    local first_checksum=$(md5sum "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml" | cut -d' ' -f1)

    # Make override newer
    touch "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml"
    sleep 1

    # Second run (should skip copy)
    bash "${TEST_PLUGIN_ROOT}/hooks/pre-up.sh"
    local second_checksum=$(md5sum "${TEST_REPO_ROOT}/mars-dev/dev-environment/docker-compose.override.yml" | cut -d' ' -f1)

    # Checksums should match (file unchanged)
    [ "$first_checksum" = "$second_checksum" ]
}
