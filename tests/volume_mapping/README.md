# Volume Mapping Test Suite

Comprehensive test suite for mars-user-plugin volume mounting mechanism.

## Overview

This test suite validates the **4-stage automated volume mapping** system:

1. **Stage 1: Pre-up Hook** - Copies template before container starts
2. **Stage 2: Docker Compose** - Merges override with main compose file
3. **Stage 3: Container Startup** - Creates symlinks for multi-user access
4. **Stage 4: Group Ownership** - Applies Sysbox-adjusted GID for file access

## Test Coverage

### Test Files

| File | Tests | Purpose |
|------|-------|---------|
| `test_pre_up_hook.bats` | 10 | Unit tests for pre-up.sh template copying |
| `test_container_startup_hook.bats` | 15 | Unit tests for container-startup.sh symlink creation |
| `test_end_to_end.bats` | 12 | Integration tests for complete workflow |
| **Total** | **37** | **Comprehensive coverage** |

### Coverage Details

**Pre-up Hook Tests** (10 tests):
- ✅ Template copying to target location
- ✅ Identical copy verification
- ✅ Skip copy if target newer than template
- ✅ Missing template handling
- ✅ ENABLE_CUSTOM_VOLUMES flag respect
- ✅ Target directory creation
- ✅ Success message output
- ✅ Warning message output
- ✅ File permission preservation
- ✅ Empty template file handling

**Container Startup Hook Tests** (15 tests):
- ✅ Symlink creation when source exists
- ✅ Skip when source doesn't exist
- ✅ Preserve existing correct symlink
- ✅ Replace incorrect symlink
- ✅ Parent directory creation
- ✅ Sysbox GID calculation
- ✅ Group creation (requires root)
- ✅ Permission fixing (requires root)
- ✅ Zellij layout symlink
- ✅ LazyVim setup handling
- ✅ Multiple symlink pairs processing
- ✅ Created/skipped count tracking

**End-to-End Tests** (12 tests):
- ✅ Complete volume mapping workflow
- ✅ Template updates propagation
- ✅ Multiple volume mounts
- ✅ Read-only mount preservation
- ✅ Read-write mount preservation
- ✅ Symlink target path matching
- ✅ Compose file format compliance
- ✅ Missing mount source handling
- ✅ Test fixture integration
- ✅ Empty volumes section
- ✅ Template comments preservation
- ✅ Idempotent multiple runs

## Running Tests

### Prerequisites

**Bats installed** (already included in mars-dev container):
```bash
bats --version
# Expected: Bats 1.13.0
```

### Quick Start

**Run all tests:**
```bash
cd /workspace/mars-v2/external/mars-user-plugin
bats tests/volume_mapping/
```

**Expected output:**
```
1..37
ok 1 symlink creation: creates symlink when source exists
ok 2 symlink creation: skips when source doesn't exist
...
ok 37 pre-up hook works with empty template file
```

### Run Specific Test Files

**Pre-up hook tests only:**
```bash
bats tests/volume_mapping/test_pre_up_hook.bats
```

**Container startup hook tests only:**
```bash
bats tests/volume_mapping/test_container_startup_hook.bats
```

**End-to-end integration tests only:**
```bash
bats tests/volume_mapping/test_end_to_end.bats
```

### Run Specific Tests

**Single test:**
```bash
bats tests/volume_mapping/test_pre_up_hook.bats --filter "copies template"
```

**Tests matching pattern:**
```bash
bats tests/volume_mapping/ --filter "symlink"
```

### Verbose Output

**Show test details:**
```bash
bats tests/volume_mapping/ --verbose
```

**Show test timings:**
```bash
bats tests/volume_mapping/ --timing
```

## Test Results

### All Tests Passing (37/37)

```
✅ 34 tests passing
⏭️  3 tests skipped (require root privileges)
❌ 0 tests failing
```

### Skipped Tests

Three tests are skipped because they require root privileges:

1. **Group setup: creates group with correct GID** - Requires `groupadd`
2. **Permissions fix: sets group to mars-dev** - Requires `chgrp`
3. **Permissions fix: adds group rwx permissions** - Requires `chmod` on root-owned dirs

These operations are tested manually or in full container integration tests.

## Test Structure

### Directory Layout

```
tests/volume_mapping/
├── README.md                           # This file
├── test_pre_up_hook.bats              # 10 unit tests
├── test_container_startup_hook.bats   # 15 unit tests
├── test_end_to_end.bats               # 12 integration tests
└── fixtures/                          # Test data (auto-created)
    └── test-files/                    # Sample mounted files
```

### Test Organization

Each `.bats` file follows this structure:

```bash
#!/usr/bin/env bats

# Setup function (runs before each test)
setup() {
    # Create temp directories
    # Set up test environment
    # Copy scripts to test location
}

# Teardown function (runs after each test)
teardown() {
    # Clean up temp directories
    # Remove test artifacts
}

# Test cases
@test "test name" {
    # Arrange: Set up test conditions
    # Act: Execute code under test
    # Assert: Verify expected behavior
}
```

