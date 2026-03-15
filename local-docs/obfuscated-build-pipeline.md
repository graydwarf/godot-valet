# Obfuscated + Encrypted Build Pipeline

## Goal
Full CLI pipeline: obfuscate → copy+overlay → export with custom Godot + encryption → collect artifacts.

## Single Command (Uber-Phase 1 — Complete)

### Test Build (debug — uses debug DB)

```bash
"C:/dad/apps/godot/godot-4.5-stable/Godot_v4.5-stable_win64.exe" --headless \
  --path "C:/dad/projects/godot/godot-4/applications/godot-valet" \
  --script res://scripts/obfuscate-cli.gd -- \
  --project-dir "C:/dad/projects/godot/godot-4/applications/suganote/suganote-middle-dev" \
  --output "C:/tmp/suganote-obfuscated" \
  --functions --variables --comments \
  --skip-dirs "tests,build" \
  --export "Windows Desktop" \
  --godot-path "C:/dad/projects/godot/godot-4/applications/suganote/suganote-main/build/templates/godot_custom_editor_windows_x86_64.exe" \
  --encryption-key "C:/dad/projects/godot/godot-4/applications/suganote/suganote-main/build/templates/encryption.key" \
  --export-output "C:/tmp/suganote-export/Suganote.exe" \
  --debug
```

### Release Build (production — uses release DB)

```bash
"C:/dad/apps/godot/godot-4.5-stable/Godot_v4.5-stable_win64.exe" --headless \
  --path "C:/dad/projects/godot/godot-4/applications/godot-valet" \
  --script res://scripts/obfuscate-cli.gd -- \
  --project-dir "C:/dad/projects/godot/godot-4/applications/suganote/suganote-main" \
  --output "C:/tmp/suganote-obfuscated" \
  --functions --variables --comments \
  --skip-dirs "tests,build" \
  --export "Windows Desktop" \
  --godot-path "C:/dad/projects/godot/godot-4/applications/suganote/suganote-main/build/templates/godot_custom_editor_windows_x86_64.exe" \
  --encryption-key "C:/dad/projects/godot/godot-4/applications/suganote/suganote-main/build/templates/encryption.key" \
  --export-output "C:/tmp/suganote-export/Suganote.exe"
```

The pipeline handles everything: obfuscation, project copy, file overlay, encryption key loading, Godot export, artifact collection (exe + pck + DLLs), and build dir cleanup.

### DB Isolation Strategy

Suganote's `WorkspaceManager` auto-selects debug vs release DB based on build type:
- **Debug export** (`--debug` / `--export-debug`): `OS.is_debug_build()` = true → `user://debug_workspaces/`
- **Release export** (default / `--export-release`): `OS.is_debug_build()` = false → `user://workspaces/`

The exported build runs from `C:/tmp/`, so worktree detection returns empty — it uses the default (no worktree suffix) debug or release workspace directory. This is safe because the debug workspaces directory is completely separate from release.

**Build templates** (`build/templates/`) are gitignored and only exist in `suganote-main`. Both test and release builds reference main's templates — they're the same compiled Godot binaries regardless of source worktree.

---

## Key Details
- **Custom encryption**: Suganote uses a custom-compiled Godot build with custom encryption (not stock Godot)
- **Test source (middle-dev)**: `C:/dad/projects/godot/godot-4/applications/suganote/suganote-middle-dev/`
- **Release source (main)**: `C:/dad/projects/godot/godot-4/applications/suganote/suganote-main/`
- **Custom Godot editor**: `suganote-main/build/templates/godot_custom_editor_windows_x86_64.exe`
- **Export templates**: `windows_release_x86_64.exe`, `windows_debug_x86_64.exe`
- **Encryption key**: `suganote-main/build/templates/encryption.key`
- **Export preset**: "Windows Desktop" in `export_presets.cfg`
- **Output artifacts**: exe + pck + SQLite DLL (all copied by pipeline)
- **Build templates location**: Only in `suganote-main/build/templates/` (gitignored). All worktrees reference main's templates.

---

## Current Status (2026-03-14, end of session)

