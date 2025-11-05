# Joe Hays' MARS Work Environment Plugin

This MARS user plugin installs work-related dependencies into the E6 containerized development environment.

## Overview

Replaces the functionality of `~/dev/dotfiles/scripts/install.work` with a MARS plugin-compliant implementation.

## Features

### 1. Dependency Installation (Build-Time)
Installs packages and tools during E6 container build via `user-setup` hook.

### 2. Custom Volume Mounting (Run-Time)
Mounts user-specified directories into the container via `pre-up` hook.

**See**: [VOLUME_MOUNTING.md](VOLUME_MOUNTING.md) for complete volume mounting guide.

## Installation Categories

### 1. Personal Tools (Default: ENABLED)
- **passwordsafe** - Password manager

### 2. Desktop Environment (Default: DISABLED)
- **xrdp** - Remote Desktop Protocol server
- **ubuntu-gnome-desktop** - Full GNOME desktop environment
- **Size**: ~2-3GB
- **Install time**: 10-15 minutes

### 3. Python Development Libraries (Default: DISABLED)
- Already included in E6 Dockerfile
- Includes: tk-dev, libffi-dev, libssl-dev, zlib1g-dev, etc.

### 4. TexLive (Default: DISABLED)
- Full TexLive distribution (scheme-full)
- **Size**: ~7GB
- **Install time**: 30-60 minutes
- Includes additional packages: newtx, xpatch, xstring, microtype, latexmk, etc.

## Setup Instructions

### 1. Register Plugin with MARS

```bash
cd ~/dev/mars-v2
mars-dev register-plugin ~/dev/dotfiles/mars-plugin
```

### 2. Verify Registration

```bash
mars-dev list-plugins
```

Expected output:
```
Registered MARS Plugins:
  - joehays-work-customizations
    Path: ~/dev/dotfiles/mars-plugin
    Enabled: true
```

### 3. Customize Installation (Optional)

Edit `hooks/user-setup.sh` to enable/disable categories:

```bash
vim ~/dev/dotfiles/mars-plugin/hooks/user-setup.sh

# Change configuration flags:
INSTALL_PERSONAL_TOOLS=true      # Default: true
INSTALL_DESKTOP=false            # Default: false (headless container)
INSTALL_PYTHON_LIBS=false        # Default: false (already in E6)
INSTALL_TEXLIVE=false            # Default: false (very large)
```

### 4. Rebuild E6 Container

```bash
cd ~/dev/mars-v2
mars-dev build --no-cache
```

The plugin's `user-setup` hook will execute during the Docker build.

### 5. Start and Verify

```bash
mars-dev up -d
mars-dev attach

# Verify installations
passwordsafe --version              # Personal tools
which xrdp                          # Desktop (if enabled)
latex --version                     # TexLive (if enabled)
```

## Customization

### Add New Packages

Edit `hooks/user-setup.sh` and add to the `install_personal_tools()` function:

```bash
install_personal_tools() {
    log_info "Installing personal tools..."
    apt-get update

    apt-get install -y passwordsafe
    apt-get install -y your-new-package  # Add here

    log_success "Personal tools installation complete"
}
```

### Enable Desktop Environment

Set `INSTALL_DESKTOP=true` in `hooks/user-setup.sh`:

```bash
INSTALL_DESKTOP=true  # Change from false to true
```

**Use case**: If you need GUI applications or remote desktop access to the container.

### Enable TexLive

Set `INSTALL_TEXLIVE=true` in `hooks/user-setup.sh`:

```bash
INSTALL_TEXLIVE=true  # Change from false to true
```

**Use case**: If you need LaTeX document compilation in the container.

**Warning**: This adds ~7GB to the container image and takes 30-60 minutes to install.

## Troubleshooting

### Plugin Not Executing

```bash
# Check plugin is registered
mars-dev list-plugins

# Validate plugin manifest
mars-dev validate-plugin ~/dev/dotfiles/mars-plugin

# Check hook is executable
ls -la ~/dev/dotfiles/mars-plugin/hooks/user-setup.sh
```

### Build Fails During Plugin Hook

Check build logs for error messages:

```bash
mars-dev build --no-cache 2>&1 | grep -A 10 "joehays-plugin"
```

### Package Not Available

Some packages may not be available in Ubuntu 22.04 repositories:
- **passwordsafe**: Check if available with `apt-cache show passwordsafe`
- **python-openssl**: Deprecated, use `python3-openssl` instead

### Disable Failed Category

Edit `hooks/user-setup.sh` and set problematic category to `false`:

```bash
INSTALL_PERSONAL_TOOLS=false  # Disable this category
```

Then rebuild.

## Uninstallation

### Disable Plugin (Keep Registered)

```bash
mars-dev disable-plugin joehays-work-customizations
mars-dev build --no-cache
```

### Unregister Plugin (Complete Removal)

```bash
mars-dev unregister-plugin joehays-work-customizations
mars-dev build --no-cache
```

## Maintenance

### Update Plugin

1. Edit `hooks/user-setup.sh` with changes
2. Update version in `mars-plugin.yaml`
3. Rebuild container: `mars-dev build --no-cache`

### Version Control

This plugin lives in your dotfiles repository:

```bash
cd ~/dev/dotfiles/mars-plugin
git add .
git commit -m "Update MARS plugin: add new tool"
git push
```

## Migration from install.work

This plugin replaces the following from your original setup:

| Original | Plugin Equivalent | Status |
|----------|------------------|--------|
| `install.work` (APT packages) | `install_personal_tools()` | ✅ Migrated |
| `programs/texlive.sh` | `install_texlive()` | ✅ Migrated |
| Python dev libraries | E6 Dockerfile | ✅ Already included |
| Conditional installers | Direct apt install | ✅ Simplified |

## See Also

- **MARS Plugin Schema**: `~/dev/mars-v2/mars-dev/docs/PLUGIN_SCHEMA.md`
- **E6 Documentation**: `~/dev/mars-v2/mars-dev/dev-environment/README.md`
- **Original Install Script**: `~/dev/dotfiles/scripts/install.work`
