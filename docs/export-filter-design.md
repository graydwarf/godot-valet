# Export Settings - Design Document

## Priority Tasks (Build Page UI Improvements)

### High Priority - Build Page Controls
- [ ] Add **Refresh button** to the left of "Export Selected" - refreshes export packages list
- [ ] Add **Save button** to right of "Export Selected" - saves changes
- [ ] Add **Include/Exclude row** below Obfuscation:
  - Text input showing summary: "Including 2 folders, 3 files | Excluding 6 files, 1 folder"
  - Cog button (⚙) at right to open Include/Exclude settings dialog
  - **Source platform**: Opens dialog with tree view + excludes + includes
  - **Other platforms**: Opens dialog with includes only + instructions for Godot export settings
- [ ] Add export options row below Include/Exclude (same line, left-aligned with padding):
  - **Export Type DDL**: Release | Debug
  - **Package Type DDL**: Zip | No Zip
  - **Generate Checksum**: [ ] checkbox
- [ ] Implement export workflow respecting these options:
  1. Export (release/debug)
  2. Obfuscate (if enabled)
  3. Copy additional files (includes)
  4. Zip (if enabled)
  5. Generate checksum (if enabled)

### Checksum Strategy (needs decision)
**Options:**
1. **Checksum the .zip** (if zipping enabled) - Single file, easy to verify
2. **Checksum the primary binary** (if no zip) - .exe, .x86_64, .html, etc.
3. **Checksum all files** → generate checksums.txt with one hash per file

**Recommendation**:
- If Zip enabled: Checksum the .zip file → `MyGame-Windows-v1.0.zip.sha256`
- If No Zip: Checksum the primary binary → `MyGame.exe.sha256`
- Add help tooltip/dialog explaining what gets checksummed

**Checksum file format:**
```
SHA256 (MyGame-Windows-v1.0.zip) = abc123def456...
```
This format is compatible with `sha256sum -c` verification.

### Medium Priority - Godot Editor Integration
- [ ] Add **"Edit Project" button** on build config dialog - launches `godot.exe --editor --path <project>`
  - Allows user to access Godot's export settings (Resources tab → include/exclude filters)
- [ ] Add "Edit export_presets.cfg" button - opens file in default text editor (for advanced users)

---

## Overview

Export settings dialog for configuring:
1. **Source platform**: Tree view with checkboxes to select which project files to include/exclude
2. **All platforms**: "Additional Files" section to copy external content into the export folder

**Note**: Binary platform exports (Windows, Linux, macOS, Web) use Godot's built-in export system which handles exclusions automatically. Tree view exclusions are **Source platform only**.

## Problem Statement

For Source exports (full project backup/sharing), users need to:
- Exclude development files (.git, .godot, .vscode, etc.)
- Exclude test folders and documentation
- Exclude raw assets (psd, blender files)
- Exclude sensitive files (.env)
- Include additional external files (documentation, assets from other locations)

For all exports, users need:
- Ability to add additional files to exports (README, licenses, docs)
- Export type control (Release/Debug)
- Packaging options (Zip/No Zip)
- Checksum generation for verification

## Core Features

### 1. Project Tree with Checkboxes (Exclusions)
- Shows full project structure as a tree with checkboxes
- Users can check/uncheck folders and files
- Unchecked items get excluded from Source export
- Inherits selection state (uncheck parent = uncheck all children)
- Shows file sizes to help users identify bloat
- Borrow implementation from existing file-tree-view (`%FileTree` Tree control)
- Tree visually updates when exclude patterns are added/removed

### 2. Exclude Patterns
- Glob patterns like `*.md`, `*.psd`, `raw_assets/`
- Add/remove buttons for each pattern
- Shows file count of excluded files
- When pattern added, tree updates to uncheck matching items

### 3. Additional Files (Includes)
- Copy external content INTO the export folder
- Each entry needs:
  - **Source path**: File or folder to copy (external to project)
  - **Target path**: Where to place it in export (relative to export root)
- Add/remove buttons for each entry
- Use cases:
  - Add license files from a shared location
  - Include documentation from another repo
  - Add build artifacts from external tools

### 4. Source Platform Only
- This dialog only applies to Source platform exports
- Binary platforms use Godot's built-in export exclusion system

