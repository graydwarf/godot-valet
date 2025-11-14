# Release Manager Wizard - Phase 4: Publishing Page

## Overview
Implement Page 5: Publishing to itch.io via Butler. This optional final step allows users to upload their exported builds directly to itch.io.

## Goals
- Create Page 5 UI with itch.io settings
- Display Butler command preview
- Implement Butler upload execution
- Add per-platform publish controls
- Show publish status and progress
- Handle Butler not installed scenario
- Replace Next button with Finish button

## Features

### Page 5: Publish

**Purpose**: Upload exported builds to itch.io via Butler

**Layout**:
```
┌─────────────────────────────────────────────────────────────────┐
│ Publish to Itch.io                                              │
│                                                                 │
│ Itch.io Settings:                                               │
│ Profile Name:  [alexdev                              ]         │
│ Project Name:  [kilanote                             ]         │
│                                                                 │
│ Butler Status: ✓ Installed (v15.21.0)                          │
│                                                                 │
│ Butler Commands Preview:                                        │
│ ┌─────────────────────────────────────────────────────────┐   │
│ │ butler push export/kilanote-v1.2.3-windows.zip \        │   │
│ │   alexdev/kilanote:windows --userversion 1.2.3          │   │
│ │ butler push export/kilanote-v1.2.3-linux.zip \          │   │
│ │   alexdev/kilanote:linux --userversion 1.2.3            │   │
│ │ butler push export/kilanote-v1.2.3-web.zip \            │   │
│ │   alexdev/kilanote:web --userversion 1.2.3              │   │
│ └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│ ────────────────────────────────────────────────────────────── │
│                                                                 │
│ Platforms:                                                      │
│ ┌─────────────────────────────────────────────────────────┐   │
│ │ Platform       Status          Actions                  │   │
│ │ ──────────────────────────────────────────────────────  │   │
│ │ Windows        Ready           [Publish]                │   │
│ │ Linux          Ready           [Publish]                │   │
│ │ Web            Ready           [Publish]                │   │
│ └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│ [Publish All]                                                   │
│                                                                 │
│ Output:                                                         │
│ ┌─────────────────────────────────────────────────────────┐   │
│ │ Publishing Windows to itch.io...                        │   │
│ │   • Pushing 45.2 MB (13 files)                          │   │
│ │   • Build uploaded successfully                         │   │
│ │ ✓ Windows published                                      │   │
│ │ Publishing Linux to itch.io...                          │   │
│ │   • Pushing 42.8 MB (11 files)                          │   │
│ │   • Build uploaded successfully                         │   │
│ │ ✓ Linux published                                        │   │
│ │ ✓ All platforms published successfully                   │   │
│ └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│ [Exit]                                     [← Back] [Finish]   │
└─────────────────────────────────────────────────────────────────┘
```

**Itch.io Settings Section**:
- Profile Name: LineEdit (e.g., "alexdev")
- Project Name: LineEdit (e.g., "kilanote")
- Both fields auto-save on change

**Butler Status Indicator**:
- ✓ Installed (vX.Y.Z) - Butler detected and version shown (green)
- ✗ Not Installed - Butler not found (red)
- ? Unknown - Haven't checked yet (gray)
- [Test Butler] button - Manually verify Butler installation

**Butler Commands Preview**:
- Read-only TextEdit showing exact commands that will run
- Updates dynamically when settings change
- Shows only platforms that were exported on Page 4
- Includes --userversion flag with project version

