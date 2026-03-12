# Obfuscator Bugfix Plan — Pre-Phase 3 Stabilization

## Context
After Phase 2 (constant/enum inlining, commit `9a4c7bf`), end-to-end testing of the obfuscator against suganote produced **158 parse/runtime errors**. These must be fixed before adding new obfuscation features.

**Test setup**: Obfuscate suganote with `--functions --variables --comments --constants`, overlay onto full project copy, launch in Godot.

**Test project**: suganote-middle-dev (middle used to avoid conflicts with active left-dev work)

**Obfuscated output**: `C:/tmp/suganote-middle-obfuscated/` (just .gd/.tscn), runnable copy at `C:/tmp/suganote-run-middle/`

---

## Progress Summary

| # | Fix | Status | Errors Fixed | Notes |
|---|-----|--------|-------------|-------|
| 1 | Skip addon directories | DONE | ~44 | `--skip-addons` flag (default: true) |
| 2 | GDScript reserved keywords | DONE | ~10 | 40-keyword list, checked in 5 functions |
| 3 | Missing built-in Godot classes | DONE (prior) | ~24 | `JSON` already present |
| 4 | Cross-file static function refs | DONE | ~51 | Resolved by Fix 1 + Fix 8 (string fix) |
| 5 | String escape sequences | DONE | ~2 | Resolved by Fix 7 (min length) + Fix 8 |
| 6 | Enum removal breaking cross-file refs | DONE | ~10 | Enum blocks kept intact |
| 7 | Loop variable / parameter scope | DONE | ~16 | Min name length > 2 chars |
| 8 | Single-quoted string handling | DONE | ~30+ | Root cause of many Fix 4/5 errors |
| 9 | Position-based string replacement | DONE | ~20+ | Fixed `.replace()` corruption of triple-quotes |
| 10 | Missing built-in methods | DONE | ~5 | `parse`, `add_item`, tween/timer/crypto methods |
| 11 | Qualified constant inlining depth | DONE | ~2 | Skip `ClassName.EnumName.VALUE` patterns |
| 12 | Newline-restricted string regex | DONE | ~280 | Single quotes in comments consumed entire code blocks |
| 13 | Extended built-in methods/properties | DONE | ~30 | `range`, `execute`, `client`, `title`, `color`, `name`, etc. |
| 14 | Skip const removal for class_name files | DONE | ~6 | `VersionManager.MAJOR` cross-file refs preserved |

**Error count progression**: 158 → 83 → 65 → 69 → 325 (full re-run exposed Fix 12) → 46 → 26 → 17 → **10**

**Unit tests**: 169 passing (up from 144)

---

## Fixes Implemented (Details)

### Fix 1: Skip Addon Directories (DONE)
- Added `skipDirs` param to `FileHelper.GetFilesRecursive()`
- Added `_skipDirectories` static var + `SetSkipDirectories()` setter to obfuscator
- `ObfuscateDirectory()` passes `_skipDirectories` to both .gd and .tscn file collection
- CLI: `--skip-addons` / `--no-skip-addons` flag, defaults true, config file support
- **Tests added**: 3 CLI tests (parse flag, negation, default)

### Fix 2: GDScript Reserved Keywords (DONE)
- Added `_gdscriptReservedKeywords` constant (40 keywords including control flow, operators, declarations, built-in values, type names)
- Keyword checks added to: `ExtractConstantsFromContent()`, `ExtractEnumValuesWithIndices()`, `InlineConstants()`, `AddFunctionsToSymbolMap()`, `AddVariablesToSymbolMap()`
- **Tests added**: 2 (keyword not extracted as enum value, keyword not inlined)

### Fix 6: Keep Enum Blocks (DONE)
- Removed enum block deletion from `RemoveConstantDeclarations()` — only `const` lines removed
- Enum blocks remain in output for cross-file type references
- **Tests updated**: 2 existing tests flipped (assert kept, not removed), 1 new test (const still removed)

