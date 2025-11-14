# Release Manager Wizard - Phase 3: Build/Export Page

## Overview
Implement Page 4: Build execution with granular per-platform export controls. This page handles the actual export process, including obfuscation (if enabled) and checksum generation.

## Goals
- Create Page 4 UI with per-platform export controls
- Implement individual platform export buttons
- Add "Export All Selected" button
- Display export status per platform
- Show export preview with generated filenames
- Add checksum generation option
- Integrate output log for export progress
- Handle obfuscation during export (not in Page 3)

## Features

### Page 4: Build

**Purpose**: Execute exports with per-platform control and monitoring

**Layout**:
```
┌─────────────────────────────────────────────────────────────────┐
│ Build & Export                                                  │
│                                                                 │
│ Export Options:                                                 │
│ Export Type:  [Release ▼]                                      │
│ Package Type: [Zip ▼]                                           │
│ ☑ Auto-generate unique filenames (adds version + platform)     │
│ ☑ Generate SHA256 checksum                                     │
│                                                                 │
│ Export Preview:                                                 │
│ kilanote-v1.2.3-windows.zip                                    │
│ kilanote-v1.2.3-linux.zip                                       │
│ kilanote-v1.2.3-web.zip                                         │
│                                                                 │
│ ────────────────────────────────────────────────────────────── │
│                                                                 │
│ Platforms:                                                      │
│ ┌─────────────────────────────────────────────────────────┐   │
│ │ Platform       Status          Actions                  │   │
│ │ ──────────────────────────────────────────────────────  │   │
│ │ Windows        Ready           [Export] [Open Folder]   │   │
│ │ Linux          Ready           [Export] [Open Folder]   │   │
│ │ Web            Ready           [Export] [Open Folder]   │   │
│ │ Source         Ready           [Export] [Open Folder]   │   │
│ └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│ [Export All Selected]                                           │
│                                                                 │
│ Output:                                                         │
│ ┌─────────────────────────────────────────────────────────┐   │
│ │ Preparing temp directory...                             │   │
│ │ Copying source to temp...                               │   │
│ │ Obfuscating code... (if enabled)                        │   │
│ │   Removed 127 comments                                  │   │
│ │   Obfuscated 89 functions                               │   │
│ │   Obfuscated 156 variables                              │   │
│ │ Exporting Windows Desktop... ✓                          │   │
│ │ Exporting Linux... ✓                                     │   │
│ │ Exporting Web... ✓                                       │   │
│ │ Generating checksums...                                  │   │
│ │   kilanote-v1.2.3-windows.zip: a3f5b2c...               │   │
│ │ ✓ All exports complete                                   │   │
│ └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│ [Exit]                                [← Back] [Next →]        │
└─────────────────────────────────────────────────────────────────┘
```

**Export Options Section**:
- Export Type: OptionButton (Release/Debug)
- Package Type: OptionButton (Zip/No Zip)
- Auto-generate filenames: CheckBox
  - When enabled: `{filename}-v{version}-{platform}.zip`
  - When disabled: `{filename}.zip`
- Generate SHA256: CheckBox (creates checksum of each export)

**Export Preview Section**:
- Read-only TextEdit showing generated filenames
- Updates dynamically when options change
- Shows what will be created when Export runs
- Only shows platforms checked on Page 2

**Platforms Table**:
- Shows only platforms selected on Page 2
- Columns:
  - **Platform**: Windows, Linux, Web, Source
  - **Status**: Ready, Exporting..., ✓ Exported, ✗ Failed
  - **Actions**: [Export] [Open Folder]
- [Export] button: Exports that specific platform only
- [Open Folder] button: Opens export directory for that platform

**Export All Selected Button**:
- Large primary button
- Exports all platforms listed in table
- Updates status column as each export completes
- Shows progress in output log

**Output Log**:
- Scrollable TextEdit (read-only)
- Shows real-time export progress
- Displays obfuscation stats (if enabled)
- Shows export results per platform
- Shows checksum values (if enabled)
- Errors displayed in red

**Status Values**:
- **Ready**: Not exported yet, ready to export
- **Exporting...**: Currently exporting (spinner icon)
- **✓ Exported**: Export completed successfully (green)
- **✗ Failed**: Export failed (red)

**Validation**:
- Disable Export buttons if export_presets.cfg missing
- Warn if export path doesn't exist
- Block Next if critical export failure

**Auto-Save**:
- Export options save immediately on change

## Technical Implementation

### page4-build.gd

