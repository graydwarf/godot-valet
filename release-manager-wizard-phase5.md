# Release Manager Wizard - Phase 5: Polish & Refinements

## Overview
Final polish phase to enhance UX, add validation, improve error handling, and implement state management for navigating between pages.

## Goals
- Add progress indicators (page completion status)
- Implement state invalidation when navigating back
- Add validation warnings and error messages
- Improve visual feedback and animations
- Add keyboard shortcuts
- Implement "dirty state" warnings
- Add status persistence across sessions
- Performance optimizations
- Accessibility improvements

## Features

### 1. Progress Indicators

**Breadcrumb Enhancement**:
```
[1. Settings] → [2. Exports] → [3. Obfuscation] → [4. Build] → [5. Publish]
     ✓              ✓               ○              ○           ○
```
- ✓ = Page completed and valid (green)
- ● = Current page (highlighted)
- ○ = Not visited yet (gray)
- Each step clickable if previously completed

**Page Completion Logic**:
- Page 1: Complete when all required fields filled
- Page 2: Complete when at least one platform selected
- Page 3: Complete when visited (obfuscation optional)
- Page 4: Complete when at least one platform exported
- Page 5: Complete when visited (publishing optional)

### 2. State Invalidation

**When Navigating Back and Making Changes**:

If user changes Page 2 (platform selection):
- Show warning on Page 2: "⚠ Changing platforms will clear export results"
- When Next → Page 4: Clear all export status (reset to "Ready")
- Breadcrumb: Page 4 changes from ✓ to ○

If user changes Page 3 (obfuscation settings):
- Show warning on Page 3: "⚠ Changing obfuscation will invalidate exports"
- When Next → Page 4: Clear export status
- Breadcrumb: Page 4 changes from ✓ to ○

Implementation:
```gdscript
# release-manager.gd
var _pageStates: Dictionary = {
    "page2_platforms": [],
    "page3_obfuscation_hash": "",
    "page4_exported": false,
    "page5_published": false
}

func _onPage2SettingsChanged():
    var newPlatforms = _getCurrentPlatformSelection()
    if newPlatforms != _pageStates.page2_platforms:
        _showInvalidationWarning("Changing platforms will clear export results")
        _invalidatePage(4)
        _invalidatePage(5)
        _pageStates.page2_platforms = newPlatforms

func _invalidatePage(pageIndex: int):
    # Reset page state
    # Update breadcrumb to show ○ instead of ✓
    # Clear results on that page
```

### 3. Validation & Error Handling

**Page 1 Validation**:
- Project Name: Required, show red border if empty
- Export Path: Required, show error if same as Project Path
- Project Version: Warn if not vX.Y.Z format (non-blocking)

**Page 2 Validation**:
- At least one platform selected to proceed
- If export_presets.cfg missing, show warning banner:
  ```
  ⚠ Warning: No export presets found
  Configure export presets in Godot before building
  ```

**Page 4 Validation**:
- Block Next if all exports failed
- Show error summary if any exports failed:
  ```
  ⚠ 2 of 3 exports failed
  Windows: ✓ Success
  Linux: ✗ Failed - Missing export template
  Web: ✗ Failed - Invalid export path
  ```

**Error Display Component**:
```gdscript
class_name ErrorBanner extends PanelContainer

@onready var _icon = %Icon
@onready var _message = %Message

enum Type { INFO, WARNING, ERROR }

func show_message(message: String, type: Type):
    _message.text = message
    match type:
        Type.INFO:
            _icon.texture = preload("res://icons/info.png")
            modulate = Color(0.2, 0.5, 1.0)
        Type.WARNING:
            _icon.texture = preload("res://icons/warning.png")
            modulate = Color(1.0, 0.7, 0.0)
        Type.ERROR:
            _icon.texture = preload("res://icons/error.png")
            modulate = Color(1.0, 0.2, 0.2)
    visible = true
```

### 4. Visual Feedback

**Field Validation Indicators**:
- Valid field: default border
- Invalid field: red border + error icon
- Warning field: orange border + warning icon

