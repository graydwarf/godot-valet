---
name: obfuscation
description: GDScript obfuscation system for Godot projects. Use when working on, debugging, or extending the obfuscator — covers architecture, CLI, testing, known limitations, and the export pipeline.
---

# GDScript Obfuscation System

## When This Applies
- Working on `scripts/obfuscator.gd` or `scripts/obfuscate-cli.gd`
- Adding/modifying obfuscation techniques
- Debugging obfuscation errors in target projects
- Modifying the Release Manager export UI for obfuscation settings
- Running or writing obfuscator tests

---

## Architecture: 4-Pass Obfuscation

**Core class**: `ObfuscateHelper` in `scripts/obfuscator.gd` (static utility, ~2000 lines)

### Pass 1 — Exclusion Extraction (lines 435-484)
Scans ALL .gd files to extract names that must never be obfuscated:
- **Enum values**: `AddEnumValuesToExcludeList()` — named + anonymous enums, explicit values, multiline
- **Signal names**: `AddSignalNamesToExcludeList()` — `signal my_signal` declarations
- **Class names**: `AddClassNamesToExcludeList()` — `class_name Foo` declarations
- **Dot-accessed properties**: `_extract_dot_accessed_properties()` — `obj.property` patterns across all files

### Pass 2 — Symbol Map Building (line 955)
`BuildGlobalObfuscationMap()` creates a global dictionary of `original_name -> {replacement, kind}`:
- `AddFunctionsToSymbolMap()` (line 1863) — `func` declarations, skips lifecycle methods, built-ins, keywords, short names (<=2 chars)
- `AddVariablesToSymbolMap()` (line 1920) — `var` declarations, skips built-in properties, dot-accessed props, keywords
- Replacement names: 8-char random alphanumeric via `GenerateObfuscatedName()`

### Pass 3 — Script Obfuscation (line 1064)
`ObfuscateAllFiles()` processes each .gd file:
1. `RemoveCommentsFromCode()` — character-level scanner, handles `"""`, `'''`, escape sequences
2. `PreserveStringLiterals()` — tokenize strings to protect from replacement
3. `PreserveSpecialStrings()` — expose `call()`, `call_deferred()`, `tween_property()` etc. string args for obfuscation
4. `InlineConstants()` + `RemoveConstantDeclarations()` — replace constant refs with literal values
5. `ApplyBasicObfuscation()` — replace all symbol map entries, with scope-aware local variable protection
6. Dead code injection — append 5-10 fake functions per file (if enabled)
7. `EncryptStringLiterals()` — XOR encrypt remaining strings (if enabled)
8. `RestoreStringLiterals()` / `RestoreSpecialStrings()` — restore tokenized strings

### Pass 4 — Scene Obfuscation (line 1127)
`ObfuscateSceneFiles()` processes each .tscn file:
- **Signal connections**: `[connection signal="..." method="old_name"]` -> replaces method name
- **Property assignments**: `property_name = value` in `[node]`/`[sub_resource]` sections -> replaces variable names
- Skips path-based properties (`theme_override_*`, `metadata/*`)

---

## Obfuscation Techniques

| Technique | CLI Flag | Default | Description |
|-----------|----------|---------|-------------|
| Functions | `--functions` / `--no-functions` | on | Rename function definitions and all call sites |
| Variables | `--variables` / `--no-variables` | on | Rename variable declarations and references |
| Comments | `--comments` / `--no-comments` | on | Strip all comments (handles triple-quotes, escape sequences) |
| Constants | `--constants` / `--no-constants` | off | Inline constant/enum values, remove declarations |
| Dead Code | `--dead-code` / `--no-dead-code` | off | Append fake functions with opaque predicates |
| Strings | `--strings` / `--no-strings` | off | XOR encrypt string literals, inject per-file decrypt helper |

### Dead Code Details
- `GenerateDeadFunctions()` (line 1334): 5-10 fake functions per file, appended at end
- `GenerateOpaquePredicate()` (line 1308): 3 always-true, 2 always-false math templates
- `InjectDeadCodeCalls()` (line 1400): EXISTS but DISABLED — inline if-blocks break Godot drag-drop
- Only append-style dead functions are used in production