### Working — Full E2E Verified
- **Full CLI pipeline** — single command obfuscates + exports + collects artifacts (commit `104225a`)
- **Functions + comments + variables obfuscation** — all working in exported build
- **Encrypted export** — PCK encrypted with custom key, runs on custom Godot build
- **Debug DB isolation** — `--debug` flag routes to `user://debug_workspaces/` (verified in logs)
- **Middle-dev worktree as test source** — Pipeline builds from middle-dev, templates from main
- **Event sync** — fully working (push/pull events verified)
- **Content loading, drag & drop, board switching** — all working in obfuscated build
- **Zero script errors** in exported debug build

### Obfuscation Coverage (measured 2026-03-14)
| Dimension | Coverage |
|-----------|----------|
| Functions | 88% (3,052/3,471 — 12% are correctly-excluded built-ins) |
| Variables | 72% (979/1,366 — rest are excluded built-ins/cross-file props) |
| Comments | 100% stripped |
| Scene signals | 100% (all method refs obfuscated) |
| File coverage | 100% (177 .gd, 42 .tscn) |

### Session 2026-03-14 Fixes (7 total)
1. **DB isolation** — Use `--debug` flag for test builds → `OS.is_debug_build()` true → debug workspace
2. **NUL file on Windows** — Reserved device name in middle-dev root broke xcopy silently. Deleted via Node.js
3. **SQLite GDExtension methods** — `query`, `query_with_bindings`, `open_db`, `close_db` etc. added to built-in list. These aren't visible in ClassDB when obfuscator runs in godot-valet's context (commit `44d21cc`)
4. **Comment stripping triple-quote bug** — `"""` toggled in_string 3x, leaving parser in wrong state for all subsequent lines. Rewrote as character-level scanner with explicit triple-quote detection. 100% strip rate (commit `8f73701`)
5. **.tscn property obfuscation** — @export vars now renamed in scene files (commit `747f8fb`)
6. **Comment escape sequences** — `\"` before `#` no longer breaks comment detection (commit `747f8fb`)
7. **`script` + `tween_property` built-in handling** — added to exclusion/preservation lists (commit `747f8fb`)

---

## Uber-Phase Roadmap

| Phase | Status | Description |
|-------|--------|-------------|
| **Uber-Phase 1** | **COMPLETE** | CLI full pipeline (obfuscate → export) |
| **Uber-Phase 2** | Next | GitHub Actions workflow using the CLI |
| **Uber-Phase 3** | Later | UI updates — see `godot-valet-ui-obfuscation-plan.md` |

---

## Session 2026-03-14: Variable Obfuscation + .tscn Properties

### What Was Done

#### Fix 1: .tscn Property Obfuscation (GENERAL — all projects)
- **Problem**: When `--variables` enabled, @export vars were renamed in .gd files but .tscn scene files still referenced original property names. Godot silently ignores unrecognized properties → vars default to Nil → animations/code crash with `Type mismatch`.
- **Root cause**: `ObfuscateSceneFiles()` only handled `[connection]` lines (signal methods). Property assignment lines (`key = value`) in `[node]` sections were not processed.
- **Fix**: Extended `ObfuscateSceneFiles()` to also rename property assignments. For each `key = value` line, if `key` is in the obfuscation map with `kind == "variable"`, rename it. Path-based properties (`/` in key, e.g. `theme_override_*`, `metadata/*`) are skipped.
- **Also**: Removed the `@export` variable skip logic. Previously, `@export var` declarations were excluded from obfuscation (lines 599-602). This prevented the mismatch but meant @export vars were never obfuscated. Now they are obfuscated in both .gd and .tscn.
- **Also**: Gate condition changed — scene processing activates when `_isObfuscatingFunctions OR _isObfuscatingVariables` (was functions-only).
- **Added**: `ObfuscateSceneContent()` static helper for in-memory testing (no file I/O).
- **Tests**: 9 new tests (181 total). Covers: property rename, built-in preservation, theme overrides, metadata, mixed properties, combined property+connection, complex value types, disabled-mode check, section headers.

