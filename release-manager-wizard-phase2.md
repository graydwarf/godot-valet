# Release Manager Wizard - Phase 2: Obfuscation Page

## Overview
Implement Page 3: Obfuscation settings, excludes, and testing tools. This page allows users to configure code obfuscation options and test them before final export.

## Goals
- Create Page 3 UI with obfuscation settings
- Integrate Function/Variable/Comment exclude lists
- Add Source Filters configuration
- Implement obfuscation test buttons (Open/Edit/Run)
- Add output log area for test results
- Display obfuscation statistics after testing

## Features

### Page 3: Obfuscation

**Purpose**: Configure obfuscation settings and test before export

**Layout**:
```
┌─────────────────────────────────────────────────────────────┐
│ Obfuscation Settings                                        │
│                                                             │
│ Code Obfuscation:                                           │
│ ☑ Obfuscate Functions                                      │
│ ☑ Obfuscate Variables                                       │
│ ☑ Obfuscate Comments                                        │
│                                                             │
│ Exclude Lists:                                              │
│ [Function Excludes...] [Variable Excludes...] [?]          │
│                                                             │
│ Build Filters:                                              │
│ [Source Filters...]                                         │
│ Note: These filters affect ALL builds (not just source)    │
│                                                             │
│ ─────────────────────────────────────────────────────────  │
│                                                             │
│ Test Options:                                               │
│ [Obfuscate - Open] [Obfuscate - Edit] [Obfuscate - Run]   │
│                                                             │
│ Output:                                                     │
│ ┌─────────────────────────────────────────────────────┐   │
│ │ Obfuscating to temp folder...                       │   │
│ │ Removed 127 comments                                │   │
│ │ Obfuscated 89 functions                             │   │
│ │ Obfuscated 156 variables                            │   │
│ │ Time: 2.3s                                           │   │
│ │ Output: C:\Users\...\AppData\Roaming\Godot\...      │   │
│ │ ✓ Complete                                           │   │
│ └─────────────────────────────────────────────────────┘   │
│                                                             │
│ [Exit]                              [← Back] [Next →]      │
└─────────────────────────────────────────────────────────────┘
```

**Obfuscation Options**:
- CheckBox: Obfuscate Functions
- CheckBox: Obfuscate Variables
- CheckBox: Obfuscate Comments
- All checkboxes can be unchecked (no obfuscation)

**Exclude Lists Section**:
- [Function Excludes...] button - Opens function exclude list dialog
- [Variable Excludes...] button - Opens variable exclude list dialog
- [?] help button - Opens obfuscation-help-dialog.tscn

**Build Filters Section**:
- [Source Filters...] button - Opens source-filter-dialog.tscn
- Info label clarifying filters affect ALL builds
- Suggest defaults: tests/, .git/, .import/

**Test Options**:
- [Obfuscate - Open] - Obfuscate to temp, open folder in explorer
- [Obfuscate - Edit] - Obfuscate to temp, launch in Godot editor
- [Obfuscate - Run] - Obfuscate to temp, run the project
- All buttons trigger obfuscation to temp directory (not final export)

**Output Log**:
- TextEdit (read-only, scrollable)
- Shows real-time obfuscation progress
- Displays statistics after completion:
  - Number of comments removed
  - Number of functions obfuscated
  - Number of variables obfuscated
  - Time taken
  - Output path
- Shows errors if obfuscation fails

**Validation**:
- No required fields - user can proceed with any settings
- If obfuscation enabled but exclude lists conflict, warn in output

**Auto-Save**:
- Checkbox changes save immediately
- Exclude list changes save when dialogs close

## Technical Implementation

### page3-obfuscation.gd