### String Encryption Details
- `GenerateEncryptionKey()` (line 1500): Random 32-byte key per build
- `EncryptStringLiterals()` (line 1508): XOR encrypt, replace with `__d(PackedByteArray([...]))`
- `_inject_decrypt_helper()` (line 1688): Inject `__d()` function + key var per file + inner classes
- **Skipped**: `res://`, `user://`, empty/single-char strings, consts, preloads, annotations, StringNames, default params

---

## Exclusion System

### Automatic Exclusions
- **ClassDB runtime query**: `BuildBuiltInSetsFromClassDB()` (line 349) — all engine methods, properties, signals, classes
- **Lifecycle methods**: `_ready`, `_process`, `_physics_process`, etc. (line 95)
- **GDScript keywords**: 40+ reserved words (line 85)
- **Enum values**: Two-pass extraction ensures cross-file safety
- **Signal names**: Auto-extracted from `signal` declarations
- **Class names**: Auto-extracted from `class_name` declarations
- **Dot-accessed properties**: `obj.property` patterns excluded from variable map
- **Short names**: Variables/functions with 2 or fewer characters skipped

### User-Configurable Exclusions
- `SetFunctionExcludeList()` — functions to never rename
- `SetVariableExcludeList()` — variables to never rename
- `SetConstantExcludeList()` — constants to never inline
- `SetExternalPluginClasses()` — addon class names
- `SetExtraBuiltInMethods()` — GDExtension methods not in ClassDB (e.g., SQLite)
- `SetSkipDirectories()` — directories to skip entirely

### Scope Protection
- `ExtractLocalNames()` (line 502): Extracts function params, local vars, class-level vars per file
- Prevents function-name replacement when a local variable has the same name
- `FindFunctionSymbol()` (line 617): Parenthesis/bracket depth tracking for callable context

---

## CLI Reference

```bash
# Full invocation pattern
"path/to/Godot" --headless \
  --path "path/to/godot-valet" \
  --script res://scripts/obfuscate-cli.gd -- [options]

# Required
--project-dir <path>       Source project directory
--output <path>            Output directory for obfuscated files

# Obfuscation toggles
--functions / --no-functions       (default: on)
--variables / --no-variables       (default: on)
--comments / --no-comments         (default: on)
--constants / --no-constants       (default: off)
--dead-code / --no-dead-code       (default: off)
--strings / --no-strings           (default: off)

# Filtering
--skip-addons / --no-skip-addons   Skip addons/ (default: on)
--skip-dirs <dirs>                 Comma-separated extra dirs to skip
--builtin-methods <methods>        Comma-separated GDExtension method names

# Export pipeline
--export <preset>          Export preset name (e.g., "Windows Desktop")
--godot-path <path>        Custom Godot binary for export (required with --export)
--encryption-key <path>    Hex encryption key file path
--export-output <path>     Copy artifacts to this location
--debug                    Use --export-debug instead of --export-release

# Validation
--validate                 Run headless error count after obfuscation

# Config file
--config <path>            INI file with [paths], [obfuscation], [exclude], [export] sections
```

### Return Codes
- `0` = success
- `1` = argument error
- `2` = export/runtime error

---

## Testing

**192+ tests** across 15 test files in `tests/unit/`:

| File | Tests | Coverage |
|------|-------|----------|
| `test-obfuscator.gd` | 8 | Core obfuscation + triple-quote comment stripping |
| `test-obfuscator-functions.gd` | 13 | Function detection, short names, lifecycle |
| `test-obfuscator-variables.gd` | 12 | Variable detection, short names, built-ins |
| `test-obfuscator-strings.gd` | 20+ | String preservation, special strings, tween patterns |
| `test-obfuscator-strings-encrypt.gd` | 17 | XOR encryption, exclusions, helper injection |
| `test-obfuscator-integration.gd` | 9 | End-to-end obfuscation |
| `test-obfuscator-excludes.gd` | 10 | Exclude list behavior |
| `test-obfuscator-callables.gd` | 12 | `.bind()`, `.call()`, `.call_deferred()`, sort_custom |
| `test-obfuscator-enums.gd` | 8 | Enum preservation, cross-file |
| `test-obfuscator-scenes.gd` | 18 | Signal connections (9) + property assignments (9) |
| `test-obfuscator-constants.gd` | 20 | Constant extraction, inlining, qualified refs |
| `test-obfuscator-deadcode.gd` | 14 | Opaque predicates, dead functions, injection |
| `test-obfuscator-cli.gd` | 15+ | Arg parsing, flag resolution, config loading |
| `test-obfuscator-builtins.gd` | varies | ClassDB built-in detection |
| `test-obfuscator-phase2.gd` | varies | Phase 2 constant/enum features |