#### Fix 2: Comment Stripping Escape Sequence Bug (GENERAL — all projects)
- **Problem**: `RemoveCommentsFromCode()` didn't handle `\"` escape sequences. In strings like `"Add the #1 best..."`, the `\"` before `#` toggled the in-string state off, causing `#1` to be treated as a comment start. Everything after `#` on that line was stripped.
- **Affected**: Any `.gd` file with `\"` followed by `#` on the same line inside a string.
- **Fix**: Added escape character handling — when `\` is encountered inside a string, skip the next character.
- **Found in**: `mcp-wizard.gd:1053` in suganote, but this is a general GDScript pattern.

#### Fix 3: `script` Property Missing from Built-in Exclusion (GENERAL — all projects)
- **Problem**: `script` is a built-in Godot property on `Object` (assigns scripts to nodes via `script = ExtResource(...)`). It was NOT in the ClassDB runtime property set (Godot treats it specially) and NOT in the manual `_godotBuiltInMethods` list. When a user's code has `var script = "..."` anywhere, `script` enters the global symbol map, and the .tscn property replacement renames `script = ExtResource(...)` in every scene file → nodes have no scripts → app is frozen.
- **Fix**: Added `"script"` to `_godotBuiltInMethods` manual list.
- **Impact**: Without this fix, ANY project using variable obfuscation would break if any file contains `var script`.

#### Fix 4: `tween_property` String Argument Preservation (GENERAL — all projects)
- **Problem**: `tween_property(self, "property_name", target, duration)` references a property by string. When variable obfuscation renames the `var` declaration but the string stays as the original name, the tween tries to animate a non-existent property → Nil → `Type mismatch` crash.
- **Fix**: Added `tween_property` and `tween_method` to `PreserveSpecialStrings()` regex. These strings are now exposed to the obfuscator (like `call("method")` already was), so the property name inside the string gets obfuscated to match the renamed declaration.
- **Regex**: `(?:tween_property|tween_method)\s*\([^,]*,\s*"([^"\\]*)"` — matches the 2nd argument (the property/method name string).