```gdscript
extends WizardPageBase

@onready var _exportTypeOption = %ExportTypeOption
@onready var _packageTypeOption = %PackageTypeOption
@onready var _autoGenerateNamesCheck = %AutoGenerateNamesCheck
@onready var _generateChecksumCheck = %GenerateChecksumCheck
@onready var _exportPreviewText = %ExportPreviewText
@onready var _platformsTable = %PlatformsTable
@onready var _exportAllButton = %ExportAllButton
@onready var _outputLog = %OutputLog

var _pathToUserTempFolder = OS.get_user_data_dir() + "/temp"
var _pathToUserTempSourceFolder = _pathToUserTempFolder + "/source"
var _pathToUserTempExportFolder = _pathToUserTempFolder + "/export"

var _platformRows: Dictionary = {} # platform_name -> row_node

func _loadPageData():
    _exportTypeOption.text = _selectedProjectItem.GetExportType()
    _packageTypeOption.text = _selectedProjectItem.GetPackageType()
    _autoGenerateNamesCheck.button_pressed = _selectedProjectItem.GetAutoGenerateExportFileNamesChecked()
    _generateChecksumCheck.button_pressed = _selectedProjectItem.GetGenerateChecksumChecked()

    _buildPlatformsTable()
    _updateExportPreview()

func _buildPlatformsTable():
    # Clear existing rows
    for child in _platformsTable.get_children():
        child.queue_free()
    _platformRows.clear()

    # Add header row
    var header = _createTableRow("Platform", "Status", "Actions", true)
    _platformsTable.add_child(header)

    # Add row for each selected platform from Page 2
    var selectedPlatforms = _getSelectedPlatforms()
    for platform in selectedPlatforms:
        var row = _createPlatformRow(platform)
        _platformsTable.add_child(row)
        _platformRows[platform] = row

func _createPlatformRow(platform: String) -> HBoxContainer:
    var row = HBoxContainer.new()

    # Platform name label
    var nameLabel = Label.new()
    nameLabel.text = platform
    nameLabel.custom_minimum_size.x = 150
    row.add_child(nameLabel)

    # Status label
    var statusLabel = Label.new()
    statusLabel.text = "Ready"
    statusLabel.custom_minimum_size.x = 150
    statusLabel.name = "StatusLabel"
    row.add_child(statusLabel)

    # Export button
    var exportBtn = Button.new()
    exportBtn.text = "Export"
    exportBtn.pressed.connect(_onExportPlatform.bind(platform))
    row.add_child(exportBtn)

    # Open folder button
    var folderBtn = Button.new()
    folderBtn.text = "Open Folder"
    folderBtn.pressed.connect(_onOpenPlatformFolder.bind(platform))
    row.add_child(folderBtn)

    return row

func _getSelectedPlatforms() -> Array:
    var platforms = []
    if _selectedProjectItem.GetWindowsChecked():
        platforms.append("Windows")
    if _selectedProjectItem.GetLinuxChecked():
        platforms.append("Linux")
    if _selectedProjectItem.GetWebChecked():
        platforms.append("Web")
    if _selectedProjectItem.GetSourceChecked():
        platforms.append("Source")
    return platforms

func _updateExportPreview():
    var preview = ""
    var selectedPlatforms = _getSelectedPlatforms()
    var baseFilename = _selectedProjectItem.GetExportFileName()
    var version = _selectedProjectItem.GetProjectVersion()
    var autoGenerate = _autoGenerateNamesCheck.button_pressed
    var packageType = _packageTypeOption.text

    for platform in selectedPlatforms:
        var filename = baseFilename
        if autoGenerate:
            filename += "-" + version + "-" + platform.to_lower()
        if packageType == "Zip":
            filename += ".zip"
        else:
            filename += _getExtensionType(platform)
        preview += filename + "\n"

    _exportPreviewText.text = preview

func _getExtensionType(platform: String) -> String:
    match platform:
        "Windows": return ".exe"
        "Linux": return ".x86_64"
        "Web": return ".html"
        "Source": return ".zip"
    return ""

func _onExportAllPressed():
    _outputLog.text = ""
    var platforms = _getSelectedPlatforms()

    for platform in platforms:
        await _exportPlatform(platform)

    _outputLog.text += "✓ All exports complete\n"

func _onExportPlatform(platform: String):
    _outputLog.text = ""
    await _exportPlatform(platform)

func _exportPlatform(platform: String):
    _updatePlatformStatus(platform, "Exporting...")

    # Step 1: Prepare temp directory (first platform only)
    if !DirAccess.dir_exists_absolute(_pathToUserTempSourceFolder):
        _outputLog.text += "Preparing temp directory...\n"
        var err = _prepTempDirectory()
        if err != OK:
            _updatePlatformStatus(platform, "✗ Failed")
            _outputLog.text += "ERROR: Failed to prepare temp directory\n"
            return

        # Step 2: Copy source to temp
        _outputLog.text += "Copying source to temp...\n"
        err = _copySourceToTemp()
        if err != OK:
            _updatePlatformStatus(platform, "✗ Failed")
            _outputLog.text += "ERROR: Failed to copy source\n"
            return

        # Step 3: Obfuscate (if enabled)
        err = await _obfuscateSource()
        if err != OK:
            _updatePlatformStatus(platform, "✗ Failed")
            _outputLog.text += "ERROR: Obfuscation failed\n"
            return

    # Step 4: Export platform
    _outputLog.text += "Exporting " + platform + "...\n"
    var err = await _exportPreset(platform)
    if err != OK:
        _updatePlatformStatus(platform, "✗ Failed")
        _outputLog.text += "ERROR: Export failed for " + platform + "\n"
        return

    # Step 5: Generate checksum (if enabled)
    if _generateChecksumCheck.button_pressed:
        _outputLog.text += "Generating checksum for " + platform + "...\n"
        var checksum = _generateChecksum(platform)
        if checksum != "":
            _outputLog.text += "  SHA256: " + checksum + "\n"

    _updatePlatformStatus(platform, "✓ Exported")
    _outputLog.text += "✓ " + platform + " export complete\n"

func _updatePlatformStatus(platform: String, status: String):
    if _platformRows.has(platform):
        var row = _platformRows[platform]
        var statusLabel = row.get_node("StatusLabel")
        statusLabel.text = status

        # Color-code status
        match status:
            "✓ Exported":
                statusLabel.modulate = Color.GREEN
            "✗ Failed":
                statusLabel.modulate = Color.RED
            "Exporting...":
                statusLabel.modulate = Color.YELLOW
            _:
                statusLabel.modulate = Color.WHITE

func _prepTempDirectory() -> int:
    # Create temp folder if doesn't exist
    if !DirAccess.dir_exists_absolute(_pathToUserTempFolder):
        DirAccess.make_dir_recursive_absolute(_pathToUserTempFolder)

    # Clean temp source and export folders
    for folder in [_pathToUserTempSourceFolder, _pathToUserTempExportFolder]:
        if DirAccess.dir_exists_absolute(folder):
            var err = FileHelper.DeleteAllFilesAndFolders(folder)
            if err != OK:
                return err

    return OK

func _copySourceToTemp() -> int:
    var sourcePath = _selectedProjectItem.GetFormattedProjectPath()
    var sourceFilters = _selectedProjectItem.GetSourceFilters()
    return FileHelper.CopyFoldersAndFilesRecursive(sourcePath, _pathToUserTempSourceFolder, sourceFilters)

func _obfuscateSource() -> int:
    # Skip if all obfuscation options disabled
    if !_selectedProjectItem.GetObfuscateFunctionsChecked() && \
       !_selectedProjectItem.GetObfuscateVariablesChecked() && \
       !_selectedProjectItem.GetObfuscateCommentsChecked():
        return OK

    _outputLog.text += "Obfuscating code...\n"

    # Parse exclude lists
    var funcExclude = _parseExcludeList(_selectedProjectItem.GetFunctionExcludeList())
    var varExclude = _parseExcludeList(_selectedProjectItem.GetVariableExcludeList())
    ObfuscateHelper.SetFunctionExcludeList(funcExclude)
    ObfuscateHelper.SetVariableExcludeList(varExclude)

    # Obfuscate in-place
    var err = ObfuscateHelper.ObfuscateScripts(
        _pathToUserTempSourceFolder,
        _pathToUserTempSourceFolder,
        _selectedProjectItem.GetObfuscateFunctionsChecked(),
        _selectedProjectItem.GetObfuscateVariablesChecked(),
        _selectedProjectItem.GetObfuscateCommentsChecked()
    )

    if err == OK:
        var stats = ObfuscateHelper.GetLastObfuscationStats()
        _outputLog.text += "  Removed %d comments\n" % stats.comments_removed
        _outputLog.text += "  Obfuscated %d functions\n" % stats.functions_obfuscated
        _outputLog.text += "  Obfuscated %d variables\n" % stats.variables_obfuscated

    return err

func _exportPreset(platform: String) -> int:
    # Use existing Godot export logic from current release-manager.gd
    # Lines 286-327
    pass

func _generateChecksum(platform: String) -> String:
    # Use FileHelper.CreateChecksum()
    pass

func _onOpenPlatformFolder(platform: String):
    var exportPath = _selectedProjectItem.GetExportPath()
    FileHelper.OpenDirectoryInExplorer(exportPath)

func _parseExcludeList(text: String) -> Array:
    var result = []
    var items = text.split("\n")
    for item in items:
        var cleaned = item.strip_edges()
        if cleaned != "" and not cleaned.begins_with("#"):
            result.append(cleaned)
    return result

func save():
    _selectedProjectItem.SetExportType(_exportTypeOption.text)
    _selectedProjectItem.SetPackageType(_packageTypeOption.text)
    _selectedProjectItem.SetAutoGenerateExportFileNamesChecked(_autoGenerateNamesCheck.button_pressed)
    _selectedProjectItem.SetGenerateChecksumChecked(_generateChecksumCheck.button_pressed)
    _selectedProjectItem.SaveProjectItem()

func validate() -> bool:
    # Check if export_presets.cfg exists
    var projectPath = _selectedProjectItem.GetFormattedProjectPath()
    var presetsPath = projectPath + "/export_presets.cfg"
    return FileAccess.file_exists(presetsPath)
```