```gdscript
extends WizardPageBase

@onready var _obfuscateFunctionsCheckBox = %ObfuscateFunctionsCheckBox
@onready var _obfuscateVariablesCheckBox = %ObfuscateVariablesCheckBox
@onready var _obfuscateCommentsCheckBox = %ObfuscateCommentsCheckBox
@onready var _functionExcludesButton = %FunctionExcludesButton
@onready var _variableExcludesButton = %VariableExcludesButton
@onready var _sourceFiltersButton = %SourceFiltersButton
@onready var _outputTextEdit = %OutputTextEdit
@onready var _openTempButton = %OpenTempButton
@onready var _editWithButton = %EditWithButton
@onready var _runWithButton = %RunWithButton

var _pathToUserTempSourceFolder = OS.get_user_data_dir() + "/temp/source"

func _loadPageData():
    _obfuscateFunctionsCheckBox.button_pressed = _selectedProjectItem.GetObfuscateFunctionsChecked()
    _obfuscateVariablesCheckBox.button_pressed = _selectedProjectItem.GetObfuscateVariablesChecked()
    _obfuscateCommentsCheckBox.button_pressed = _selectedProjectItem.GetObfuscateCommentsChecked()

func save():
    _selectedProjectItem.SetObfuscateFunctionsChecked(_obfuscateFunctionsCheckBox.button_pressed)
    _selectedProjectItem.SetObfuscateVariablesChecked(_obfuscateVariablesCheckBox.button_pressed)
    _selectedProjectItem.SetObfuscateCommentsChecked(_obfuscateCommentsCheckBox.button_pressed)
    _selectedProjectItem.SaveProjectItem()

func validate() -> bool:
    # Always valid - obfuscation is optional
    return true

func _onOpenTempPressed():
    await _testObfuscation()
    FileHelper.OpenDirectoryInExplorer(_pathToUserTempSourceFolder)

func _onEditWithPressed():
    await _testObfuscation()
    var godotPath = _selectedProjectItem.GetGodotPath(_selectedProjectItem.GetGodotVersionId())
    OS.execute(godotPath, ["--path", _pathToUserTempSourceFolder])

func _onRunWithPressed():
    await _testObfuscation()
    var godotPath = _selectedProjectItem.GetGodotPath(_selectedProjectItem.GetGodotVersionId())
    OS.execute(godotPath, ["--path", _pathToUserTempSourceFolder])

func _testObfuscation():
    _outputTextEdit.text = "Starting obfuscation test...\n"

    # Clean temp folder
    var err = _prepTempDirectory()
    if err != OK:
        _outputTextEdit.text += "ERROR: Failed to prepare temp directory\n"
        return

    # Copy source to temp
    _outputTextEdit.text += "Copying source to temp folder...\n"
    var sourcePath = _selectedProjectItem.GetFormattedProjectPath()
    var sourceFilters = _selectedProjectItem.GetSourceFilters()
    err = FileHelper.CopyFoldersAndFilesRecursive(sourcePath, _pathToUserTempSourceFolder, sourceFilters)
    if err != OK:
        _outputTextEdit.text += "ERROR: Failed to copy source\n"
        return

    # Skip obfuscation if all options disabled
    if !_obfuscateFunctionsCheckBox.button_pressed && !_obfuscateVariablesCheckBox.button_pressed && !_obfuscateCommentsCheckBox.button_pressed:
        _outputTextEdit.text += "Obfuscation disabled - skipping\n"
        _outputTextEdit.text += "Output: " + _pathToUserTempSourceFolder + "\n"
        _outputTextEdit.text += "✓ Complete\n"
        return

    # Run obfuscation
    _outputTextEdit.text += "Obfuscating code...\n"
    var startTime = Time.get_ticks_msec()

    # Parse exclude lists
    var funcExclude = _parseExcludeList(_selectedProjectItem.GetFunctionExcludeList())
    var varExclude = _parseExcludeList(_selectedProjectItem.GetVariableExcludeList())
    ObfuscateHelper.SetFunctionExcludeList(funcExclude)
    ObfuscateHelper.SetVariableExcludeList(varExclude)

    # Obfuscate in-place
    err = ObfuscateHelper.ObfuscateScripts(
        _pathToUserTempSourceFolder,
        _pathToUserTempSourceFolder,
        _obfuscateFunctionsCheckBox.button_pressed,
        _obfuscateVariablesCheckBox.button_pressed,
        _obfuscateCommentsCheckBox.button_pressed
    )

    if err != OK:
        _outputTextEdit.text += "ERROR: Obfuscation failed\n"
        return

    var elapsedTime = (Time.get_ticks_msec() - startTime) / 1000.0

    # Get statistics from obfuscator
    var stats = ObfuscateHelper.GetLastObfuscationStats()
    _outputTextEdit.text += "Removed %d comments\n" % stats.comments_removed
    _outputTextEdit.text += "Obfuscated %d functions\n" % stats.functions_obfuscated
    _outputTextEdit.text += "Obfuscated %d variables\n" % stats.variables_obfuscated
    _outputTextEdit.text += "Time: %.1fs\n" % elapsedTime
    _outputTextEdit.text += "Output: " + _pathToUserTempSourceFolder + "\n"
    _outputTextEdit.text += "✓ Complete\n"

func _prepTempDirectory():
    var tempFolder = OS.get_user_data_dir() + "/temp"
    if !DirAccess.dir_exists_absolute(tempFolder):
        DirAccess.make_dir_recursive_absolute(tempFolder)

    # Clean existing temp source folder
    if DirAccess.dir_exists_absolute(_pathToUserTempSourceFolder):
        var err = FileHelper.DeleteAllFilesAndFolders(_pathToUserTempSourceFolder)
        if err != OK:
            return err

    return OK

func _parseExcludeList(text: String) -> Array:
    var result = []
    var items = text.split("\n")
    for item in items:
        var cleaned = item.strip_edges()
        if cleaned != "" and not cleaned.begins_with("#"):
            result.append(cleaned)
    return result

func _onFunctionExcludesPressed():
    # Open exclude-list-dialog.tscn with function excludes
    pass

func _onVariableExcludesPressed():
    # Open exclude-list-dialog.tscn with variable excludes
    pass

func _onSourceFiltersPressed():
    # Open source-filter-dialog.tscn
    pass
```