**Button States**:
- Default: Normal appearance
- Disabled: Grayed out with tooltip explaining why
- Loading: Show spinner, disable interaction
- Success: Brief green flash on completion

**Status Transitions**:
- "Ready" → "Exporting..." → "✓ Exported" with smooth color transitions
- Add 200ms fade when changing status colors

**Output Log Enhancements**:
- Color-coded output (errors red, success green, info white)
- Monospace font for better readability
- Timestamps for each log entry (optional)
- Auto-scroll to bottom as new entries appear
- [Clear Log] button

### 5. Keyboard Shortcuts

Global shortcuts across all pages:
- `Ctrl+Enter`: Next button (if enabled)
- `Ctrl+Backspace`: Back button (if enabled)
- `Escape`: Exit wizard (with confirmation if dirty)
- `F1`: Open help for current page

Page-specific shortcuts:
- Page 3: `Ctrl+O`: Obfuscate - Open
- Page 3: `Ctrl+E`: Obfuscate - Edit
- Page 3: `Ctrl+R`: Obfuscate - Run
- Page 4: `Ctrl+Shift+E`: Export All
- Page 5: `Ctrl+Shift+P`: Publish All

```gdscript
# release-manager.gd
func _input(event: InputEvent):
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ENTER and event.ctrl_pressed:
            _onNextPressed()
        elif event.keycode == KEY_BACKSPACE and event.ctrl_pressed:
            _onBackPressed()
        elif event.keycode == KEY_ESCAPE:
            _onExitPressed()
        elif event.keycode == KEY_F1:
            _showHelpForCurrentPage()
```

### 6. Dirty State Warnings

**Exit Confirmation**:
If user clicks Exit while work in progress:
- Exporting in progress → Block exit, show "Export in progress, please wait"
- Publishing in progress → Block exit, show "Publishing in progress, please wait"
- Otherwise → Allow exit (auto-save handles persistence)

**Navigation Confirmation**:
When navigating away from page with unsaved work:
- Currently not needed (all pages auto-save)
- But show warning if export/publish in progress

### 7. Status Persistence

**Save Export/Publish Status**:
When user exits wizard mid-export:
- Save which platforms were exported
- Save export timestamps
- On return, show status:
  ```
  Windows: ✓ Exported (5 minutes ago)
  Linux: ✗ Failed
  Web: Not exported yet
  ```

**Implementation**:
```gdscript
# project-item.gd
var _exportStatus: Dictionary = {
    "Windows": {"status": "exported", "timestamp": 1234567890},
    "Linux": {"status": "failed", "timestamp": 1234567890},
    "Web": {"status": "not_exported", "timestamp": 0}
}

func SaveProjectItem():
    # ... existing save logic ...
    config.set_value("ProjectSettings", "export_status", _exportStatus)
```

### 8. Performance Optimizations

**Lazy Loading**:
- Don't create all 5 pages on wizard open
- Create pages on-demand when first visited
- Cache created pages for instant switching

**Output Log Optimization**:
- Limit log to last 1000 lines
- Truncate old entries if exceeded
- Add "View Full Log" button to open in external editor

