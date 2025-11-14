# Session State: Release Manager Wizard Redesign

**Date**: 2025-01-14
**Project**: godot-valet
**Task**: Transform Release Manager from single-page form to multi-step wizard

---

## Current Status

**Phase**: Design Complete, Ready for Implementation
**Next Step**: Begin Phase 1 implementation (foundation + Pages 1-2)

---

## Design Documentation Location

All design documents are in the project root:
- `release-manager-wizard-phase1.md` - Foundation, Pages 1-2, Build Config dialog ⭐ START HERE
- `release-manager-wizard-phase2.md` - Obfuscation page (OBSOLETE - will be deleted)
- `release-manager-wizard-phase3.md` - Build/Export page (needs updating to be Phase 2)
- `release-manager-wizard-phase4.md` - Publishing page (needs updating to be Phase 3)
- `release-manager-wizard-phase5.md` - Polish/refinements (needs updating to be Phase 4)

**Note**: Phase docs are for reference only, NOT committed to git.

---

## Final Design Summary

### 4-Page Wizard Structure

**Page 1: Project Settings**
- Project name, version, paths
- Export path, filename
- Folder pickers for project/export paths
- Validation: Export path must not equal project path

**Page 2: Select Exports + Per-Platform Build Configuration**
- Checkboxes for each platform (Windows, Web, Linux, Source)
- **[⚙ Build Config...]** button per platform opens dialog:
  - Obfuscation options (Functions/Variables/Comments)
  - Function excludes
  - Variable excludes
  - Source filters (per-platform)
  - **Clone dropdown** (top-right) to copy settings from other platforms
  - Test buttons: Open/Edit/Run
    - Run only enabled when: platform == current OS && platform != Web && platform != Source
  - Output log showing obfuscation test results
  - Save & Close or Cancel
- Summary text next to each platform:
  - "No Obfuscation" - all options unchecked
  - "Full Obfuscation" - all options checked, no excludes
  - "Partial Obfuscation (X excludes)" - partial settings or has excludes

**Page 3: Build/Export**
- Per-platform export controls
- "Build Type" column shows: Normal or 🔒 Obfuscated
- Individual Export buttons per platform
- Export All button
- Output log with export progress
- Obfuscation happens during export based on Page 2 config

**Page 4: Publish**
- Itch.io settings (profile, project name)
- Butler detection and status
- Per-platform Publish buttons
- Publish All button
- Selective publishing (export 3, publish 2)

### Navigation & Saving

**Breadcrumb Bar**: `[1. Settings] → [2. Exports] → [3. Build] → [4. Publish]`
- Current page highlighted
- Click completed pages to go back

**Navigation Buttons**:
- `[Exit]` - Left side, prompts if unsaved changes on current page
- `[← Back] [Next →]` - Right side, saves current page when clicked
- Page 4: Next becomes Finish

**Save Behavior**:
- Settings save when clicking **Next** or **Back**
- **NOT** auto-save on every field change
- **Exit** does NOT save current page, prompts: "Exit without saving changes? [Discard & Exit] [Cancel]"
- Build Config dialog: [Save & Close] saves, [Cancel] discards

### Key Design Decisions

1. **Per-Platform Build Config** (not global obfuscation page)
   - Different platforms need different obfuscation (e.g., Web obfuscated, Windows not)
   - Each platform has its own settings stored independently
   - Clone feature makes it easy to copy/tweak settings

2. **Build Config Dialog** (not inline on Page 2)
   - Keeps Page 2 clean and scannable
   - Room for complex configuration (excludes, filters, testing)
   - Future-proof for additional build options (encryption, compression, etc.)

3. **Clone Dropdown** (not copy buttons or context menu)
   - In-dialog dropdown (top-right corner)
   - Clean, discoverable
   - Copies: obfuscation options, function excludes, variable excludes, source filters

