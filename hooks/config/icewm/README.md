# IceWM Configuration for mars-user-plugin

This directory contains **fallback configuration** for the IceWM window manager.

## Architecture

**Primary configuration** lives in `mounted-files/root/.icewm/` (bind-mounted into container):
- `toolbar` - Taskbar application launchers
- `preferences` - IceWM behavior settings
- `winoptions` - Per-application window behavior
- `startup` - Commands to run when IceWM starts
- `keys` - Keyboard shortcuts

**This directory** (`hooks/config/icewm/`) contains:
- `configure-icewm.sh` - Configuration script (runs on container startup)
- `backgrounds/` - Desktop background images (fallback)
- `startup` - Fallback startup script (used only if bind-mount missing)
- `preferences.example` - Example preferences file for reference

## How It Works

1. Container starts with bind mounts from `mounted-files/root/.icewm/` → `/root/.icewm/`
2. `configure-icewm.sh` runs and checks each config file:
   - If file exists in `/root/.icewm/` (bind-mounted) → **preserve it**
   - If file is missing → copy from `hooks/config/icewm/` as fallback
3. User customizations in `mounted-files/` persist across container restarts

## Quick Start

**Edit IceWM toolbar (add/remove application launchers):**
```bash
# Edit the bind-mounted file directly
vim mounted-files/root/.icewm/toolbar

# Restart container to apply
mars up -d
```

**Edit IceWM preferences:**
```bash
vim mounted-files/root/.icewm/preferences
mars up -d
```

**Changes take effect immediately** - no rebuild required, just restart the container.

## File Locations

| Purpose | Authoritative Source | Fallback |
|---------|---------------------|----------|
| Toolbar | `mounted-files/root/.icewm/toolbar` | `hooks/config/icewm/toolbar` (deleted) |
| Preferences | `mounted-files/root/.icewm/preferences` | MARS defaults |
| Window Options | `mounted-files/root/.icewm/winoptions` | None |
| Startup Script | `mounted-files/root/.icewm/startup` | `hooks/config/icewm/startup` |
| Keybindings | `mounted-files/root/.icewm/keys` | None |
| Backgrounds | N/A | `hooks/config/icewm/backgrounds/` |

## Custom Desktop Background

Place background images in `hooks/config/icewm/backgrounds/`:

**Single background:**
```bash
cp ~/Pictures/wallpaper.png hooks/config/icewm/backgrounds/custom.png
```

**Per-workspace backgrounds:**
```bash
cp workspace1.png hooks/config/icewm/backgrounds/workspace1.png
cp workspace2.png hooks/config/icewm/backgrounds/workspace2.png
# etc.
```

Supported formats: PNG, JPG, JPEG, SVG

## Toolbar Format

The toolbar file uses this format:
```
prog "Label" /path/to/icon command
```

Example:
```bash
# Web browser
prog "Firefox" /usr/share/pixmaps/firefox.png firefox

# Web service (opens in browser)
prog "GitLab" /usr/share/pixmaps/gitlab.png firefox http://mars-gitlab-ce

# Application
prog "Zotero" /usr/share/pixmaps/zotero.png zotero
```

## Preferences Reference

Common preferences (see `preferences.example` for full list):

```bash
# Taskbar
TaskBarAtTop=1              # 1=top, 0=bottom
TaskBarAutoHide=0           # 1=auto-hide

# Focus behavior
FocusMode=2                 # 0=click, 1=sloppy, 2=explicit
RaiseOnFocus=1              # Raise window when focused

# Workspaces
WorkspaceNames=" Dev "," Test "," Docs "," Misc "
```

Full documentation: https://ice-wm.org/man/icewm-preferences

## Troubleshooting

**Toolbar entries not showing:**
```bash
# Check file syntax
cat /root/.icewm/toolbar

# Restart IceWM
icewm --restart
```

**Changes not persisting:**
- Ensure you're editing `mounted-files/root/.icewm/*` (not `hooks/config/icewm/*`)
- The hooks/config files are fallbacks, not the primary source

**Find window class for winoptions:**
```bash
xprop WM_CLASS
# Then click on the window
```

## Related Documentation

- **IceWM Official Docs:** https://ice-wm.org/
- **IceWM Preferences:** https://ice-wm.org/man/icewm-preferences
- **Plugin auto-mount system:** See main plugin README.md