### Obfuscation Statistics

Need to add stats tracking to `ObfuscateHelper`:

```gdscript
# In obfuscator.gd
static var _lastObfuscationStats: Dictionary = {
    "comments_removed": 0,
    "functions_obfuscated": 0,
    "variables_obfuscated": 0
}

static func GetLastObfuscationStats() -> Dictionary:
    return _lastObfuscationStats

# Update stats during obfuscation
static func RemoveCommentsFromCode(contentPayload: ContentPayload):
    var beforeCount = _countComments(contentPayload.GetContent())
    # ... existing comment removal logic ...
    var afterCount = _countComments(contentPayload.GetContent())
    _lastObfuscationStats.comments_removed += (beforeCount - afterCount)

static func AddFunctionsToSymbolMap(code: String, symbolMap: Dictionary):
    # ... existing logic ...
    _lastObfuscationStats.functions_obfuscated += symbolMap.size()
```

## Integration with Existing Code

### Reuse Existing Components
- `scenes/source-filter-dialog/source-filter-dialog.tscn` - Already exists
- `scenes/release-manager/exclude-list-dialog.tscn` - Already exists (if it exists)
- `scenes/release-manager/obfuscation-help-dialog.tscn` - Already exists
- `scripts/obfuscator.gd` (ObfuscateHelper) - Already exists

### Connect to Current release-manager.gd Logic
- Extract temp folder prep logic (lines 492-527)
- Extract obfuscation logic (lines 585-604)
- Extract exclude list parsing (lines 573-582)
- Move to page3-obfuscation.gd

## Files to Modify
- Create `scenes/release-manager/pages/page3-obfuscation.tscn`
- Create `scenes/release-manager/pages/page3-obfuscation.gd`
- Modify `scripts/obfuscator.gd` - Add statistics tracking
- Update `scenes/release-manager/release-manager.gd` - Wire up Page 3

## UI Considerations

### Output Log Formatting
- Use monospace font for better readability
- Color-code output:
  - Normal: white
  - Success (✓): green
  - Error: red
  - Stats: cyan
- Auto-scroll to bottom as new output appears

### Button States
- Disable test buttons while obfuscation is running
- Show progress spinner during obfuscation
- Re-enable when complete or failed

### Help Button (?)
- Opens existing obfuscation-help-dialog.tscn
- Provides comprehensive guide on obfuscation system
- Explains what each option does
- Testing best practices

## Acceptance Criteria
- [ ] Page 3 displays obfuscation checkboxes
- [ ] Checkboxes auto-save on change
- [ ] Function Excludes button opens dialog
- [ ] Variable Excludes button opens dialog
- [ ] Source Filters button opens dialog
- [ ] Help (?) button opens obfuscation guide
- [ ] Test buttons trigger obfuscation to temp folder
- [ ] "Obfuscate - Open" opens temp folder in explorer
- [ ] "Obfuscate - Edit" launches Godot editor with temp project
- [ ] "Obfuscate - Run" executes temp project
- [ ] Output log shows real-time progress
- [ ] Output log displays obfuscation statistics
- [ ] Statistics show correct counts (comments, functions, variables)
- [ ] Statistics show elapsed time
- [ ] Errors display clearly in output log
- [ ] Test buttons disabled during obfuscation
- [ ] Can proceed to Next with any obfuscation settings
- [ ] All settings persist when navigating back

## Testing Checklist
- [ ] Enable all obfuscation options, test each button
- [ ] Disable all obfuscation options, verify skip message
- [ ] Add function excludes, verify they're respected
- [ ] Add variable excludes, verify they're respected
- [ ] Add source filters, verify files excluded from temp
- [ ] Navigate Back and Next, verify settings persist
- [ ] Open obfuscated temp project in editor, verify it works
- [ ] Run obfuscated temp project, verify it executes
- [ ] Check output log formatting and colors
- [ ] Verify statistics are accurate
- [ ] Test with projects of varying sizes