### Fix 7: Skip Short Variable/Function Names (DONE)
- Added `symbolName.length() <= 2` guard to both `AddFunctionsToSymbolMap()` and `AddVariablesToSymbolMap()`
- Eliminates single-char vars (`i`, `n`, `c`) and two-char vars (`id`, `hp`) from global map
- Also resolves Fix 5 (string escape corruption from `\bn\b` matching inside `\n`)
- **Tests added**: 3 variable tests (single-letter, two-letter, three-letter+), 1 function test

### Fix 8: Single-Quoted String Handling (DONE)
**Root cause discovered**: GDScript supports both `"text"` and `'text'` string syntax. The original regex `"([^"\\]|\\.)*"` only handled double-quoted strings. When code like `c == '"'` (single-quoted string containing a double quote) appeared, the regex incorrectly matched code between unrelated `"` characters as a string literal, causing entire code blocks to be preserved (not obfuscated) or corrupted.

- Updated `PreserveStringLiterals()` regex to handle:
  - Triple double-quoted: `"""[\s\S]*?"""`
  - Triple single-quoted: `'''[\s\S]*?'''`
  - Regular double-quoted: `"([^"\\]|\\.)*"`
  - Regular single-quoted: `'([^'\\]|\\.)*'`
- Triple-quoted patterns matched FIRST (via regex alternation order)

### Fix 9: Position-Based String Replacement (DONE)
**Root cause discovered**: `PreserveStringLiterals()` used `.replace(matchedText, token)` which does GLOBAL substring replacement. When `""` (empty string literal) was matched early, `.replace('""', token)` also corrupted `"""..."""` triple-quoted strings elsewhere in the file, because `""` is a substring of `"""`.

- Switched from `.replace()` to position-based replacement (last-to-first) in both `PreserveStringLiterals()` and `PreserveSpecialStrings()`
- Each match replaced at its exact regex position using `substr()` splicing
- Eliminates all substring collision issues

### Fix 10: Missing Built-in Methods (DONE)
Added to `_godotBuiltInMethods`:
- JSON: `parse`, `stringify`, `get_data`, `get_error_line`, `get_error_message`, `get_parsed_text`
- PopupMenu/ItemList/Tree: `add_item`, `add_icon_item`, `add_check_item`, `add_separator`, `get_item_count`, etc.
- HTTPRequest: `request`, `cancel_request`, etc.
- Tween: `tween_property`, `tween_method`, `tween_callback`, `chain`, `parallel`, etc.
- Timer: `start`, `stop`, `is_stopped`, `get_time_left`
- Crypto: `update`, `finish`, `hmac_digest`

### Fix 11: Qualified Constant Inlining Depth (DONE)
**Problem**: `SupabaseQuery.Directions.Ascending` — the qualified key `Directions.Ascending` was replaced with `0`, producing invalid `SupabaseQuery.0`.

