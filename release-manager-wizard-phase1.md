# Release Manager Wizard - Phase 1: Foundation & Basic Pages

## Overview
Transform the Release Manager from a single-page form into a multi-step wizard. Phase 1 establishes the navigation foundation and implements Pages 1-2.

## Goals
- Create wizard navigation structure with breadcrumb bar
- Implement Page 1: Basic Project Settings
- Implement Page 2: Select Exports
- Add persistent project card header to all pages
- Establish auto-save behavior
- Create page transition system

## Features

### Wizard Navigation Structure
**Breadcrumb Bar**:
```
[1. Settings] → [2. Exports] → [3. Obfuscation] → [4. Build] → [5. Publish]
     ●              ○               ○              ○           ○
```
- Current step highlighted
- Completed steps show filled dot (●), clickable to navigate back
- Future steps show empty dot (○), not clickable
- Located at top of wizard below project card

**Navigation Buttons**:
- Bottom-left: `[Exit]` - Returns to Project Manager
- Bottom-right: `[← Back] [Next →]`
- Page 1: Only Next enabled
- Page 5: Next becomes Finish
- All pages: Exit always visible

### Project Card Header
Appears at top of every page:
```
┌─────────────────────────────────────────────────────┐
│ 📦 Kilanote v1.2.3                     [Saved ✓]   │
│ Path: C:/projects/kilanote                          │
│ Godot: 4.5-stable                                   │
└─────────────────────────────────────────────────────┘
```
- Always visible for context
- Shows project name, version, path, Godot version
- Auto-save indicator (top-right): briefly flashes on setting change

### Page 1: Basic Project Settings

**Purpose**: Configure project identity and output locations

**Layout**:
```
┌─────────────────────────────────────────────────────┐
│ Basic Project Settings                              │
│                                                     │
│ Project Name:    [Kilanote                      ]  │
│ Project Path:    [C:/projects/kilanote          ] [📁]│
│ Project Version: [v1.2.3                        ]  │
│ Godot Version:   4.5-stable (read-only)            │
│                                                     │
│ Export Path:     [C:/exports/kilanote           ] [📁]│
│ Export Filename: [kilanote                      ]  │
│                                                     │
│ Last Published:  2025-01-15 (read-only)            │
│                                                     │
│                                                     │
│                                                     │
│ [Exit]                              [Next →]       │
└─────────────────────────────────────────────────────┘
```

**Fields**:
- Project Name (LineEdit) - editable
- Project Path (LineEdit + Button) - shows current path, button opens folder picker
- Project Version (LineEdit) - editable, format: vX.Y.Z
- Godot Version (Label) - read-only, from config
- Export Path (LineEdit + Button) - where builds go, button opens folder picker
- Export Filename (LineEdit) - base name for all exports
- Last Published (Label) - read-only, formatted date

**Validation**:
- Project Name: not empty
- Project Version: warn if not vX.Y.Z format
- Export Path: warn if doesn't exist
- Export Path: error if same as Project Path
- Next enabled when all required fields valid

**Auto-Save**:
- Every field change saves immediately to project config
- Brief "Saved ✓" indicator flash in project card

### Page 2: Select Exports

**Purpose**: Choose which platforms to build

**Layout**:
```
┌─────────────────────────────────────────────────────┐
│ Select Exports                                      │
│                                                     │
│ Choose which platforms to build:                   │
│                                                     │
│ ☑ Windows Desktop                                  │
│ ☑ Linux                                            │
│ ☑ Web                                              │
│ ☐ macOS (coming soon)                              │
│ ☑ Source Code                                      │
│                                                     │
│ [Source Filters...]  (visible when Source checked) │
│                                                     │
│ Note: Export presets must be configured in Godot   │
│       Missing presets will show errors on export.  │
│                                                     │
│                                                     │
│ [Exit]                       [← Back] [Next →]     │
└─────────────────────────────────────────────────────┘
```

**Fields**:
- CheckBox for each platform (Windows, Linux, Web, macOS, Source)
- Source Filters button (visible only when Source checked)
- Info label about export presets

**Validation**:
- Warn if no platforms selected
- Check if export_presets.cfg exists in project path
- Show warning if missing (but allow Next)

**Source Filters Dialog**:
- Opens existing source-filter-dialog.tscn
- Clarify in dialog that filters affect ALL builds (not just source export)
- Suggest default: tests/, .git/, .import/