## Integration with Existing Code

### Reuse from Current release-manager.gd
- Export preset logic (lines 286-327) → `_exportPreset()`
- Temp directory prep (lines 492-527) → `_prepTempDirectory()`
- Obfuscation logic (lines 585-604) → `_obfuscateSource()`
- Checksum generation (lines 224-245) → `_generateChecksum()`

### Export Flow
Current flow in ExportProjectThread() (lines 540-570):
1. ExportSourceToTempWorkingDirectory()
2. ObfuscateSource()
3. For each platform: ExportPreset()
4. Generate checksums
5. Copy to export path
6. Zip (if enabled)

Adapt to per-platform export:
- Prep/copy/obfuscate once (first platform export)
- Reuse temp source for subsequent platforms
- Clean temp on "Export All" start, not per platform

## Files to Modify
- Create `scenes/release-manager/pages/page4-build.tscn`
- Create `scenes/release-manager/pages/page4-build.gd`
- Update `scenes/project-item/project-item.gd` - Add GetAutoGenerateExportFileNamesChecked(), GetGenerateChecksumChecked()
- Update `scenes/release-manager/release-manager.gd` - Wire up Page 4

## UI Considerations

### Platform Table Styling
- Use GridContainer or Table layout
- Header row bold
- Status column color-coded (green/red/yellow)
- Buttons uniform size

