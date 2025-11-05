# Custom Volume Mounting Guide

The plugin supports mounting **user-specified volumes** into the E6 container through Docker Compose override files.

## How It Works

1. **Plugin contains template**: `templates/docker-compose.override.yml.template`
2. **Pre-up hook**: Copies template to `mars-dev/dev-environment/docker-compose.override.yml`
3. **Docker Compose**: Automatically merges override file with main `docker-compose.yml`
4. **Result**: Your custom volumes are mounted when container starts

## Quick Setup

### 1. Enable Volume Mounting (Default: ON)

The `pre-up` hook is already enabled in the plugin manifest. Volume mounting is active by default.

To disable:
```bash
vim ~/dev/dotfiles/mars-plugin/hooks/pre-up.sh
# Set: ENABLE_CUSTOM_VOLUMES=false
```

### 2. Customize Volume Mounts

After first `mars-dev up`, edit the generated override file:

```bash
vim ~/dev/mars-v2/mars-dev/dev-environment/docker-compose.override.yml
```

Uncomment and customize mounts:

```yaml
services:
  mars-dev:
    volumes:
      # Add your custom mounts here
      - ~/dev/my-project:/workspace/my-project:rw
      - ~/Documents/docs:/workspace/docs:ro
      - ~/.ssh:/root/.ssh:ro
```

### 3. Restart Container

```bash
mars-dev down
mars-dev up -d
```

Your custom volumes will be mounted.

## Common Use Cases

### Mount Additional Projects

```yaml
volumes:
  # Other development projects
  - ~/dev/my-web-app:/workspace/my-web-app:rw
  - ~/dev/data-pipeline:/workspace/data-pipeline:rw
```

### Mount Reference Materials

```yaml
volumes:
  # Documentation (read-only)
  - ~/Documents/technical-docs:/workspace/docs:ro
  - ~/Books/programming:/workspace/books:ro
```

### Mount SSH/GPG Keys

```yaml
volumes:
  # SSH keys (read-only for security)
  - ~/.ssh:/root/.ssh:ro

  # GPG keys (read-only)
  - ~/.gnupg:/root/.gnupg:ro
```

### Mount Persistent Caches

```yaml
volumes:
  # Pip cache (speeds up Python installs)
  - ~/.cache/pip:/root/.cache/pip:rw

  # npm cache
  - ~/.npm:/root/.npm:rw

  # Docker build cache
  - ~/.docker:/root/.docker:rw
```

### Mount Shared Datasets

```yaml
volumes:
  # ML models and datasets (read-only)
  - ~/ml-models:/workspace/ml-models:ro
  - ~/datasets:/workspace/datasets:ro
```

## Mount Permissions

**Read-Write (`:rw`)**:
- Files can be modified inside container
- Changes persist on host
- Use for: Active development directories

**Read-Only (`:ro`)**:
- Files cannot be modified inside container
- Protects host files from accidental changes
- Use for: Reference materials, SSH keys, shared resources

## File Ownership (Sysbox UID Mapping)

Files created inside the container will have correct ownership on the host thanks to Sysbox UID mapping:

```bash
# Inside container (as root UID 0)
touch /workspace/my-project/newfile.txt

# On host - owned by you!
ls -l ~/dev/my-project/newfile.txt
# -rw-r--r-- 1 joehays joehays 0 newfile.txt
```

This works because of the Sysbox configuration in `docker-compose.yml`:

```yaml
labels:
  - "io.sysbox.subid.uid=10227"  # Maps to your host UID
  - "io.sysbox.subid.gid=101"    # Maps to your host GID
```

## Workflow

### Initial Setup

```bash
# 1. Register plugin (includes pre-up hook)
cd ~/dev/mars-v2
mars-dev register-plugin ~/dev/dotfiles/mars-plugin

# 2. Start container (pre-up hook creates override file)
mars-dev up -d

# 3. Check override file was created
ls -la mars-dev/dev-environment/docker-compose.override.yml
```

### Customize Mounts

```bash
# 4. Edit override file
vim mars-dev/dev-environment/docker-compose.override.yml

# 5. Add your custom volumes (uncomment examples or add new ones)

# 6. Restart container to apply changes
mars-dev down
mars-dev up -d

# 7. Verify mounts inside container
mars-dev attach
ls /workspace  # Should show your custom mounts
```

