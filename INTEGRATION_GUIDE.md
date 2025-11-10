# Integration Guide: joe-docs Permission System

Step-by-step guide to integrate the new plugin-based permission system for joe-docs credentials.

## Quick Start (Automated)

For automated integration, use the provided script:

```bash
cd ~/dev/mars-v2/external/mars-user-plugin
./integrate-permissions.sh
```

This script automates all four phases below: host setup, container rebuild, verification, and testing.

For manual step-by-step instructions, continue reading below.

---

## Prerequisites

- User plugin registered: `external/mars-user-plugin`
- Changes committed to git (optional but recommended)
- Docker installed and accessible

---

## Phase 1: Host Setup (One-Time)

### Step 1: Verify Plugin Configuration

Check that the plugin configuration is correct:

```bash
cd ~/dev/mars-v2

# Verify config.sh exists and has correct values
cat external/mars-user-plugin/config.sh
# Expected:
#   MARS_USER_CREDENTIALS_GID=55556
#   MARS_USER_CREDENTIALS_GROUP="joe-docs"
#   MARS_USER_CREDENTIALS_DIR="$HOME/dev/joe-docs/dev-ops"

# Verify env-setup hook exists and is executable
ls -la external/mars-user-plugin/hooks/env-setup.sh
# Expected: -rwxr-xr-x ... env-setup.sh

# Verify host-permissions hook exists and is executable
ls -la external/mars-user-plugin/hooks/host-permissions.sh
# Expected: -rwxr-xr-x ... host-permissions.sh
```

### Step 2: Create joe-docs Group and Set Permissions

Run the host-permissions setup script:

```bash
cd ~/dev/mars-v2

# Option A: Run directly (will prompt for sudo if needed)
external/mars-user-plugin/hooks/host-permissions.sh

# Option B: Via mars-env.config (automatic on next source)
source mars-env.config
# The script will run automatically if joe-docs group doesn't exist
```

**What this does:**
1. Creates `joe-docs` group (GID 55556) on host
2. Adds your user (joehays) to joe-docs group
3. Sets group ownership on credential files:
   - `~/dev/joe-docs/dev-ops/get_capra_access_token.sh` → `joehays:joe-docs` (750)
   - `~/dev/joe-docs/dev-ops/capra_access_token` → `joehays:joe-docs` (640)
   - `~/dev/joe-docs/dev-ops/capra-api-key` → `joehays:joe-docs` (750)
   - `~/dev/joe-docs/dev-ops/Certificates_PKCS7_v5_14_DoD/DoD_PKE_CA_chain.pem` → `joehays:joe-docs` (644)

### Step 3: Verify Host Setup

```bash
# Check user is in joe-docs group
groups | grep joe-docs
# Expected: ... joe-docs ...

# Check joe-docs group exists with correct GID
getent group joe-docs
# Expected: joe-docs:x:55556:joehays

# Check credential files have correct group
ls -l ~/dev/joe-docs/dev-ops/get_capra_access_token.sh
# Expected: -rwxr-x--- joehays joe-docs ... get_capra_access_token.sh

ls -l ~/dev/joe-docs/dev-ops/capra_access_token
# Expected: -rw-r----- joehays joe-docs ... capra_access_token

ls -l ~/dev/joe-docs/dev-ops/capra-api-key
# Expected: -rwxr-x--- joehays joe-docs ... capra-api-key

ls -l ~/dev/joe-docs/dev-ops/Certificates_PKCS7_v5_14_DoD/DoD_PKE_CA_chain.pem
# Expected: -rw-r--r-- joehays joe-docs ... DoD_PKE_CA_chain.pem
```

**IMPORTANT:** If you just added yourself to joe-docs group, you may need to log out and back in, OR run:

```bash
# Activate group membership in current shell
newgrp joe-docs

# Verify it worked
groups
# Should now show joe-docs
```

---

## Phase 2: Rebuild mars-dev Container

### Step 4: Stop Existing Container

```bash
cd ~/dev/mars-v2/mars-dev/dev-environment

# Stop and remove existing container
DOCKER_HOST= docker compose down

# Optional: Remove old image to force full rebuild
DOCKER_HOST= docker rmi mars-dev:latest
```

### Step 5: Rebuild Container with New Configuration

```bash
cd ~/dev/mars-v2/mars-dev/dev-environment

# Rebuild container (picks up new Dockerfile with fixed GID calculation)
DOCKER_HOST= docker compose build --no-cache

# Expected output should show:
#   - Building mars-dev
#   - Stage 9: Non-Root User Setup
#   - Creating mars-dev group with Sysbox-adjusted GID
#   - Creating mars user...
```