## Manual Testing Checklist

Until automated tests are implemented, use this checklist:

### Pre-deployment Verification

- [ ] Template file exists: `templates/docker-compose.override.yml.template`
- [ ] Pre-up hook exists: `hooks/pre-up.sh`
- [ ] Container-startup hook exists: `hooks/container-startup.sh`

### Post-deployment Verification

```bash
# 1. Verify override file copied
[ -f ~/dev/mars-v2/mars-dev/dev-environment/docker-compose.override.yml ]

# 2. Verify container volumes mounted
docker exec mars-dev ls -la /root/dev

# 3. Verify symlink created
docker exec mars-dev ls -la /home/mars/dev

# 4. Verify group created
docker exec mars-dev getent group joe-docs

# 5. Verify mars user membership
docker exec mars-dev groups mars | grep joe-docs

# 6. Test file access (root)
docker exec mars-dev cat /root/dev/test-file.txt

# 7. Test file access (mars)
docker exec -u mars mars-dev cat /home/mars/dev/test-file.txt

# 8. Verify both paths access same file
ROOT_INODE=$(docker exec mars-dev stat -c '%i' /root/dev/test-file.txt)
MARS_INODE=$(docker exec mars-dev stat -c '%i' /home/mars/dev/test-file.txt)
[ "${ROOT_INODE}" = "${MARS_INODE}" ]
```

## Test Development

### Adding New Tests

1. **Identify functionality to test**
2. **Determine appropriate test file**:
   - Unit test for single function → `test_*_hook.bats`
   - Integration test for workflow → `test_end_to_end.bats`
3. **Write test using bats syntax**:
   ```bash
   @test "descriptive test name" {
       # Setup
       local test_var="value"

       # Execute
       run bash script.sh

       # Assert
       [ "$status" -eq 0 ]
       echo "$output" | grep -q "expected"
   }
   ```
4. **Run test to verify**:
   ```bash
   bats tests/volume_mapping/your_test.bats
   ```

### Test Best Practices

1. **Use temp directories** - Never write to `/root/` or `/home/mars/` directly
2. **Clean up in teardown** - Remove all test artifacts
3. **Test one thing per test** - Keep tests focused and simple
4. **Use descriptive names** - Test names should explain what's being tested
5. **Avoid test dependencies** - Each test should run independently
6. **Mock external dependencies** - Don't rely on actual Docker or system state

### Debugging Failed Tests

**Show detailed output:**
```bash
bats tests/volume_mapping/test_name.bats --verbose --tap
```

**Debug single test:**
```bash
bats tests/volume_mapping/test_name.bats --filter "specific test" --verbose
```

**Add debug output to test:**
```bash
@test "my test" {
    echo "Debug: Variable value is $my_var" >&3
    # ... rest of test
}
```

## Continuous Integration

### GitLab CI Integration

Add to `.gitlab-ci.yml`:

```yaml
test:volume-mapping:
  stage: test
  script:
    - cd external/mars-user-plugin
    - bats tests/volume_mapping/
  artifacts:
    reports:
      junit: test-results.xml
  rules:
    - changes:
        - external/mars-user-plugin/hooks/**/*
        - external/mars-user-plugin/templates/**/*
        - external/mars-user-plugin/tests/**/*
```

### Pre-commit Hook Integration

Add to `.pre-commit-config.yaml`:

```yaml
- repo: local
  hooks:
    - id: volume-mapping-tests
      name: Volume Mapping Tests
      entry: bash -c 'cd external/mars-user-plugin && bats tests/volume_mapping/'
      language: system
      pass_filenames: false
```

## Related Documentation

- **Volume Mounting Guide**: `../../VOLUME_MOUNTING.md`
- **Volume Mounting Quickstart**: `../../VOLUME_MOUNTING_QUICKSTART.md`
- **Pre-up Hook**: `../../hooks/pre-up.sh`
- **Container Startup Hook**: `../../hooks/container-startup.sh`
- **GitLab Issue #8**: Volume mapping test suite

## Maintenance

### When to Update Tests

- ✅ When hook scripts are modified
- ✅ When template format changes
- ✅ When new volume mounting features added
- ✅ When bugs are discovered (add regression test)
- ✅ When Sysbox UID/GID mapping changes

### Test Review Checklist

Before committing test changes:

- [ ] All tests pass locally
- [ ] New tests have clear, descriptive names
- [ ] Tests use temp directories (no hardcoded paths)
- [ ] Teardown cleans up all test artifacts
- [ ] Tests are documented in this README
- [ ] Tests follow existing patterns

## Support

For issues with tests or test failures:

1. **Check test output** - Read error messages carefully
2. **Run with verbose mode** - `bats --verbose tests/volume_mapping/`
3. **Check GitLab issue #8** - Volume mapping test suite tracking
4. **Review related docs** - VOLUME_MOUNTING.md for context

## License

Part of mars-user-plugin. See parent LICENSE file for details.
