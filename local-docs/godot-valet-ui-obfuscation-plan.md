# Godot-Valet UI Obfuscation Updates (Uber-Phase 3)

> **Status**: Future work — depends on Uber-Phase 1 (CLI pipeline) and Uber-Phase 2 (GitHub Actions)
> **Last updated**: 2026-03-14

## Goal

Update godot-valet's Release Manager UI to support all new obfuscation features and add first-class support for custom Godot builds with encryption.

## Context

The obfuscation system has grown beyond the original 3 toggles (functions, variables, comments). The CLI (`obfuscate-cli.gd`) already supports the full feature set, but the UI (`export-page.gd`) only passes the original 3 flags. Additionally, encrypted builds currently require manual setup — the UI has no awareness of custom Godot builds or encryption keys.

## New UI Features Needed

### 1. New Obfuscation Toggles

**Current UI toggles** (in Build Config dialog):
- Obfuscate Functions (checkbox)
- Obfuscate Variables (checkbox)
- Remove Comments (checkbox)

**New toggles to add**:
- Inline Constants/Enums (checkbox, default off)
- Skip Directories (text field, comma-separated, default: "tests,build")
- Skip Addons Directory (checkbox, default on)

**Location**: `scenes/release-manager/pages/export-page/dialogs/build-config-dialog/`

### 2. Exclude List Enhancements

**Current exclude lists** (in Exclude List dialog):
- Function Excludes (text area)
- Variable Excludes (text area)

**New exclude lists to add**:
- Constant Excludes (text area)
- External Plugin Classes (text area) — classes from addons that shouldn't be obfuscated

**Location**: `scenes/release-manager/pages/export-page/dialogs/exclude-list-dialog/`

### 3. Custom Godot Build Support

**New feature**: Allow projects to specify a custom Godot executable for export, separate from the "run" Godot version.

**Possible approaches**:
- **Per-project setting**: Add "Custom Export Godot" path field to project item settings
- **Per-platform setting**: Add "Export Godot Override" to each platform's build config
- **Auto-detect**: If `build/templates/` exists in the project dir, offer to use the custom editor found there

**UI location**: Build Config dialog or a new "Advanced Export" section

### 4. Encryption Key Management

**New feature**: Store and manage encryption keys per project for encrypted PCK exports.

**Discussion points**:
- Where to store the key reference? (project item config, separate secure storage)
- Should godot-valet store the key itself or just a path to it?
- How to handle the `GODOT_SCRIPT_ENCRYPTION_KEY` env var at export time?
- Security: keys should never be committed to git or shown in plain text in the UI

**Possible approach**:
- Project item gets an "Encryption Key File" path field
- At export time, godot-valet reads the key and sets the env var
- Key path is stored in `user://project-items/<id>.cfg` (local to machine, not in repo)

### 5. Custom Header Trick

**Discussion**: Godot supports a "custom header" for encrypted builds where you compile a custom Godot build with a modified encryption header. This makes it harder to extract the encryption key even if someone has the binary.

**How it works**:
1. Modify `core/io/file_access_encrypted.h` in Godot source to change magic bytes
2. Compile custom editor + export templates with this change
3. Standard Godot can't open the encrypted files — only your custom build can

**What godot-valet could do**:
- Provide a UI to set/generate a custom header value
- Store it alongside the encryption key
- When user compiles their custom Godot build, embed this header
- Validate that the custom build matches the expected header before export

**This is a discussion item** — it requires the user to compile Godot from source, which is outside godot-valet's scope. But godot-valet could help manage the configuration.

## Integration with CLI

The UI should produce the same results as the CLI. Two approaches:

### Option A: UI calls the CLI internally
- Build Config dialog settings → generate CLI flags
- Export runs `obfuscate-cli.gd` as a subprocess
- Pros: Single code path, guaranteed consistency
- Cons: Requires running a second Godot instance for obfuscation

### Option B: UI calls ObfuscateHelper directly (current approach, extended)
- Pass new options to `ObfuscateHelper.ObfuscateScripts()`
- Add export with custom Godot support to `export-page.gd`
- Pros: Single process, faster, existing pattern
- Cons: Two code paths to maintain (CLI + UI)

**Recommendation**: Option B for obfuscation (performance), but add custom Godot + encryption support following the CLI's pattern for the export step.

## Files to Modify

### Build Config Dialog
- `scenes/release-manager/pages/export-page/dialogs/build-config-dialog/build-config-dialog.gd`
- `scenes/release-manager/pages/export-page/dialogs/build-config-dialog/build-config-dialog.tscn`

### Exclude List Dialog
- `scenes/release-manager/pages/export-page/dialogs/exclude-list-dialog/exclude-list-dialog.gd`
- `scenes/release-manager/pages/export-page/dialogs/exclude-list-dialog/exclude-list-dialog.tscn`

### Export Page
- `scenes/release-manager/pages/export-page/export-page.gd` — pass new flags, handle custom Godot + encryption

### Project Item
- `scenes/project-item/project-item.gd` — store custom export Godot path + encryption key path

### Help Dialog
- `scenes/release-manager/pages/export-page/dialogs/obfuscation-help-dialog/` — update docs

## Open Questions

1. Should constant inlining be on or off by default in the UI?
2. Should the custom Godot path be per-project or per-platform?
3. How much of the encryption workflow should godot-valet own vs. leave to the user?
4. Is the custom header trick worth building UI for, or just documenting?
5. Should there be a "CLI command preview" button that shows the equivalent CLI command for the current UI settings?