**Run tests**: Via godot-valet Admin Panel or test runner autorun on startup.

---

## Known Limitations

1. **Global flat symbol map** — No true scope modeling. `ExtractLocalNames()` adds per-file protection but edge cases with inner classes or deeply nested scopes may exist.
2. **String-based reflection** — `set("property")`, `get("property")`, `get_node("path")` are NOT auto-handled. Users must add to exclude lists. Only `call()`, `call_deferred()`, `has_method()`, `tween_property()`, `tween_method()` are auto-detected.
3. **Inline dead code disabled** — `InjectDeadCodeCalls()` exists but breaks Godot drag-drop. Only append-style dead functions are safe.
4. **Constant inlining scope** — Constants in `class_name` files aren't removed (cross-file refs like `ClassName.CONST`). The constant map only has bare keys, not qualified cross-file keys.
5. **No signal obfuscation** — `ObfuscateSignals()` is a placeholder (line 1735). Signal names in declarations and connections are preserved, not renamed.
6. **No minification** — `Minify()` placeholder exists (line 1782) but not fully implemented.

---

## Export Pipeline

The CLI handles the full pipeline: obfuscate -> copy project -> overlay obfuscated files -> export with custom Godot + encryption -> collect artifacts.

### DB Isolation
- `--debug` flag -> exports with `--export-debug` -> `OS.is_debug_build()` returns true -> app routes to `user://debug_workspaces/`
- No `--debug` -> release build -> routes to `user://workspaces/`

### Custom Godot Build
- Production exports use a custom-compiled Godot with custom encryption (not stock)
- Encryption key set via `GODOT_SCRIPT_ENCRYPTION_KEY` env var at export time
- Build templates are gitignored, stored in target project's `build/templates/`

---

## Key Files

| File | Purpose |
|------|---------|
| `scripts/obfuscator.gd` | Core obfuscation engine (~2000 lines) |
| `scripts/obfuscate-cli.gd` | CLI entry point for headless/CI usage |
| `scripts/content-payload.gd` | Data container for file content + preserved strings |
| `scripts/file-helper.gd` | File system utilities (recursive file listing with skip dirs) |
| `scenes/release-manager/pages/export-page/export-page.gd` | GUI invocation of obfuscator |
| `scenes/release-manager/pages/export-page/dialogs/build-config-dialog/` | Obfuscation toggle UI |
| `tests/unit/test-obfuscator*.gd` | 15 test files, 192+ tests |
| `local-docs/obfuscated-build-pipeline.md` | Pipeline docs, E2E status, coverage stats |
| `local-docs/obfuscator-bugfix-plan.md` | All 24 bug fixes with root causes |
| `local-docs/godot-valet-ui-obfuscation-plan.md` | Uber-Phase 3 UI spec |

---

## Phase Status

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1 | COMPLETE | CLI mode + obfuscator decoupling |
| Phase 2 | COMPLETE | Constant/enum inlining |
| Phase 3 | COMPLETE | String encryption (XOR, per-build key) |
| Phase 4 | COMPLETE | Dead code injection (append-only) |
| Phase 5 | NOT STARTED | Control flow flattening (while/match state machine) |
| Uber-Phase 1 | COMPLETE | Full CLI pipeline (obfuscate -> export) |
| Uber-Phase 2 | COMPLETE | GitHub Actions workflow in downstream project |
| Uber-Phase 3 | IN PROGRESS | UI updates — wire missing flags, add new toggles |

### E2E Coverage (measured 2026-03-14)
- Functions: 88% (3,052/3,471)
- Variables: 72% (979/1,366)
- Comments: 100% stripped
- Scene signals: 100%
- File coverage: 100% (177 .gd, 42 .tscn)
- Production errors: **0**

### UI Gap (Uber-Phase 3)
The build config dialog has toggles for `dead_code` and `encrypt_strings`, but `export-page.gd` only passes 3 flags (functions, variables, comments) to `ObfuscateHelper.ObfuscateScripts()`. Constants, dead code, string encryption, source filters, and `--builtin-methods` need to be wired through.