#### Fix 5: Reverted `get()`/`set()` from PreserveSpecialStrings (GENERAL — all projects)
- **Problem**: Initially added `[gs]et` to PreserveSpecialStrings to handle `Object.set("property")` / `Object.get("property")`. But `get()` is also `Dictionary.get("key")` — far more common. PreserveSpecialStrings **exposes** string content to the obfuscator (that's its purpose). So `result.get("card_node")` was having `"card_node"` obfuscated, breaking dictionary lookups.
- **Fix**: Reverted. `get()`/`set()` string args are NOT special-cased. Dictionary keys that happen to match variable names are protected by normal `PreserveStringLiterals()` (which keeps them as-is). For `Object.set("prop")` / `Object.get("prop")` patterns, users must add those property names to the variable exclude list.

### Generality Assessment

All 5 fixes are **general-purpose** — they affect any Godot project using the obfuscator, not just Suganote. The fixes were discovered via Suganote E2E testing, but the root causes are in the obfuscator's core logic:

| Fix | Suganote-specific? | Why it's general |
|-----|--------------------|------------------|
| .tscn property obfuscation | No | Any project with @export vars in scene files |
| Comment escape sequences | No | Any string with `\"` before `#` on same line |
| `script` built-in | No | Universal Godot property, any project with `var script` |
| tween_property strings | No | Any project using `tween_property` with variable names |
| get/set revert | No | Any project using Dictionary.get() with variable-name keys |

### Remaining Issues to Investigate

#### 1. Content not loading in obfuscated build
- **Symptom**: Board loads (board switching works, titles visible) but card text/content doesn't render.
- **Not yet investigated**. Could be:
  - A string-based property access pattern not yet handled
  - A variable name used as a dictionary key in content loading code
  - An @export var on the card scene that affects text rendering
- **Action**: Investigate `create_card()` and card content rendering flow in obfuscated output.

#### 2. Drag drops at wrong position (top-left corner)
- **Symptom**: Dragging new nodes from toolbar shows the drag preview correctly, but dropping places the card near the navbar (top-left).
- **Not yet investigated**. Could be:
  - A position-related variable being obfuscated that shouldn't be
  - A coordinate conversion function (`screen_to_world`, etc.) not working correctly
- **Action**: Compare `StartDragProgrammatically()` and drop handling between original and obfuscated.

#### 3. ~~⚠️ DB safety: Must use debug workspace for testing~~ — RESOLVED (2026-03-14)
- **Fix**: Use `--debug` flag in the pipeline command. This exports with `--export-debug`, so `OS.is_debug_build()` returns true in the exported app, and WorkspaceManager routes to `user://debug_workspaces/` (separate from release).
- **Verified**: Exported build logs `[WorkspaceManager] DEBUG MODE - Worktree: unknown - Using: user://debug_workspaces/`
- **Test source**: Use `suganote-middle-dev` worktree (`--project-dir`) to avoid touching main.
- **Build templates**: Still reference `suganote-main/build/templates/` (gitignored, only exist there).
- **Gotcha found**: A `NUL` file (Windows reserved device name) existed in middle-dev root, causing xcopy to silently fail. Deleted via Node.js `fs.unlinkSync()`. If xcopy ever fails silently again, check for reserved Windows filenames (`NUL`, `CON`, `PRN`, `AUX`, `COM1`-`COM9`, `LPT1`-`LPT9`).

#### 4. Architectural concern: string-based property access
- **Pattern**: GDScript allows accessing properties by string via `tween_property()`, `set()`, `get()`, `get_node()`, etc. The obfuscator can't automatically detect all of these.
- **Currently handled**:
  - `call("method")`, `call_deferred("method")`, `has_method("method")` — string exposed to obfuscator, method name gets renamed
  - `tween_property(obj, "property")`, `tween_method(obj, "method")` — same treatment
- **NOT handled** (users must add to exclude list):
  - `set("property", value)` / `get("property")` — too ambiguous (Dictionary.get vs Object.get)
  - `get_node("path")` — node paths, not obfuscated
  - `has("key")` — dictionary method
  - Any custom string-based reflection pattern
- **Mitigation**: Document that string-based property access requires manual exclude list entries. Consider adding a `--warn-string-refs` flag that scans for potential issues.

### Files Modified This Session

| File | Changes |
|------|---------|
| `scripts/obfuscator.gd` | Removed `_exportVariableNames` + skip logic; added property replacement to `ObfuscateSceneFiles()`; added `ObfuscateSceneContent()` helper; fixed comment escape sequences; added `script` to built-in list; added `tween_property`/`tween_method` to PreserveSpecialStrings; updated gate condition |
| `tests/unit/test-obfuscator-scenes.gd` | 9 new property obfuscation tests |
| `CLAUDE.md` | Updated test count (181), scene processing docs, bug fix list |
| `local-docs/obfuscator-bugfix-plan.md` | Updated @export limitation note |

---

## Suganote-Side Requirements for Obfuscation
1. **Test preloads removed from main.gd** — Done (commit cdc1da8)
2. **Exclude tests/ from exports** — Done via `--skip-dirs tests,build`
3. **`--variables` flag now supported** — .tscn property obfuscation implemented (2026-03-14). Add any string-reflected @export vars to variable exclude list.
4. **Use debug workspace for E2E testing** — DONE. Use `--debug` flag → exports as debug build → WorkspaceManager auto-routes to `user://debug_workspaces/`. Test builds use `suganote-middle-dev` as source.

---

## Next Session Checklist

### Testing
- ✅ **Unit tests confirmed** — 192 tests passing (was 181)
- ✅ **Triple-quote comment stripping tests added** — 6 tests in `test-obfuscator.gd`
- ✅ **`tween_property`/`tween_method` tests added** — 5 tests in `test-obfuscator-strings.gd`

### Pipeline Improvements
- **GDExtension method discovery** — Currently SQLite methods are hardcoded in `_godotBuiltInMethods`. Consider scanning target project's `.gdextension` files or adding a `--builtin-methods` CLI flag for project-specific additions

### Next Major Milestones
- **Uber-Phase 2** — GitHub Actions workflow using the CLI
- **Uber-Phase 3** — UI updates for obfuscation settings (see `godot-valet-ui-obfuscation-plan.md`)

### Completed (this session)
- ~~Set up DB isolation~~ — `--debug` flag + middle-dev worktree
- ~~Content not loading~~ — working after .tscn property fixes
- ~~Drag position bug~~ — working after prior fixes
- ~~`query` function error~~ — SQLite GDExtension methods added to built-in list
- ~~Comment stripping triple-quote bug~~ — rewrote as character-level scanner
- ~~NUL file breaking xcopy~~ — deleted reserved filename from middle-dev
