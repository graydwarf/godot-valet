# Obfuscated + Encrypted Build Pipeline

## Goal
Verify that an obfuscated + encrypted build of suganote runs correctly end-to-end.

## Pipeline Steps

### Step 1: Obfuscate
Run godot-valet's obfuscator CLI against suganote-main:
```bash
"C:/dad/apps/godot/godot-4.5-stable/Godot_v4.5-stable_win64.exe" --headless \
  --path "C:/dad/projects/godot/godot-4/applications/godot-valet" \
  --script res://scripts/obfuscate-cli.gd -- \
  --project-dir "C:/dad/projects/godot/godot-4/applications/suganote/suganote-main" \
  --output "C:/tmp/suganote-obfuscated" \
  --functions --variables --comments \
  --skip-dirs "tests,build"
```

### Step 2: Copy + Overlay
Copy entire suganote-main, then overlay obfuscated files on top:
```bash
cp -r "C:/dad/projects/godot/godot-4/applications/suganote/suganote-main" "C:/tmp/suganote-obfuscated-build"
cp -r "C:/tmp/suganote-obfuscated/"* "C:/tmp/suganote-obfuscated-build/"
```

### Step 3: Export
Export using the custom Godot editor with encryption key:
```bash
GODOT_SCRIPT_ENCRYPTION_KEY=$(cat ".../build/templates/encryption.key") \
  "C:/dad/projects/godot/godot-4/applications/suganote/suganote-main/build/templates/godot_custom_editor_windows_x86_64.exe" \
  --headless --path "C:/tmp/suganote-obfuscated-build" \
  --export-release "Windows Desktop"
```
- Custom Godot build at: `suganote-main/build/templates/godot_custom_editor_windows_x86_64.exe`
- Custom release/debug templates: `windows_release_x86_64.exe`, `windows_debug_x86_64.exe`
- Encryption key: `build/templates/encryption.key`
- Export preset: "Windows Desktop" in `export_presets.cfg`
- Output: `exports/v0.1.52/Suganote.exe` + `.pck` + SQLite DLLs

### Step 4: Run + Test
Launch the exported exe and manually verify it works:
```bash
"C:/tmp/suganote-obfuscated-build/exports/v0.1.52/Suganote.exe" --verbose 2>&1 | tee "C:/tmp/suganote-obfuscated-crash.log"
```

---

## Key Details
- **Custom encryption**: Suganote uses a custom-compiled Godot build with custom encryption (not stock Godot PCK encryption)
- **Suganote source**: `C:/dad/projects/godot/godot-4/applications/suganote/suganote-main/`
- **Temp dirs**: `C:/tmp/suganote-obfuscated/` (obfuscated output), `C:/tmp/suganote-obfuscated-build/` (full build copy)

---

## Current Status (2026-03-14)

### Completed This Session
1. **Fixed `test_named_enum_no_bare_keys`** (godot-valet, uncommitted) — Moved `IsBuiltInClass()` check in `ExtractEnumValuesWithIndices()` to only apply to anonymous enums. Named enums now correctly produce qualified keys like `Format.JSON` even when the value name matches a built-in class.
   - File: `scripts/obfuscator.gd` ~line 757
2. **Created `tests/run-tests-headless.gd`** (godot-valet, uncommitted) — SceneTree-based entry point for running unit tests without UI: `--script res://tests/run-tests-headless.gd`
3. **All 172 godot-valet unit tests passing**

### Current Problem
The exported build doesn't reflect suganote-main's latest changes (column paste above/below, new settings options). The pipeline runs successfully (obfuscate → copy → export → launch) but the resulting app appears to be missing recent work. Root cause not yet identified — possibly stale copy, wrong source, or caching issue.

### Earlier Issue (Fixed in suganote)
First attempt crashed due to `main.gd` preloading test files (`res://tests/test-runner/test-runner.gd`). `preload()` is parsed at compile time, so even though the code path was gated by `OS.has_feature("editor")`, it caused parse errors in exported builds. This was fixed in suganote commit `cdc1da8 feat: Exclude dev/test content from release builds`.

---

## Suganote-Side Requirements for Obfuscation
1. **Test preloads removed from main.gd** — Done (commit cdc1da8)
2. **Exclude tests/ from exports** — Needs verification
3. **Use `--skip-dirs tests,build`** when running obfuscator
4. **Use `--validate` flag** for automated error checking