- Changed `InlineConstants()` qualified key processing from `pattern.sub()` (global) to per-match processing
- Each match checked: if preceded by `.`, skip (it's a deeper qualified reference)

### Fix 12: Newline-Restricted String Regex (DONE)
**Root cause discovered**: Regular single/double-quoted string regex patterns (`'([^'\\]|\\.)*'` and `"([^"\\]|\\.)*"`) allowed matching across newlines. When a comment contained a single quote (e.g., `# doesn't need database`), the `'` in `doesn't` started a string match that consumed everything until the next `'` in the file — potentially hundreds of lines of code were tokenized as a "string literal" and left un-obfuscated.

- Added `\n` to excluded characters in regular string patterns:
  - `"([^"\\n\\]|\\.)*"` (double-quoted)
  - `'([^'\\n\\]|\\.)*'` (single-quoted)
- Triple-quoted patterns unchanged (they legitimately span lines)
- This was the single biggest remaining bug, responsible for ~280 errors

### Fix 13: Extended Built-in Methods/Properties (DONE)
Many commonly-used Node properties and GDScript global functions were missing from `_godotBuiltInMethods`, causing them to be added to the global symbol map and obfuscated across all files.

Added:
- **GDScript globals**: `range`, `preload`, `load`, `assert`, `type_string`, `typeof`
- **Node properties**: `name`, `visible`, `modulate`, `position`, `rotation`, `scale`, `offset`, `text`, `icon`, `tooltip_text`, `placeholder_text`, `theme`, `title`, `color`, `size_flags_horizontal`, `size_flags_vertical`, `custom_minimum_size`, `anchors_preset`, `mouse_filter`
- **OS/Engine methods**: `execute`, `kill`, `shell_open`, `get_executable_path`, etc.
- **TLS factory**: `client`, `server`, `client_unsafe`
- **Singleton patterns**: `get_instance`, `instance`, `new`

### Fix 14: Skip Const Removal for class_name Files (DONE)
**Problem**: Files with `class_name` declarations (e.g., `class_name VersionManager`) expose their constants for cross-file access via `VersionManager.MAJOR`. When `RemoveConstantDeclarations()` removed `const MAJOR = 0`, external references like `VersionManager.MAJOR` broke.

- Added `class_name` detection in `RemoveConstantDeclarations()` using `(?m)^\s*class_name\s+\w+` regex
- If file has `class_name`, skip all const removal (constants stay as-is)
- Required multiline flag `(?m)` since `class_name` is usually not on line 1

---

## Remaining (10 errors, ~6%)

After all 14 fixes, 10 errors remain across 6 files. These fall into two root causes:

### 1. Local Variable Scope Mismatch (~4 errors)
The obfuscator uses a **global flat symbol map** — it doesn't understand scope. When a variable name is declared inside a function body (local scope), it may:
- Be added to the global map from another file where it's a top-level `var`
- Get its *usage* replaced by the global map, but NOT its `var` declaration (the declaration regex only captures `var X` lines, not all lines that introduce a name)

**Example**: `var card_count = 0` declared inside a function → declaration stays as `card_count`, but usage on a later line gets replaced with `aNEkIDhT`.

**Fix options**:
- **Short-term**: Add frequently-colliding names to the exclude list
- **Long-term**: Scope-aware symbol replacement (skip replacements inside functions for names not in the local file's top-level declarations)

### 2. Cascading Compile Failures (~6 errors)
When a script fails to parse (e.g., supabase-client.gd depends on a script with scope errors), Godot can't resolve its `class_name` or exports, causing "type not found" errors in all dependent scripts. The McpUpdateBanner and current_workspace errors are cascade effects.

**Fix**: Resolving the scope mismatch errors (#1) would eliminate most cascading failures.

---

## Files Modified

| File | Fixes |
|------|-------|
| `scripts/obfuscator.gd` | 1, 2, 6, 7, 8, 9, 10, 11, 12, 13, 14 |
| `scripts/file-helper.gd` | 1 |
| `scripts/obfuscate-cli.gd` | 1 |
| `tests/unit/test-obfuscator-variables.gd` | 7, 13 (updated test for `position` built-in) |
| `tests/unit/test-obfuscator-functions.gd` | 7 |
| `tests/unit/test-obfuscator-constants.gd` | 2, 6 |
| `tests/unit/test-obfuscator-cli.gd` | 1 |
| `tests/unit/test-obfuscator-phase2.gd` | 10 (updated test for `add_item` built-in) |

## Verification
1. Run godot-valet test suite — **169 tests, all passing**
2. Re-run CLI obfuscation on suganote-middle-dev with `--functions --variables --comments --constants`
3. Overlay onto runnable copy, launch headless, count `SCRIPT ERROR` lines → **10 errors**
4. After final fixes: launch obfuscated suganote with GUI and manually test

## Key Files
- Obfuscator: `scripts/obfuscator.gd`
- CLI: `scripts/obfuscate-cli.gd`
- File helper: `scripts/file-helper.gd`
- Tests: `tests/unit/test-obfuscator-*.gd` (13 test files)
- Test runner: `tests/test-runner/test-runner.gd`
- Suganote source: `C:/dad/projects/godot/godot-4/applications/suganote/suganote-middle-dev/`