**File Operations**:
- Show progress bar for large file copies
- Use threads for obfuscation (don't block UI)
- Stream Butler output instead of waiting for completion

### 9. Accessibility

**Screen Reader Support**:
- Add aria labels to all interactive elements
- Announce page changes
- Announce status updates

**High Contrast Mode**:
- Respect OS high contrast settings
- Ensure color-coded status has text alternatives
- Don't rely solely on color for status (use icons + text)

**Focus Management**:
- Auto-focus first field on page load
- Tab order logical and intuitive
- Keyboard navigation for all features

### 10. Help & Documentation

**Per-Page Help**:
- F1 or [?] button opens context-sensitive help
- Page 1: Explains project settings, export path recommendations
- Page 2: Explains export presets, platform-specific notes
- Page 3: Links to obfuscation guide
- Page 4: Export troubleshooting, common errors
- Page 5: Butler setup guide, itch.io channel naming

**Tooltips**:
- Every field has descriptive tooltip
- Buttons explain what they do
- Status values have explanatory tooltips

### 11. Additional Polish

**First-Time User Experience**:
- Detect if this is user's first time opening wizard
- Show brief tutorial overlay highlighting key features
- "Don't show again" checkbox

**Recent Exports List**:
- Page 4: Show "Last exported: 2 hours ago" under each platform
- Click to open that export in explorer

**Smart Defaults**:
- If project version not set, suggest "v1.0.0"
- If export filename empty, suggest project name
- If export path empty, suggest Documents/Exports/{ProjectName}

**Batch Operations**:
- Page 4: "Re-export All" button (clears and re-exports)
- Page 5: "Re-publish All" button

## Technical Implementation

### Enhanced WizardPageBase

```gdscript
extends Control
class_name WizardPageBase

signal page_changed()
signal validation_changed(is_valid: bool)
signal state_changed()

var _selectedProjectItem = null
var _isComplete: bool = false

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

func get_completion_status() -> bool:
    # Override in subclasses
    return _isComplete

func invalidate():
    # Called when previous page changes invalidate this page
    _isComplete = false
    emit_signal("state_changed")

func show_help():
    # Override in subclasses - show page-specific help
    pass
```

### Wizard State Manager

```gdscript
# wizard-state-manager.gd
class_name WizardStateManager

static var _pageStates: Dictionary = {}

static func save_page_state(page_index: int, state: Dictionary):
    _pageStates[page_index] = state

static func get_page_state(page_index: int) -> Dictionary:
    return _pageStates.get(page_index, {})

static func invalidate_page(page_index: int):
    if _pageStates.has(page_index):
        _pageStates[page_index]["valid"] = false

static func clear_all():
    _pageStates.clear()
```

## Files to Modify
- Enhance `scenes/release-manager/pages/page-base.gd`
- Create `scenes/release-manager/wizard-state-manager.gd`
- Create `scenes/release-manager/components/error-banner.tscn/gd`
- Update all page scripts (page1-5) with validation and help
- Update `scenes/release-manager/release-manager.gd` with keyboard shortcuts
- Update `scenes/project-item/project-item.gd` with export status persistence

## Acceptance Criteria

### Progress & State
- [ ] Breadcrumb shows ✓ for completed pages
- [ ] Changing platforms on Page 2 invalidates Page 4
- [ ] Changing obfuscation on Page 3 invalidates Page 4
- [ ] Invalidation warnings display correctly

### Validation
- [ ] Page 1 validates required fields
- [ ] Page 2 validates at least one platform
- [ ] Export path validation works
- [ ] Error banners display for validation failures

### Visual Feedback
- [ ] Invalid fields show red border
- [ ] Button states (disabled, loading, success) work
- [ ] Status transitions smooth
- [ ] Output logs color-coded

### Keyboard Shortcuts
- [ ] Ctrl+Enter triggers Next
- [ ] Ctrl+Backspace triggers Back
- [ ] Escape triggers Exit
- [ ] F1 opens help
- [ ] Page-specific shortcuts work

### Persistence
- [ ] Export status persists across sessions
- [ ] Wizard state saves on exit
- [ ] Restored state accurate on reopen

### Performance
- [ ] Pages load quickly
- [ ] Large exports don't block UI
- [ ] Output logs handle high volume

### Accessibility
- [ ] Tab order logical
- [ ] All elements keyboard accessible
- [ ] Tooltips present and helpful
- [ ] High contrast mode supported

## Testing Checklist
- [ ] Test all keyboard shortcuts
- [ ] Change platforms, verify Page 4 invalidated
- [ ] Change obfuscation, verify Page 4 invalidated
- [ ] Fill Page 1 with invalid data, verify errors
- [ ] Select no platforms on Page 2, verify blocked
- [ ] Export with failures, verify error summary
- [ ] Test Exit during export, verify blocked
- [ ] Test Exit with clean state, verify allowed
- [ ] Test persistence: export, exit, reopen - verify status restored
- [ ] Test with large project, verify performance
- [ ] Test keyboard-only navigation
- [ ] Test with screen reader (if available)
- [ ] Test all tooltips present and accurate
- [ ] Test help (F1) on each page
- [ ] Verify output logs don't exceed memory limits
- [ ] Test smooth status color transitions