**Key changes in new build:**
- Dockerfile line 215: `groupadd -g $((${MARS_DEV_GID} - ${HOST_UID})) mars-dev`
- Dockerfile: mars-dev group GID = 55555 - 10227 = 45328
- docker-compose.yml: Exports `HOST_UID` environment variable

### Step 6: Start Container

```bash
cd ~/dev/mars-v2/mars-dev/dev-environment

# Start container
DOCKER_HOST= docker compose up -d

# Wait for container to start (~5-10 seconds)
sleep 5

# Check container is running
DOCKER_HOST= docker ps | grep mars-dev
# Expected: mars-dev container with status "Up"
```

---

## Phase 3: Verify Container Setup

### Step 7: Verify Container Groups

```bash
# Check mars-dev group in container
DOCKER_HOST= docker exec mars-dev getent group mars-dev
# Expected: mars-dev:x:45328:mars
#           (45328 = 55555 - 10227)

# Check joe-docs group in container
DOCKER_HOST= docker exec mars-dev getent group joe-docs
# Expected: joe-docs:x:45329:mars
#           (45329 = 55556 - 10227)

# Check mars user's groups
DOCKER_HOST= docker exec mars-dev id mars
# Expected: uid=10227(mars) gid=0(root) groups=0(root),45328(mars-dev),45329(joe-docs),...
```

### Step 8: Verify mars User Can Access Credentials

```bash
# Test mars user can read capra_access_token
DOCKER_HOST= docker exec -u mars mars-dev cat /root/dev/joe-docs/dev-ops/capra_access_token
# Expected: [your CAPRA token contents]
# If this fails with "Permission denied", check Step 3 and Step 7

# Test mars user can execute get_capra_access_token.sh
DOCKER_HOST= docker exec -u mars mars-dev /root/dev/joe-docs/dev-ops/get_capra_access_token.sh
# Expected: [your CAPRA token]

# Test mars user can read CA bundle
DOCKER_HOST= docker exec -u mars mars-dev cat /root/dev/joe-docs/dev-ops/Certificates_PKCS7_v5_14_DoD/DoD_PKE_CA_chain.pem | head -5
# Expected: -----BEGIN CERTIFICATE-----
```

### Step 9: Verify Environment Variables (Inside Container)

```bash
# Enter container as mars user
DOCKER_HOST= docker exec -it -u mars mars-dev bash

# Source mars-env.config (should trigger env-setup hook)
cd /workspace/mars-v2
source mars-env.config

# Verify environment variables are set
echo "CURL_CA_BUNDLE=$CURL_CA_BUNDLE"
# Expected: CURL_CA_BUNDLE=/root/dev/joe-docs/dev-ops/Certificates_PKCS7_v5_14_DoD/DoD_PKE_CA_chain.pem

echo "MARS_ASKSAGE_CA_BUNDLE=$MARS_ASKSAGE_CA_BUNDLE"
# Expected: Same as CURL_CA_BUNDLE

echo "MARS_ASKSAGE_KEY=$MARS_ASKSAGE_KEY"
# Expected: [your CAPRA token - should not be empty]

echo "AIDER_CA_BUNDLE=$AIDER_CA_BUNDLE"
# Expected: Same as CURL_CA_BUNDLE

# Exit container
exit
```

---

## Phase 4: Testing

### Step 10: Run Regression Tests

```bash
cd ~/dev/mars-v2/mars-dev

# Run the plugin permission tests
python3 -m pytest tests/test_user_plugin_permissions.py -v

# Expected: 20 passed in ~3 seconds
```

### Step 11: Test Multi-Instance Support (Optional)

If you want to verify multi-instance support works:

```bash
# Terminal 1: mars-dev container (already running)
DOCKER_HOST= docker exec mars-dev id mars
# Expected: groups includes joe-docs

# Terminal 2: Start a second instance (hypothetical mars-rt)
# This would use the same joe-docs group files
# Both containers can access credentials via joe-docs group permissions
```

---

## Troubleshooting

### Problem: "Permission denied" when mars user accesses credentials

**Check 1:** Verify joe-docs group on host
```bash
getent group joe-docs
# Must show: joe-docs:x:55556:joehays
```

**Check 2:** Verify file permissions on host
```bash
ls -l ~/dev/joe-docs/dev-ops/capra_access_token
# Must show: joehays joe-docs (not joehays dev)
```

**Fix:** Re-run host permissions setup
```bash
external/mars-user-plugin/hooks/host-permissions.sh
```

---

### Problem: joe-docs group not in container