**Platforms Table**:
- Shows only platforms that were successfully exported on Page 4
- Source platform not shown (doesn't publish to itch.io)
- Columns:
  - **Platform**: Windows, Linux, Web
  - **Status**: Ready, Publishing..., ✓ Published, ✗ Failed
  - **Actions**: [Publish]
- [Publish] button: Publishes that specific platform only

**Publish All Button**:
- Large primary button
- Publishes all exported platforms
- Updates status column as each publishes
- Shows progress in output log

**Output Log**:
- Scrollable TextEdit (read-only)
- Shows real-time Butler output
- Displays upload progress
- Shows success/failure per platform

**Status Values**:
- **Ready**: Not published yet
- **Publishing...**: Currently uploading (spinner)
- **✓ Published**: Upload successful (green)
- **✗ Failed**: Upload failed (red)

**Finish Button**:
- Replaces "Next" button on this page
- Returns to Project Manager
- Same as Exit button, just clearer intent

**Validation**:
- Warn if itch.io settings empty
- Disable Publish buttons if Butler not installed
- Disable Publish buttons if no builds exported on Page 4

**Auto-Save**:
- Itch.io settings save immediately on change

## Butler Detection & Testing

### Butler Detection
```gdscript
func _detectButler() -> Dictionary:
    var result = {
        "installed": false,
        "version": "",
        "path": ""
    }

    # Try running butler --version
    var output = []
    var err = OS.execute("butler", ["--version"], output, true, false)

    if err == OK and output.size() > 0:
        result.installed = true
        result.version = output[0].strip_edges()
    else:
        # Butler not in PATH, try common locations
        var commonPaths = [
            "C:/Users/" + OS.get_environment("USERNAME") + "/.config/itch/bin/butler.exe",
            OS.get_environment("USERPROFILE") + "/.config/itch/bin/butler.exe"
        ]

        for path in commonPaths:
            if FileAccess.file_exists(path):
                result.installed = true
                result.path = path
                # Get version
                err = OS.execute(path, ["--version"], output, true, false)
                if err == OK and output.size() > 0:
                    result.version = output[0].strip_edges()
                break

    return result
```

### Butler Not Installed UI
If Butler not detected:
```
Butler Status: ✗ Not Installed

Butler is required to publish to itch.io.

[Download Butler] - Opens https://itch.io/docs/butler/
[Test Butler] - Re-check if Butler installed

Note: You can skip publishing by clicking Finish below.
```

## Technical Implementation

### page5-publish.gd

```gdscript
extends WizardPageBase

@onready var _profileNameLineEdit = %ProfileNameLineEdit
@onready var _projectNameLineEdit = %ProjectNameLineEdit
@onready var _butlerStatusLabel = %ButlerStatusLabel
@onready var _testButlerButton = %TestButlerButton
@onready var _commandsPreviewText = %CommandsPreviewText
@onready var _platformsTable = %PlatformsTable
@onready var _publishAllButton = %PublishAllButton
@onready var _outputLog = %OutputLog

var _butlerInfo: Dictionary = {}
var _platformRows: Dictionary = {}

func _ready():
    super._ready()
    _detectButlerInstallation()

func _loadPageData():
    _profileNameLineEdit.text = _selectedProjectItem.GetItchProfileName()
    _projectNameLineEdit.text = _selectedProjectItem.GetItchProjectName()

    _buildPlatformsTable()
    _updateCommandsPreview()

func _detectButlerInstallation():
    _butlerInfo = _detectButler()

    if _butlerInfo.installed:
        _butlerStatusLabel.text = "✓ Installed (" + _butlerInfo.version + ")"
        _butlerStatusLabel.modulate = Color.GREEN
        _publishAllButton.disabled = false
    else:
        _butlerStatusLabel.text = "✗ Not Installed"
        _butlerStatusLabel.modulate = Color.RED
        _publishAllButton.disabled = true
        _showButlerNotInstalledHelp()

func _showButlerNotInstalledHelp():
    _outputLog.text = "Butler is required to publish to itch.io.\n\n"
    _outputLog.text += "Download Butler: https://itch.io/docs/butler/\n"
    _outputLog.text += "Or click Finish below to skip publishing.\n"

func _detectButler() -> Dictionary:
    # Implementation as shown above
    pass

func _buildPlatformsTable():
    # Clear existing rows
    for child in _platformsTable.get_children():
        child.queue_free()
    _platformRows.clear()

    # Add header
    var header = _createTableRow("Platform", "Status", "Actions", true)
    _platformsTable.add_child(header)

    # Add rows for exported platforms (excluding Source)
    var exportedPlatforms = _getExportedPlatforms()
    for platform in exportedPlatforms:
        if platform != "Source":  # Don't publish source to itch.io
            var row = _createPlatformRow(platform)
            _platformsTable.add_child(row)
            _platformRows[platform] = row

func _getExportedPlatforms() -> Array:
    # Check which platforms were successfully exported on Page 4
    # For now, just return selected platforms
    # TODO: Check actual export status from Page 4
    var platforms = []
    if _selectedProjectItem.GetWindowsChecked():
        platforms.append("Windows")
    if _selectedProjectItem.GetLinuxChecked():
        platforms.append("Linux")
    if _selectedProjectItem.GetWebChecked():
        platforms.append("Web")
    return platforms

func _createPlatformRow(platform: String) -> HBoxContainer:
    var row = HBoxContainer.new()

    # Platform name
    var nameLabel = Label.new()
    nameLabel.text = platform
    nameLabel.custom_minimum_size.x = 150
    row.add_child(nameLabel)

    # Status
    var statusLabel = Label.new()
    statusLabel.text = "Ready"
    statusLabel.custom_minimum_size.x = 150
    statusLabel.name = "StatusLabel"
    row.add_child(statusLabel)

    # Publish button
    var publishBtn = Button.new()
    publishBtn.text = "Publish"
    publishBtn.disabled = !_butlerInfo.installed
    publishBtn.pressed.connect(_onPublishPlatform.bind(platform))
    row.add_child(publishBtn)

    return row

func _updateCommandsPreview():
    var preview = ""
    var profileName = _profileNameLineEdit.text
    var projectName = _projectNameLineEdit.text
    var version = _selectedProjectItem.GetProjectVersion()
    var exportPath = _selectedProjectItem.GetExportPath()
    var exportFilename = _selectedProjectItem.GetExportFileName()

    var platforms = _getExportedPlatforms()
    for platform in platforms:
        if platform == "Source":
            continue

        var filename = _getExportedFilename(platform)
        var channel = platform.to_lower()

        preview += "butler push " + exportPath + "/" + filename + " \\\n"
        preview += "  " + profileName + "/" + projectName + ":" + channel
        preview += " --userversion " + version.trim_prefix("v") + "\n"

    _commandsPreviewText.text = preview

func _getExportedFilename(platform: String) -> String:
    var baseFilename = _selectedProjectItem.GetExportFileName()
    var version = _selectedProjectItem.GetProjectVersion()
    var autoGenerate = _selectedProjectItem.GetAutoGenerateExportFileNamesChecked()

    var filename = baseFilename
    if autoGenerate:
        filename += "-" + version + "-" + platform.to_lower()

    if _selectedProjectItem.GetPackageType() == "Zip":
        filename += ".zip"

    return filename

func _onPublishAllPressed():
    _outputLog.text = ""
    var platforms = _getExportedPlatforms()

    for platform in platforms:
        if platform != "Source":
            await _publishPlatform(platform)

    _outputLog.text += "✓ All platforms published successfully\n"

func _onPublishPlatform(platform: String):
    _outputLog.text = ""
    await _publishPlatform(platform)

func _publishPlatform(platform: String):
    _updatePlatformStatus(platform, "Publishing...")

    var profileName = _profileNameLineEdit.text
    var projectName = _projectNameLineEdit.text
    var version = _selectedProjectItem.GetProjectVersion()
    var exportPath = _selectedProjectItem.GetExportPath()
    var filename = _getExportedFilename(platform)
    var channel = platform.to_lower()

    _outputLog.text += "Publishing " + platform + " to itch.io...\n"

    # Build butler command
    var butlerPath = "butler" if _butlerInfo.path == "" else _butlerInfo.path
    var args = [
        "push",
        exportPath + "/" + filename,
        profileName + "/" + projectName + ":" + channel,
        "--userversion", version.trim_prefix("v")
    ]

    # Execute butler
    var output = []
    var err = OS.execute(butlerPath, args, output, true, false)

    if err == OK:
        _updatePlatformStatus(platform, "✓ Published")
        _outputLog.text += "✓ " + platform + " published\n"
        for line in output:
            _outputLog.text += "  " + line + "\n"
    else:
        _updatePlatformStatus(platform, "✗ Failed")
        _outputLog.text += "✗ Failed to publish " + platform + "\n"
        for line in output:
            _outputLog.text += "  " + line + "\n"

func _updatePlatformStatus(platform: String, status: String):
    if _platformRows.has(platform):
        var row = _platformRows[platform]
        var statusLabel = row.get_node("StatusLabel")
        statusLabel.text = status

        match status:
            "✓ Published":
                statusLabel.modulate = Color.GREEN
            "✗ Failed":
                statusLabel.modulate = Color.RED
            "Publishing...":
                statusLabel.modulate = Color.YELLOW
            _:
                statusLabel.modulate = Color.WHITE

func _onTestButlerPressed():
    _detectButlerInstallation()

func _onProfileNameChanged(new_text: String):
    _updateCommandsPreview()
    save()

func _onProjectNameChanged(new_text: String):
    _updateCommandsPreview()
    save()

func save():
    _selectedProjectItem.SetItchProfileName(_profileNameLineEdit.text)
    _selectedProjectItem.SetItchProjectName(_projectNameLineEdit.text)
    _selectedProjectItem.SaveProjectItem()

func validate() -> bool:
    # Always valid - publishing is optional
    return true
```

## Integration with Existing Code

### Reuse from Current release-manager.gd
- Butler execution logic (lines 751-804) → `_publishPlatform()`
- Butler command generation (lines 403-425) → `_updateCommandsPreview()`

### Butler Command Format
Current format:
```bash
butler push <file> <user>/<project>:<channel> --userversion <version>
```

Example:
```bash
butler push export/kilanote-v1.2.3-windows.zip alexdev/kilanote:windows --userversion 1.2.3
```

## Files to Modify
- Create `scenes/release-manager/pages/page5-publish.tscn`
- Create `scenes/release-manager/pages/page5-publish.gd`
- Update `scenes/release-manager/release-manager.gd` - Wire up Page 5, change Next → Finish

## UI Considerations

### Butler Not Installed
- Show clear instructions
- Provide download link button
- Allow skipping via Finish
- Disable Publish buttons

### Empty Itch.io Settings
- Allow empty (publishing is optional)
- Show placeholder text in fields
- Update commands preview with placeholders

### Real-time Butler Output
- Butler provides progress output
- Parse and display upload progress
- Show file sizes, upload speed

### Error Handling
- Invalid credentials
- Network errors
- File not found
- Channel doesn't exist
- Show detailed error in output log

## Acceptance Criteria
- [ ] Page 5 displays itch.io settings fields
- [ ] Butler status shows installed/not installed
- [ ] Butler version displayed when installed
- [ ] Commands preview shows correct Butler commands
- [ ] Commands preview updates when settings change
- [ ] Platforms table shows only exported platforms
- [ ] Source platform not shown in table
- [ ] Publish All button publishes all platforms
- [ ] Individual Publish buttons work
- [ ] Butler output displayed in real-time
- [ ] Status column updates during publish
- [ ] Publish buttons disabled when Butler not installed
- [ ] Test Butler button re-checks installation
- [ ] Settings auto-save on change
- [ ] Next button replaced with Finish button
- [ ] Finish button returns to Project Manager
- [ ] Can skip publishing by clicking Finish

## Testing Checklist
- [ ] Test with Butler installed, verify detection
- [ ] Test with Butler not installed, verify warning
- [ ] Test Butler button manually
- [ ] Publish single platform, verify success
- [ ] Publish all platforms, verify all succeed
- [ ] Test with invalid credentials, verify error
- [ ] Test with network offline, verify error
- [ ] Change itch.io settings, verify commands update
- [ ] Navigate Back to Page 4, change exports, return - verify table updates
- [ ] Test Finish button returns to Project Manager
- [ ] Verify settings persist after Finish
- [ ] Test with empty itch.io settings, verify still works