**Auto-Save**:
- Checkbox changes save immediately
- Source filters save when dialog closes

## Technical Implementation

### File Structure
```
scenes/release-manager/
├── release-manager.tscn (main wizard container)
├── release-manager.gd (wizard state machine)
├── pages/
│   ├── page-base.gd (base class for all pages)
│   ├── page1-settings.tscn/gd
│   ├── page2-exports.tscn/gd
│   ├── page3-obfuscation.tscn/gd (Phase 2)
│   ├── page4-build.tscn/gd (Phase 3)
│   └── page5-publish.tscn/gd (Phase 4)
└── components/
    ├── wizard-breadcrumb.tscn/gd
    └── project-card.tscn/gd
```

### release-manager.gd Core Logic
```gdscript
extends Panel

var _currentPage: int = 0
var _pages: Array[Control] = []

func _ready():
    _loadPages()
    _showPage(0)

func _loadPages():
    _pages = [
        $Pages/Page1Settings,
        $Pages/Page2Exports,
        $Pages/Page3Obfuscation,
        $Pages/Page4Build,
        $Pages/Page5Publish
    ]

func _showPage(pageIndex: int):
    for i in range(_pages.size()):
        _pages[i].visible = (i == pageIndex)
    _currentPage = pageIndex
    _updateBreadcrumb()
    _updateNavigationButtons()

func _onNextPressed():
    if _currentPage < _pages.size() - 1:
        _showPage(_currentPage + 1)

func _onBackPressed():
    if _currentPage > 0:
        _showPage(_currentPage - 1)

func _onExitPressed():
    # Return to Project Manager
    Signals.emit_signal("CloseReleaseManager")
```

### page-base.gd (Base Class)
```gdscript
extends Control
class_name WizardPageBase

signal page_changed()
signal validation_changed(is_valid: bool)

var _selectedProjectItem = null

func configure(projectItem):
    _selectedProjectItem = projectItem
    _loadPageData()

func _loadPageData():
    # Override in subclasses
    pass

func validate() -> bool:
    # Override in subclasses
    return true

func save():
    # Override in subclasses - auto-save on field change
    pass
```

### Auto-Save System
- Each page extends WizardPageBase
- Field changes call `save()` which writes to project config immediately
- project-card component listens for save events and shows "Saved ✓" indicator

### Breadcrumb Component
```gdscript
extends HBoxContainer
class_name WizardBreadcrumb

signal step_clicked(step_index: int)

var _steps = ["Settings", "Exports", "Obfuscation", "Build", "Publish"]
var _currentStep: int = 0

func update_progress(current: int):
    _currentStep = current
    _updateStepVisuals()

func _updateStepVisuals():
    # Update dots: filled (●) for completed/current, empty (○) for future
    # Enable clicking on completed steps only
```

## Files to Modify
- `scenes/release-manager/release-manager.tscn` - Complete restructure
- `scenes/release-manager/release-manager.gd` - Rewrite as wizard controller
- Create new scenes/scripts as listed in File Structure

## Migration Notes
- Current release-manager.tscn has all fields in one panel
- Need to extract and organize into 5 separate page scenes
- Preserve all existing functionality, just reorganize UI
- Keep all existing ProjectItem getters/setters
- Maintain compatibility with existing project configs

## Acceptance Criteria
- [ ] Breadcrumb bar shows 5 steps with current step highlighted
- [ ] Breadcrumb allows clicking back to completed steps
- [ ] Project card appears at top of all pages
- [ ] Project card shows auto-save indicator
- [ ] Page 1 displays all basic settings fields
- [ ] Page 1 folder picker buttons work correctly
- [ ] Page 1 validates export path != project path
- [ ] Page 2 displays platform checkboxes
- [ ] Page 2 Source Filters button visible when Source checked
- [ ] Navigation buttons (Exit, Back, Next) work correctly
- [ ] Page transitions are instant (no animation)
- [ ] All field changes auto-save to project config
- [ ] Exit returns to Project Manager
- [ ] All existing release manager functionality preserved

## Testing Checklist
- [ ] Navigate forward through all pages
- [ ] Navigate backward through breadcrumb clicks
- [ ] Change settings on Page 1, verify auto-save
- [ ] Select/deselect exports on Page 2, verify auto-save
- [ ] Open Source Filters dialog, verify changes save
- [ ] Exit wizard and reopen, verify settings persisted
- [ ] Validate folder pickers work correctly
- [ ] Verify export path validation works