4. **Test Run Button State**
   - Only enabled for matching OS (can't run Linux builds on Windows)
   - Disabled for Web (can't run web builds directly)
   - Disabled for Source (not executable)
   - Open/Edit always enabled (test obfuscation, view code)

5. **Save-on-Navigation** (not auto-save)
   - User expects control over saving in a "wizard" workflow
   - Allows experimenting without committing
   - Crash protection via Save on Next/Back
   - Exit without saving is intentional choice

6. **4 Pages Not 5**
   - Removed standalone obfuscation page (was Page 3)
   - Build config integrated into Page 2
   - Cleaner flow, less clicking

---

## Implementation Priority

### Phase 1 (Start Here)
**Files**: `release-manager-wizard-phase1.md`

**Goals**:
- Wizard navigation foundation (breadcrumbs, page switching)
- Page 1: Project Settings
- Page 2: Select Exports + Build Config Dialog
- Save-on-navigation behavior

**Key Components to Build**:
1. `scenes/release-manager/release-manager.gd` - Wizard controller
2. `scenes/release-manager/pages/page-base.gd` - Base class
3. `scenes/release-manager/pages/page1-settings.tscn/gd`
4. `scenes/release-manager/pages/page2-exports.tscn/gd`
5. `scenes/release-manager/components/wizard-breadcrumb.tscn/gd`
6. `scenes/release-manager/components/project-card.tscn/gd`
7. `scenes/release-manager/components/build-config-dialog.tscn/gd`

**ProjectItem Changes**:
```gdscript
# Add to scenes/project-item/project-item.gd:
func GetPlatformBuildConfigs() -> Dictionary
func SetPlatformBuildConfigs(configs: Dictionary)

# Config structure:
{
  "Windows": {
    "obfuscate_functions": bool,
    "obfuscate_variables": bool,
    "obfuscate_comments": bool,
    "function_excludes": Array[String],
    "variable_excludes": Array[String],
    "source_filters": Array[String]
  },
  "Web": { ... },
  "Linux": { ... },
  "Source": { ... }
}
```

### Phase 2
**Files**: Currently `release-manager-wizard-phase3.md` (rename to phase2.md)

**Goals**:
- Page 3: Build/Export with per-platform controls
- Read build configs from Page 2
- Execute exports with platform-specific obfuscation
- Show build type indicator (Normal vs Obfuscated)

### Phase 3
**Files**: Currently `release-manager-wizard-phase4.md` (rename to phase3.md)

**Goals**:
- Page 4: Publishing to itch.io
- Butler detection
- Selective publishing

### Phase 4
**Files**: Currently `release-manager-wizard-phase5.md` (rename to phase4.md)

**Goals**:
- Polish: validation, error handling, keyboard shortcuts
- State invalidation warnings
- Performance optimizations

---

## Important Context from Discussion

### Why This Design?

**Problem Statement**:
- Need to obfuscate some platforms but not others (Web yes, Windows/Source no)
- Need to export multiple platforms with different configs in one session
- Need selective publishing (export 3, publish 2)
- Current single-page UI is overwhelming

**User Workflow Example**:
1. Configure project settings
2. Select: Windows, Web, Source
3. Web → Build Config → Full obfuscation
4. Windows → Build Config → No obfuscation
5. Source → Build Config → No obfuscation
6. Export all 3 platforms
7. Publish only Windows and Web (skip Source)

### Design Iterations

**Iteration 1**: Global obfuscation page (Page 3)
- ❌ Rejected: Can't configure different settings per platform

**Iteration 2**: Per-platform obfuscation checkboxes on Page 2
- ❌ Rejected: Cluttered UI, couldn't configure excludes/filters per platform

**Iteration 3**: Build Config button per platform on Page 2 ✅ FINAL
- ✅ Clean Page 2 UI
- ✅ Full configuration in dialog
- ✅ Clone feature for easy setup
- ✅ Testing right in dialog
- ✅ Per-platform source filters

---

## Technical Notes

### Obfuscation Test Buttons

**Obfuscate - Open**:
- Copy source → temp
- Apply obfuscation (if enabled)
- Open temp folder in explorer
- Always enabled

**Obfuscate - Edit**:
- Copy source → temp
- Apply obfuscation (if enabled)
- Launch Godot editor with temp project
- Always enabled

**Obfuscate - Run**:
- Copy source → temp
- Apply obfuscation (if enabled)
- Execute project
- Enabled only when: `platform == OS.get_name() && platform != "Web" && platform != "Source"`
- Disabled tooltip: "Cannot run {platform} builds on {current_OS}"

### Export Workflow Per Platform

```gdscript
func _exportPlatform(platform: String):
    # 1. Copy source to temp (if not already done)
    if !_tempSourceReady:
        _copySourceToTemp()
        _tempSourceReady = true

    # 2. Check if this platform needs obfuscation
    var buildConfig = _platformBuildConfigs[platform]
    var needsObfuscation = buildConfig.get("obfuscate_functions", false) ||
                           buildConfig.get("obfuscate_variables", false) ||
                           buildConfig.get("obfuscate_comments", false)

    # 3. Obfuscate if needed (in-place in temp)
    if needsObfuscation:
        _obfuscateWithConfig(buildConfig)

    # 4. Export from temp
    _exportPreset(platform)

    # 5. Generate checksum if enabled
    if _generateChecksums:
        _createChecksum(platform)
```

### Summary Text Logic

```gdscript
func _getSummaryText(platform: String) -> String:
    var config = _platformBuildConfigs[platform]
    var funcCheck = config.get("obfuscate_functions", false)
    var varCheck = config.get("obfuscate_variables", false)
    var commentCheck = config.get("obfuscate_comments", false)
    var funcExcludes = config.get("function_excludes", [])
    var varExcludes = config.get("variable_excludes", [])

    if !funcCheck && !varCheck && !commentCheck:
        return "No Obfuscation"

    var totalExcludes = funcExcludes.size() + varExcludes.size()
    if funcCheck && varCheck && commentCheck && totalExcludes == 0:
        return "Full Obfuscation"
    else:
        if totalExcludes > 0:
            return "Partial Obfuscation (%d excludes)" % totalExcludes
        else:
            return "Partial Obfuscation"
```

---

## Files to Reference

### Existing Code to Reuse

**Current Release Manager**:
- `scenes/release-manager/release-manager.tscn` - Will be restructured
- `scenes/release-manager/release-manager.gd` - Lots of export logic to reuse

**Existing Dialogs**:
- `scenes/source-filter-dialog/source-filter-dialog.tscn` - Reuse for source filters
- `scenes/release-manager/exclude-list-dialog.tscn` - Reuse for function/variable excludes (if exists)
- `scenes/release-manager/obfuscation-help-dialog.tscn` - Reuse for help (?)

**Obfuscator**:
- `scripts/obfuscator.gd` (ObfuscateHelper) - Core obfuscation logic
- Will need to add statistics tracking (Phase 1)

### Relevant Git Commits

- `129565b` - Add 'Test Options:' label to obfuscation testing buttons
- `ae3d5ac` - Add Release Manager Wizard redesign - 5 phase implementation plan (original)

---

## Next Session Checklist

When resuming work:

1. ✅ Read this session state document
2. ✅ Review `release-manager-wizard-phase1.md` in detail
3. ⬜ Create `scenes/release-manager/pages/` directory
4. ⬜ Create `scenes/release-manager/components/` directory
5. ⬜ Implement `page-base.gd` base class
6. ⬜ Implement wizard breadcrumb component
7. ⬜ Implement project card component
8. ⬜ Create Page 1: Project Settings scene
9. ⬜ Create Page 2: Select Exports scene
10. ⬜ Create Build Config Dialog scene
11. ⬜ Wire up navigation (Next/Back/Exit)
12. ⬜ Implement save-on-navigation behavior
13. ⬜ Test wizard flow end-to-end

---

## Questions to Consider During Implementation

1. **Breadcrumb Styling**: Use custom drawing or standard buttons?
2. **Project Card**: Collapsible or always visible?
3. **Build Config Dialog Size**: Fixed or resizable?
4. **Clone Dropdown**: Native PopupMenu or custom?
5. **Test Button Layout**: Horizontal row or vertical stack?
6. **Output Log**: Shared component or per-dialog?

---

## End of Session State

**Status**: Design finalized and documented
**Ready**: Phase 1 implementation can begin
**Blockers**: None
**Notes**: Phase docs are reference only, not committed to git