### Update Mounts Later

```bash
# Edit override file
vim ~/dev/mars-v2/mars-dev/dev-environment/docker-compose.override.yml

# Add/remove/modify mounts

# Restart to apply
mars-dev down && mars-dev up -d
```

## Template Management

### Update Template

If you want to change the default template for future containers:

```bash
# Edit template in your plugin
vim ~/dev/dotfiles/mars-plugin/templates/docker-compose.override.yml.template

# Commit to dotfiles
cd ~/dev/dotfiles
git add mars-plugin/templates/
git commit -m "Update volume mount template"
git push
```

### Force Template Refresh

If you've updated the template and want to regenerate the override file:

```bash
# Delete existing override
rm ~/dev/mars-v2/mars-dev/dev-environment/docker-compose.override.yml

# Restart (pre-up hook will regenerate)
mars-dev up -d
```

**Note**: This will overwrite your custom mounts! Back up first if needed.

## Git Ignore Configuration

The `docker-compose.override.yml` file is **user-specific** and should be git-ignored.

**Add to MARS repo `.gitignore`**:

```bash
echo "mars-dev/dev-environment/docker-compose.override.yml" >> ~/dev/mars-v2/.gitignore
```

This prevents accidentally committing your personal volume configuration to the MARS repository.

## Troubleshooting

### Override File Not Created

Check pre-up hook executed:
```bash
mars-dev list-plugins
# Verify joehays-work-customizations is enabled

# Try manually running the hook
cd ~/dev/mars-v2/mars-dev/dev-environment
export MARS_PLUGIN_ROOT=~/dev/dotfiles/mars-plugin
export MARS_REPO_ROOT=~/dev/mars-v2
bash ~/dev/dotfiles/mars-plugin/hooks/pre-up.sh
```

### Volumes Not Mounting

Verify override file syntax:
```bash
# Check YAML is valid
cat ~/dev/mars-v2/mars-dev/dev-environment/docker-compose.override.yml

# Test compose merge (dry-run)
cd ~/dev/mars-v2/mars-dev/dev-environment
docker compose config
```

### Permission Denied on Mounted Volume

Check host directory exists and has correct permissions:
```bash
# On host
ls -la ~/dev/my-project
# Should be owned by you (joehays)

# If not, fix ownership
sudo chown -R joehays:joehays ~/dev/my-project
```

### Files Owned by Root on Host

This indicates Sysbox UID mapping is not working. See E6 README section on "Configure UID/GID Mapping".

### Changes Not Applied After Edit

Restart container (down + up):
```bash
mars-dev down
mars-dev up -d
```

Simply restarting (restart command) may not reload volume configuration.

## Advanced: Multiple Override Files

Docker Compose supports multiple override files:

```bash
# In mars-dev script, you could add:
docker compose -f docker-compose.yml \
               -f docker-compose.override.yml \
               -f docker-compose.local.yml \
               up -d
```

However, the standard single override approach is simpler and sufficient for most use cases.

## Security Considerations

### Read-Only Mounts

Always use `:ro` for sensitive files:
```yaml
volumes:
  - ~/.ssh:/root/.ssh:ro      # ✅ Read-only
  - ~/.gnupg:/root/.gnupg:ro  # ✅ Read-only
```

**Why**: Prevents malicious code in container from modifying your SSH/GPG keys.

### Avoid Mounting Entire Home Directory

```yaml
volumes:
  - ~:/root:rw  # ❌ DON'T DO THIS
```

**Why**: Container compromise would expose all your files. Mount only what's needed.

### Use Specific Paths

```yaml
volumes:
  - ~/dev/specific-project:/workspace/project:rw  # ✅ Specific
  - ~/dev:/workspace:rw                           # ❌ Too broad
```

## See Also

- **E6 README**: `~/dev/mars-v2/mars-dev/dev-environment/README.md`
- **Plugin Schema**: `~/dev/mars-v2/mars-dev/docs/PLUGIN_SCHEMA.md`
- **Docker Compose Docs**: https://docs.docker.com/compose/extends/
