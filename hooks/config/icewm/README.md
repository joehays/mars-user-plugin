# IceWM Configuration for mars-user-plugin

IceWM configuration is managed through **bind-mounted files only**.

## Architecture (SIMPLIFIED)

**ALL configuration** lives in `mounted-files/root/.icewm/` (bind-mounted into container):

| File/Dir | Purpose | Required? |
|----------|---------|-----------|
| `toolbar` | Taskbar application launchers | **Yes** |
| `preferences` | IceWM behavior settings | **Yes** |
| `backgrounds/` | Desktop background images | No |
| `startup` | Commands to run on IceWM start | No |
| `winoptions` | Per-application window behavior | No |
| `keys` | Keyboard shortcuts | No |

**This directory** (`hooks/config/icewm/`) contains only:
- `configure-icewm.sh` - Sets permissions and creates prefoverride
- `preferences.example` - Example preferences for reference

## Quick Start

**Edit IceWM toolbar:**
```bash
vim mounted-files/root/.icewm/toolbar
# Restart IceWM or container
```

**Edit IceWM preferences:**
```bash
vim mounted-files/root/.icewm/preferences
# Restart IceWM or container
```

## Custom Desktop Background

Place background images in `mounted-files/root/.icewm/backgrounds/`:

```bash
# Single background
cp ~/Pictures/wallpaper.png mounted-files/root/.icewm/backgrounds/custom.png

# Per-workspace backgrounds (workspace1.png through workspace8.png)
cp workspace1.png mounted-files/root/.icewm/backgrounds/workspace1.png
```

## Toolbar Format

```bash
# Format: prog "Label" /path/to/icon command
prog "GitLab" /usr/share/pixmaps/gitlab.png firefox http://mars-gitlab-ce
prog "PlantUML" /usr/share/pixmaps/plantuml.png firefox http://localhost:8091/plantuml/
prog "graph-db" /usr/share/pixmaps/neo4j.png firefox http://localhost:7474
```

## Related Documentation

- **IceWM Official Docs**: https://ice-wm.org/
- **IceWM Preferences**: https://ice-wm.org/man/icewm-preferences