**Check:** Container environment variables
```bash
DOCKER_HOST= docker exec mars-dev printenv HOST_UID
# Must show: 10227
```

**Fix:** Rebuild container with correct environment
```bash
cd mars-dev/dev-environment
DOCKER_HOST= docker compose down
DOCKER_HOST= docker compose build --no-cache --build-arg HOST_UID=$(id -u)
DOCKER_HOST= docker compose up -d
```

---

### Problem: Environment variables not set

**Check 1:** Verify env-setup hook is sourced
```bash
# On host
grep "env-setup" mars-env.config
# Must show: source "$MARS_REPO_ROOT/external/mars-user-plugin/hooks/env-setup.sh"
```

**Check 2:** Verify hook is executable
```bash
ls -la external/mars-user-plugin/hooks/env-setup.sh
# Must show: -rwxr-xr-x
```

**Fix:** Make hook executable
```bash
chmod +x external/mars-user-plugin/hooks/env-setup.sh
```

---

### Problem: "You are not in joe-docs group"

**Cause:** User added to group but shell hasn't refreshed

**Fix Option 1:** Log out and back in (terminal session)

**Fix Option 2:** Activate group in current shell
```bash
newgrp joe-docs
```

**Fix Option 3:** Restart shell
```bash
exec bash -l
```

---

## Quick Reference Commands

### Host Setup
```bash
# One-line setup
cd ~/dev/mars-v2 && external/mars-user-plugin/hooks/host-permissions.sh

# Verify
groups | grep joe-docs && ls -l ~/dev/joe-docs/dev-ops/capra_access_token
```

### Container Rebuild
```bash
# One-line rebuild
cd ~/dev/mars-v2/mars-dev/dev-environment && DOCKER_HOST= docker compose down && DOCKER_HOST= docker compose build --no-cache && DOCKER_HOST= docker compose up -d

# Verify
DOCKER_HOST= docker exec mars-dev id mars | grep joe-docs
```

### Container Test
```bash
# One-line credential access test
DOCKER_HOST= docker exec -u mars mars-dev cat /root/dev/joe-docs/dev-ops/capra_access_token

# One-line environment test
DOCKER_HOST= docker exec -u mars mars-dev bash -c "cd /workspace/mars-v2 && source mars-env.config && echo \$CURL_CA_BUNDLE"
```

---

## Success Criteria

✅ **Host:**
- [ ] joe-docs group exists (GID 55556)
- [ ] User is member of joe-docs group
- [ ] Credential files have joe-docs group ownership
- [ ] Credential files have group-read permissions (640/750/644)

✅ **Container:**
- [ ] mars-dev group exists with GID 45328 (55555 - 10227)
- [ ] joe-docs group exists with GID 45329 (55556 - 10227)
- [ ] mars user is member of both groups
- [ ] mars user can read credential files
- [ ] mars user can execute token script

✅ **Environment:**
- [ ] CURL_CA_BUNDLE set to joe-docs CA path
- [ ] MARS_ASKSAGE_KEY set (token retrieved)
- [ ] MARS_ASKSAGE_CA_BUNDLE set
- [ ] AIDER_CA_BUNDLE set
- [ ] MARS_RAG_CA_BUNDLE set

✅ **Tests:**
- [ ] All 20 plugin permission tests pass
- [ ] No joe-docs hardcoding in core files

---

## Next Steps After Integration

Once integrated and working:

1. **Commit Changes:**
   ```bash
   cd ~/dev/mars-v2
   git add external/mars-user-plugin/hooks/env-setup.sh
   git add external/mars-user-plugin/mars-plugin.yaml
   git add mars-env.config
   git add mars-dev/dev-environment/Dockerfile
   git add mars-dev/dev-environment/docker-compose.yml
   git add mars-dev/tests/test_user_plugin_permissions.py
   git commit -m "feat(permissions): Move joe-docs to plugin-based env system

- Created env-setup hook for credential exports
- Removed hardcoded joe-docs from mars-env.config
- Fixed Sysbox GID calculation in Dockerfile
- Added 20 regression tests for generic plugin system
- Supports multi-instance containers with different credential groups"
   ```

2. **Update Documentation:**
   - Add plugin env-setup pattern to DEVELOPMENT_WORKFLOW.md
   - Update ADR-0031 with env-setup hook architecture
   - Document multi-instance credential sharing pattern

3. **Test with LiteLLM/AskSage:**
   - Verify CAPRA API calls work with new CA bundle exports
   - Test Aider with new configuration
   - Verify RAG system uses correct CA bundle

---

**Last Updated:** 2025-11-10
**Tested With:** mars-dev container, joe-docs credentials, HOST_UID=10227
