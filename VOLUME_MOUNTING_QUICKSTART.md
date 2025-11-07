# Volume Mounting Quick Start

Mount additional directories into your E6 container in 3 steps.

## Step 1: Register Plugin (If Not Already Done)

```bash
cd ~/dev/mars-v2
source mars-env.config
mars-dev register-plugin ~/dev/dotfiles/mars-plugin
```

The plugin's `pre-up` hook will automatically set up volume mounting.

## Step 2: Start Container

```bash
mars-dev up -d
```

The `pre-up` hook executes and creates:
- `~/dev/mars-v2/mars-dev/dev-environment/docker-compose.override.yml`

You'll see:
```
[joehays-plugin:pre-up] Copying volume override configuration...
[joehays-plugin:pre-up] ✅ Custom volume configuration ready
```

## Step 3: Customize Your Mounts

```bash
vim ~/dev/mars-v2/mars-dev/dev-environment/docker-compose.override.yml
```

Uncomment and customize:

```yaml
services:
  mars-dev:
    volumes:
      # Add your mounts here
      - ~/dev/my-project:/workspace/my-project:rw
      - ~/Documents/docs:/workspace/docs:ro
      - ~/.ssh:/root/.ssh:ro
```

## Step 4: Restart to Apply

```bash
mars-dev down
mars-dev up -d
```

## Step 5: Verify

```bash
mars-dev attach
ls /workspace  # Should show your new mounts
```

## Common Mounts

### Additional Projects
```yaml
- ~/dev/my-web-app:/workspace/my-web-app:rw
```

### SSH Keys (Read-Only)
```yaml
- ~/.ssh:/root/.ssh:ro
```

### Documentation (Read-Only)
```yaml
- ~/Documents/technical-docs:/workspace/docs:ro
```

### Persistent Caches
```yaml
- ~/.cache/pip:/root/.cache/pip:rw
```

## Permissions

- `:rw` - Read-write (can modify files)
- `:ro` - Read-only (cannot modify files)

**Use `:ro` for sensitive files like SSH keys!**

## Troubleshooting

### Override File Not Created

Manually run the hook:
```bash
cd ~/dev/mars-v2/mars-dev/dev-environment
export MARS_PLUGIN_ROOT=~/dev/dotfiles/mars-plugin
export MARS_REPO_ROOT=~/dev/mars-v2
bash ~/dev/dotfiles/mars-plugin/hooks/pre-up.sh
```

### Mounts Not Appearing

Check override file syntax:
```bash
docker compose -f ~/dev/mars-v2/mars-dev/dev-environment/docker-compose.yml \
               -f ~/dev/mars-v2/mars-dev/dev-environment/docker-compose.override.yml \
               config | grep -A 20 volumes
```

## Git Ignore

Add to MARS repo `.gitignore`:
```bash
echo "mars-dev/dev-environment/docker-compose.override.yml" >> ~/dev/mars-v2/.gitignore
```

## Full Documentation

See [VOLUME_MOUNTING.md](VOLUME_MOUNTING.md) for complete guide with examples, security considerations, and advanced usage.
