# Quick Start Guide

Get your work environment dependencies into MARS E6 container in 3 steps.

## Step 1: Register Plugin

```bash
cd ~/dev/mars-v2
mars-dev register-plugin ~/dev/dotfiles/mars-plugin
```

Expected output:
```
[mars-plugin] Registering plugin: joehays-work-customizations
[mars-plugin] ✓ Plugin registered successfully
```

## Step 2: Verify Registration

```bash
mars-dev list-plugins
```

Expected output:
```
Registered MARS Plugins:
  - joehays-work-customizations
    Path: /home/joehays/dev/dotfiles/mars-plugin
    Enabled: true
    Registered: 2025-11-05T...
```

## Step 3: Rebuild Container

```bash
# Full rebuild with plugin hooks
mars-dev build --no-cache

# This will take 5-10 minutes (or 30-60 if TexLive enabled)
```

During build, you'll see:
```
=== Executing user-setup hooks from registered plugins ===
[joehays-plugin] Starting joehays-work-customizations setup...
[joehays-plugin] ✅ passwordsafe installed
[joehays-plugin] ✅ Personal tools installation complete
...
[joehays-plugin] ✅ joehays-work-customizations setup complete!
```

## Step 4: Start and Verify

```bash
# Start container
mars-dev up -d

# Attach to shell
mars-dev attach

# Verify installations
passwordsafe --version  # Should show version info
```

## Customization (After Initial Setup)

### Disable Components You Don't Need

Edit the configuration section:

```bash
vim ~/dev/dotfiles/mars-plugin/hooks/user-setup.sh
```

Change any flags from `true` to `false`:

```bash
# Top of file (lines 20-23)
INSTALL_PERSONAL_TOOLS=true      # Keep this if you want passwordsafe
INSTALL_DESKTOP=false            # Set true if you need GUI/RDP
INSTALL_PYTHON_LIBS=false        # Keep false (already in E6)
INSTALL_TEXLIVE=false            # Set true if you need LaTeX
```

### Comment Out Individual Packages

Find the package in the script and comment it out:

```bash
install_personal_tools() {
    log_info "Installing personal tools..."
    apt-get update

    # Password manager
    # apt-get install -y passwordsafe  # ← Comment out if not needed

    # Add your own packages here
    # apt-get install -y my-tool
}
```

### Rebuild After Changes

```bash
mars-dev build --no-cache
```

## Troubleshooting

### "Plugin not found"

Check path is correct:
```bash
ls -la ~/dev/dotfiles/mars-plugin/mars-plugin.yaml
```

### "Hook not executable"

Make it executable:
```bash
chmod +x ~/dev/dotfiles/mars-plugin/hooks/user-setup.sh
```

### "Package not available"

Some packages may not be in Ubuntu 22.04:
- Check with: `docker run --rm ubuntu:22.04 apt-cache show <package-name>`
- Comment out unavailable packages in the script

## Next Steps

1. ✅ Plugin is working with default config (passwordsafe only)
2. ⏭️ Review what you need and disable unnecessary components
3. ⏭️ Add your own custom packages to `install_personal_tools()`
4. ⏭️ Rebuild and test
5. ⏭️ Commit changes to your dotfiles repo

## Help

For detailed documentation, see:
- **README.md** - Full plugin documentation
- **hooks/user-setup.sh** - The actual installation script
- **mars-plugin.yaml** - Plugin manifest
