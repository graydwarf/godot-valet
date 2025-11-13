# Godot Valet - Project Context

## Guidelines
- Don't launch godot-valet for any other reason besides running unit-tests or checking for build errors
- Don't kill any godot tasks we didn't explicitly start

## Obfuscation System (scripts/obfuscator.gd)

### Architecture: Two-Pass Obfuscation + Scene File Processing

The obfuscator processes both `.gd` script files and `.tscn` scene files:

**Pass 1 - Enum Value Extraction** (`BuildGlobalObfuscationMap` lines 261-267):
- Scans ALL .gd files to extract ALL enum values into `_enumValueExcludeList`
- Ensures enum values defined in one file won't be obfuscated when used in another file
- Handles: named enums, anonymous enums, explicit values, multiline definitions

**Pass 2 - Symbol Map Building** (`BuildGlobalObfuscationMap` lines 269-283):
- Builds symbol map from all .gd files
- Functions and variables skip any names in `_enumValueExcludeList`
- Creates global dictionary of original → obfuscated name mappings

**Pass 3 - Script File Obfuscation** (`ObfuscateAllFiles` lines 333-377):
- Processes all .gd files using the global obfuscation map
- Replaces function/variable names with obfuscated versions
- Writes obfuscated scripts to output directory

**Pass 4 - Scene File Obfuscation** (`ObfuscateSceneFiles` lines 379-438):
- Processes all .tscn files to update signal connection method references
- Finds `[connection signal="..." method="method_name"]` lines
- Replaces method names with obfuscated versions from global map
- Preserves scene files without connections (copied as-is)

### Supported Patterns

**Callable Patterns** (Godot 4.x):
- `MyFunction.bind()` - Function references with bind
- `MyFunction.unbind()` - Unbind patterns
- `MyFunction.call()` - Explicit call invocations
- `MyFunction.callv()` - Call with argument array
- `items.sort_custom(ClassName.MethodName)` - Direct callable references
- `callback = my_function` - Callable assignment

**Enum Patterns**:
- `enum Name { VALUE1, VALUE2 }` - Named enums
- `enum { VALUE1, VALUE2 }` - Anonymous enums
- `enum State { Idle = 0, Running = 1 }` - Explicit values
- Multiline enum definitions with trailing commas

**Standard Patterns**:
- Function definitions: `func my_function():`
- Variable declarations: `var my_var = value`
- Class variables: `var _private_var: Type`
- Comments: Stripped from output

### Exclusion System
- User-configurable exclude lists prevent obfuscation of specific symbols
- Automatic exclusion of enum values (built-in)
- Godot built-in types/methods automatically preserved

### Testing
- **99 tests total** - All passing
- Test suites in `tests/unit/`:
  - `test-obfuscator.gd` - Core obfuscation (8 tests)
  - `test-obfuscator-functions.gd` - Function detection (13 tests)
  - `test-obfuscator-variables.gd` - Variable detection (12 tests)
  - `test-obfuscator-strings.gd` - String handling (18 tests)
  - `test-obfuscator-integration.gd` - End-to-end (9 tests)
  - `test-obfuscator-excludes.gd` - Exclude lists (10 tests)
  - `test-obfuscator-callables.gd` - Callable patterns (12 tests)
  - `test-obfuscator-enums.gd` - Enum preservation (8 tests)
  - `test-obfuscator-scenes.gd` - Scene file obfuscation (9 tests)

### UI Features
- Help dialog accessible via "?" button in Release Manager
- Comprehensive documentation of obfuscation types, testing requirements, platform support
- Located at: `scenes/release-manager/obfuscation-help-dialog.tscn`

### Recent Bug Fixes (Session 2025-01-XX)
1. ✅ **Callable .bind() patterns** - Functions referenced in `function.bind()` now obfuscated
2. ✅ **Direct callable references** - `sort_custom(ClassName.Method)` now detected
3. ✅ **Enum value preservation** - Enum values never obfuscated (two-pass architecture)
4. ✅ **Cross-file enum handling** - Enum in one file won't conflict with variable in another
5. ✅ **Scene file signal connections** - Method references in .tscn signal connections now updated to obfuscated names

### Git Commits
- `0ecd011` - Add callable pattern detection for .bind(), .unbind(), .call(), .callv()
- `3d1f4ef` - Add obfuscation help dialog with comprehensive documentation
- `0b32027` - Add enum value preservation to obfuscator
- `b3d239f` - Fix enum detection with two-pass approach for cross-file enum values
- `c7944c0` - Add .tscn scene file obfuscation to update signal connection method references

### Known Limitations
- Reflection patterns (string-based method calls) require manual exclude-list entries
- Export functions (@export) should be added to exclude list if called by string
- Signal names accessed by string should be excluded

### Testing Workflow
Run tests via Admin Panel or startup auto-run. All tests must pass before releasing obfuscated builds.

Last updated: 2025-01-XX (Scene file obfuscation completed - all 99 tests passing)