### Export Progress
- Disable buttons during export
- Show spinner/progress indicator
- Auto-scroll output log to bottom

### Error Handling
- If one platform fails, continue with others
- Show ✗ Failed status in table
- Detailed error in output log
- Allow retry via individual Export button

## Acceptance Criteria
- [ ] Page 4 displays export options (type, package, checksum)
- [ ] Export preview shows generated filenames
- [ ] Export preview updates when options change
- [ ] Platforms table shows only selected platforms from Page 2
- [ ] Each platform row has Export and Open Folder buttons
- [ ] Export All button exports all selected platforms
- [ ] Individual Export buttons export single platform
- [ ] Status column updates during export
- [ ] Obfuscation runs during first platform export
- [ ] Obfuscation stats display in output log
- [ ] Checksums generate when enabled
- [ ] Output log shows real-time progress
- [ ] Errors display clearly with ✗ Failed status
- [ ] Open Folder buttons work correctly
- [ ] Settings auto-save on change
- [ ] Can navigate Back without losing export results
- [ ] Next button enabled after successful export

## Testing Checklist
- [ ] Export single platform, verify works
- [ ] Export all platforms, verify all complete
- [ ] Enable obfuscation, verify runs during export
- [ ] Disable obfuscation, verify skipped
- [ ] Enable checksums, verify generated
- [ ] Test with Zip package type
- [ ] Test with No Zip package type
- [ ] Test auto-generated filenames
- [ ] Test manual filenames
- [ ] Trigger export failure, verify ✗ status
- [ ] Open folder buttons work correctly
- [ ] Navigate Back to Page 2, change platforms, return - verify table updates
- [ ] Navigate Back to Page 3, change obfuscation, return - verify applies
- [ ] Export all, then export individual platform again