## UI Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Source Export Settings                                      │
├─────────────────────────────────────────────────────────────┤
│ ▼ Project Tree (check items to include)                     │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ ☑ MyGame/                                               │ │
│ │   ☑ scenes/                                             │ │
│ │   ☑ scripts/                                            │ │
│ │   ☐ .git/                                               │ │
│ │   ☐ .godot/                                             │ │
│ │   ☑ assets/                                             │ │
│ │   ☐ exports/                                            │ │
│ └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│ ▼ Exclude Patterns (147 files excluded)                     │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ .git/                                           [Remove]│ │
│ │ .godot/                                         [Remove]│ │
│ │ *.psd                                           [Remove]│ │
│ └─────────────────────────────────────────────────────────┘ │
│ [+ Add Pattern]                                             │
├─────────────────────────────────────────────────────────────┤
│ ▼ Additional Files (copy into export)                       │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Source: C:/shared/LICENSE.txt                           │ │
│ │ Target: LICENSE.txt                        [Browse] [X] │ │
│ │─────────────────────────────────────────────────────────│ │
│ │ Source: C:/docs/user-manual/                            │ │
│ │ Target: docs/                              [Browse] [X] │ │
│ └─────────────────────────────────────────────────────────┘ │
│ [+ Add File/Folder]                                         │
├─────────────────────────────────────────────────────────────┤
│                                       [Cancel]    [Save]    │
└─────────────────────────────────────────────────────────────┘
```

## Data Structure

Stored in build config for Source platform:

```gdscript
{
    "excluded_paths": ["exports", ".git", ".godot"],  # From tree unchecks
    "exclude_patterns": [".git/", ".godot/", "*.psd"],  # Glob patterns
    "additional_files": [
        {
            "source": "C:/shared/LICENSE.txt",
            "target": "LICENSE.txt"
        },
        {
            "source": "C:/docs/user-manual/",
            "target": "docs/"
        }
    ]
}
```

## Default Exclude Patterns

For Source platform:
- `.git/`
- `.godot/`
- `.import/`
- `exports/` or `builds/`
- `.vscode/`, `.vs/`, `.idea/`

## Tree Behavior

### Visual Updates from Patterns
- Tree starts with everything checked
- When user adds `.git/` to exclude patterns → tree unchecks `.git/` folder
- When user adds `*.md` to exclude patterns → tree unchecks all `.md` files
- User can also manually uncheck items in tree → adds to `excluded_paths`

### Data Separation
- `excluded_paths`: Only manually unchecked items from tree (not pattern-matched ones)
- `exclude_patterns`: Glob patterns

This way the tree shows the combined result visually, but we store the rules separately. When loading, we rebuild the tree visual by applying patterns to check/uncheck items.

**Benefit**: If user adds `*.md` pattern and later removes it, all the .md files automatically become checked again (since they weren't individually stored in `excluded_paths`).

## Export Process

During Source export, apply in order:
1. Start with all project files
2. Remove anything in `excluded_paths` (from tree unchecks)
3. Remove anything matching `exclude_patterns`
4. Copy remaining files to export folder
5. Copy each `additional_files` entry from source to target location

## Access Point

- Cog button (⚙) next to Export button on Source platform card only
- Opens full-screen dialog

## Files to Create/Modify

### New Files
- `scenes/release-manager/source-export-settings-dialog.tscn`
- `scenes/release-manager/source-export-settings-dialog.gd`

### Modified Files
- `scenes/release-manager/pages/page3-build.gd` - Add cog button for Source, launch dialog
- `scenes/release-manager/pages/page3-build.tscn` - Add cog button UI (Source only)
- `scenes/release-manager/build-config-dialog.gd` - Add new fields to config
- Source export functions to apply filters and copy additional files

## Implementation Todos

- [ ] Create source-export-settings-dialog.tscn with full-screen layout
- [ ] Create source-export-settings-dialog.gd with tree and pattern management
- [ ] Implement project tree with checkboxes (borrow from file-tree-view)
- [ ] Add exclude pattern section with add/remove
- [ ] Add additional files section with source/target paths and browse buttons
- [ ] Save/load filter settings in Source platform build config
- [ ] Add cog button next to Export button on Source platform card only
- [ ] Apply exclude filters during Source export copy
- [ ] Copy additional files to target locations after main export
- [ ] Add unit tests for:
  - [ ] Pattern matching (glob patterns)
  - [ ] Tree checkbox state management
  - [ ] Filter application during export
  - [ ] Additional files copy with target paths
  - [ ] Save/load persistence

## Testing Requirements

Unit tests should cover:
1. Glob pattern matching
2. Tree checkbox inheritance (parent/child)
3. Pattern-to-tree visual sync
4. Filter application order
5. Additional files copy to correct targets
6. Default excludes applied on first load

## Questions Resolved

1. **Per-platform or global?** - Source platform only
2. **Include patterns purpose?** - Changed to "Additional Files" - copy external content into export
3. **Tree saves selections?** - Yes, persist across sessions
4. **UI format?** - Full-screen dialog for visibility

## Future Enhancements

- File size display in tree
- Preview of final export (file count, total size)
- Presets: "Default", "Minimal", "Clean"
- Search/filter within tree
- Bulk operations (check/uncheck all matching pattern)
- Drag and drop for additional files
