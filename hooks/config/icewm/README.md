# IceWM Configuration for mars-user-plugin

IceWM configuration is managed through **bind-mounted files only**. No fallbacks.

## Architecture

**All configuration** lives in `mounted-files/root/.icewm/` (bind-mounted into container):

| File | Purpose | Required? |
|------|---------|-----------|
| `toolbar` | Taskbar application launchers | **Yes** |
| `preferences` | IceWM behavior settings | **Yes** |
| `startup` | Commands to run on IceWM start | No |
| `winoptions` | Per-application window behavior | No |
| `keys` | Keyboard shortcuts | No |

**This directory** (`hooks/config/icewm/`) contains only:
- `configure-icewm.sh` - Validates bind-mounts and sets permissions
- `backgrounds/` - Desktop background images (copied to container)
- `preferences.example` - Example preferences for reference

## Fail-Fast Behavior

If required files (`preferences`, `toolbar`) are missing, `configure-icewm.sh` **fails with an error** and stops container startup. No silent fallbacks.

Error output:
```
[icewm-config] ✗ ERROR: MISSING REQUIRED IceWM CONFIG FILES
[icewm-config] ✗ ERROR: The following bind-mounted files are missing from /root/.icewm/:
[icewm-config] ✗ ERROR:   - preferences
[icewm-config] ✗ ERROR:   - toolbar
```

## Quick Start

**Edit IceWM toolbar:**
```bash
vim mounted-files/root/.icewm/toolbar
mars up -d
```

**Edit IceWM preferences:**
```bash
vim mounted-files/root/.icewm/preferences
mars up -d
```

## Custom Desktop Background

Place background images in `hooks/config/icewm/backgrounds/`:

```bash
# Single background
cp ~/Pictures/wallpaper.png hooks/config/icewm/backgrounds/custom.png

# Per-workspace backgrounds
cp workspace1.png hooks/config/icewm/backgrounds/workspace1.png
```

Backgrounds are the only files that come from this directory (binary files shouldn't be in mounted-files/).

## Toolbar Format

```bash
# Format: prog "Label" /path/to/icon command
prog "GitLab" /usr/share/pixmaps/gitlab.png firefox http://mars-gitlab-ce
prog "PlantUML" /usr/share/pixmaps/plantuml.png firefox http://localhost:8091/plantuml/
prog "Neo4j" /usr/share/pixmaps/neo4j.png firefox http://localhost:7474
```

## Related Documentation

- **IceWM Official Docs**: https://ice-wm.org/
- **IceWM Preferences**: https://ice-wm.org/man/icewm-preferences
