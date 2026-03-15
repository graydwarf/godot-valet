# Godot-Valet Obfuscation Enhancement Plan

## Context
Godot-valet's obfuscator (`scripts/obfuscator.gd`, 941 lines, 99 tests) currently handles function/variable name obfuscation, comment removal, and scene file signal updates. This plan adds five new obfuscation techniques plus a headless CLI mode for CI pipeline integration.

The goal: make reverse-engineering Suganote (and any project using godot-valet) expensive for both humans and AI tools.

## Current Architecture (4-Pass)
1. **Pass 1**: Enum/signal/class name extraction → exclusion lists
2. **Pass 2**: Symbol map building (functions + variables → random 8-char names)
3. **Pass 3**: Script file obfuscation (symbol replacement, comment removal)
4. **Pass 4**: Scene file obfuscation (signal connection method name updates)

Key files:
- `scripts/obfuscator.gd` — core obfuscation engine
- `scripts/content-payload.gd` — data container
- `scripts/file-helper.gd` — file system utilities
- `tests/unit/test-obfuscator*.gd` — 9 test files, 99 tests

## New Features

### Feature 1: Constant/Enum Inlining
**Effort**: Low | **Impact**: Medium

Replace named constant and enum references with their literal values throughout the codebase.

**Before:**
```gdscript
const MAX_SPEED = 100
enum State { IDLE, RUNNING, JUMPING }

func update():
    if speed > MAX_SPEED:
        speed = MAX_SPEED
    if state == State.RUNNING:
        move()
```

**After:**
```gdscript
func update():
    if speed > 100:
        speed = 100
    if state == 1:
        move()
```

**Implementation:**
- Add Pass 1.5: Scan all files for `const NAME = value` and `enum Name { A, B, C }` declarations
- Build a constant map: `{ "MAX_SPEED": "100", "State.IDLE": "0", "State.RUNNING": "1" }`
- During Pass 3, replace all constant/enum references with literal values
- Remove the original `const` and `enum` declarations
- **Exclude**: Constants used in `@export` annotations, string values (keep string obfuscation separate)
- **Test**: Verify inlined values match original, verify declarations removed, verify cross-file references work

### Feature 2: String Encryption
**Effort**: Medium | **Impact**: High

Encrypt all string literals and inject a runtime decryption helper.

**Before:**
```gdscript
var label = "Hello World"
print("User connected: " + username)
```

**After:**
```gdscript
var _dk = "a7b3f2..." # per-build key
func _sd(s): # string decrypt
    var r = ""
    for i in s.length():
        r += char(s.unicode_at(i) ^ _dk.unicode_at(i % _dk.length()))
    return r

var label = _sd("\x2b\x04\x1e...")
print(_sd("\x3a\x16\x02...") + username)
```

**Implementation:**
- Generate a random per-build encryption key (stored in obfuscation config, NOT in output)
- During Pass 3, identify all quoted string literals via regex
- Encrypt each string with XOR (simple but effective for obfuscation)
- Replace with call to injected decrypt function `_sd("encrypted")`
- Inject `_dk` and `_sd()` at top of each script file
- **Exclude**: `res://` and `user://` paths (preload/load must work), `class_name` strings, empty strings
- **Obfuscate the helper**: `_sd` and `_dk` get random names like any other function/variable
- **Test**: Verify encrypted strings decrypt correctly, verify excluded strings untouched, verify runtime behavior matches

### Feature 3: Dead Code Injection
**Effort**: Low | **Impact**: Low-Medium

Insert realistic-looking functions and variables that are never truly executed.

**Implementation:**
- Generate 5-15 fake functions per file (configurable)
- Each fake function: reads 1-2 real variables, performs plausible operations, writes to a fake variable
- Fake variables are declared at class level, referenced in fake functions
- Fake functions are called from opaque predicate false branches (Feature 5)
- Names are obfuscated along with real names in Pass 2
- **Key**: Fake code must have realistic data flow — reads real vars so static analysis can't trivially prove it's dead
- **Test**: Verify fake functions are syntactically valid GDScript, verify they don't affect real execution

### Feature 4: Control Flow Flattening
**Effort**: High | **Impact**: Very High

Transform structured control flow into state-machine switches.

**Before:**
```gdscript
func process_input(event):
    if event is InputEventMouseButton:
        if event.pressed:
            start_drag()
        else:
            end_drag()
    elif event is InputEventMouseMotion:
        update_drag(event.position)
    update_cursor()
```

**After:**
```gdscript
func process_input(event):
    var _s = 0
    while _s != -1:
        match _s:
            0:
                if event is InputEventMouseButton:
                    _s = 1
                elif event is InputEventMouseMotion:
                    _s = 4
                else:
                    _s = 5
            1:
                if event.pressed:
                    _s = 2
                else:
                    _s = 3
            2:
                start_drag()
                _s = 5
            3:
                end_drag()
                _s = 5
            4:
                update_drag(event.position)
                _s = 5
            5:
                update_cursor()
                _s = -1
```

**Implementation:**
- Parse function bodies into a basic block representation (sequences of statements between branches)
- Assign each block a random integer state ID (non-sequential to prevent easy reconstruction)
- Generate a `while/match` dispatcher
- **Selective application**: Only flatten functions with complexity score > threshold (configurable)
  - Complexity = number of `if/elif/else/while/for/match` statements
  - Default threshold: 3+ control structures
  - Skip: `_ready`, `_process`, `_physics_process` (performance-critical lifecycle methods — configurable)
- **For loops**: Transform `for i in range(n)` into equivalent while-based state machine
- **Nested ifs**: Flatten recursively — inner branches become additional states
- **Test**: Verify flattened functions produce identical output, verify state IDs are non-sequential, verify lifecycle methods excluded by default

### Feature 5: Opaque Predicates
**Effort**: Medium | **Impact**: Medium-High

Insert always-true or always-false conditions using mathematical invariants.

**Mathematical invariants to use:**
- `(x * x + 1) % 4 != 2` — always true (x²+1 is never ≡ 2 mod 4)
- `(x * (x + 1)) % 2 == 0` — always true (consecutive integers, one is even)
- `(x * x * x - x) % 3 == 0` — always true (Fermat's little theorem)
- `(x | (x - 1)) >= x - 1` — always true (bitwise property)

**Implementation:**
- Maintain a library of 10+ opaque predicate templates
- At random insertion points (between real statements), inject:
  ```gdscript
  if ((_v1 * _v1 + 1) % 4 != 2):  # always true
      real_next_statement()
  else:
      fake_function_call()  # from Feature 3
  ```
- `_v1` references a real variable in scope (makes the predicate appear data-dependent)
- Injection density: configurable (default: 1 per 10 lines of real code)
- **Always-false branch**: Calls dead code from Feature 3
- **Test**: Verify predicates always evaluate to expected value, verify real code always executes, verify fake branch never executes

### Feature 6: Headless CLI Mode
**Effort**: Medium | **Impact**: Required for CI

Enable running obfuscation from command line without GUI.

**Usage:**
```bash
Godot --headless --script obfuscate-cli.gd -- \
    --project-dir /path/to/suganote \
    --output /path/to/build \
    --config obfuscation.cfg
```

**Config file (`obfuscation.cfg`):**
```ini
[obfuscation]
functions = true
variables = true
comments = true
strings = true
constants = true
control_flow = true
opaque_predicates = true
dead_code = true

[control_flow]
complexity_threshold = 3
exclude_lifecycle = true

[opaque_predicates]
density = 0.1  # 1 per 10 lines

[dead_code]
functions_per_file = 10

[exclude]
function_names = my_special_func,another_func
variable_names = my_global_var
external_classes = SQLite,SupabaseClient
```

**Implementation:**
- Create `scripts/obfuscate-cli.gd` — extends SceneTree, runs in `_init()`
- Refactor `obfuscator.gd` to accept config via dictionary (not UI nodes)
- CLI script parses command-line args, builds config dict, calls obfuscator
- Exit codes: 0 = success, 1 = error (with message to stderr)
- **Validate**: Run CLI on suganote, export result, verify app functions

## Implementation Phases

### Phase 1: CLI Mode + Pipeline (do first — enables testing everything else)
1. Refactor `obfuscator.gd` to decouple from UI
2. Create `obfuscate-cli.gd` wrapper
3. Create config file format
4. Test: run on suganote via CLI, verify output compiles and runs
5. Add CI step to suganote's GitHub Actions workflow

### Phase 2: Constant Inlining (quick win)
1. Add constant/enum value extraction to Pass 1
2. Add inlining replacement to Pass 3
3. Add declaration removal
4. Tests: 10-15 new tests in `test-obfuscator-constants.gd`

### Phase 3: String Encryption
1. Implement XOR encryption with per-build key
2. Add string literal detection (regex, handle escaped quotes)
3. Inject decrypt helper into each file
4. Handle exclusions (res://, user://, class names)
5. Tests: 15-20 new tests in `test-obfuscator-strings-encryption.gd`

### Phase 4: Dead Code + Opaque Predicates (together — they complement each other)
1. Build opaque predicate library (10+ templates)
2. Implement dead code function generator
3. Implement injection logic with configurable density
4. Wire opaque predicate false branches to dead code
5. Tests: 15-20 new tests across two test files

### Phase 5: Control Flow Flattening (most complex — do last)
1. Implement basic block parser for GDScript functions
2. Implement state machine transformation
3. Add complexity scoring and selective application
4. Handle all control structures: if/elif/else, while, for, match
5. Handle nested structures recursively
6. Tests: 20+ new tests in `test-obfuscator-control-flow.gd`

## Local Testing Strategy

### Running Unit Tests (godot-valet)
All obfuscation tests run via godot-valet's built-in test runner:
```bash
# Launch godot-valet — tests auto-run at startup
"C:\dad\apps\godot\godot-4.5-stable\Godot_v4.5-stable_win64.exe" --path "C:\dad\projects\godot\godot-4\applications\godot-valet"

# Or run specific test file via Admin Panel in the app
```
Each new feature gets its own test file. Tests validate obfuscation correctness without needing to export/run the target project.

### Local Obfuscation Test (via GUI)
1. Open godot-valet
2. Select a test project (or suganote) in Project Manager
3. Open Release Manager → configure obfuscation toggles
4. Run obfuscation → inspect output in the `exports/` folder
5. Verify: open obfuscated `.gd` files and confirm transformations applied correctly

### Local Obfuscation Test (via CLI — after Phase 1)
```bash
# Obfuscate suganote locally, output to a temp folder
"C:\dad\apps\godot\godot-4.5-stable\Godot_v4.5-stable_win64.exe" --headless \
    --script "C:\dad\projects\godot\godot-4\applications\godot-valet\scripts\obfuscate-cli.gd" \
    -- --project-dir "C:\dad\projects\godot\godot-4\applications\suganote\suganote-main" \
       --output "C:\dad\projects\godot\godot-4\applications\suganote\suganote-obfuscated" \
       --config obfuscation.cfg
```

### Local End-to-End Validation
After obfuscating, verify the obfuscated project actually runs:
```bash
# Run the obfuscated suganote build
"C:\dad\apps\godot\godot-4.5-stable\Godot_v4.5-stable_win64.exe" --path \
    "C:\dad\projects\godot\godot-4\applications\suganote\suganote-obfuscated"
```
Checklist per feature:
- [ ] App launches without errors
- [ ] Can create/edit/delete cards
- [ ] Can navigate between boards
- [ ] Database operations work (save/load)
- [ ] Settings panel opens and functions
- [ ] No GDScript runtime errors in console

### Diff-Based Verification
After obfuscation, compare input vs output to verify transformations:
```bash
# See what changed
diff -r suganote-main/scripts suganote-obfuscated/scripts --brief
# Spot-check a specific file
diff suganote-main/scenes/board/board.gd suganote-obfuscated/scenes/board/board.gd
```

### Per-Feature Local Test Checklist

| Feature | Unit Tests | GUI Test | CLI Test | E2E Run |
|---------|-----------|----------|----------|---------|
| Constant Inlining | `test-obfuscator-constants.gd` | Toggle in Release Manager | `--constants` flag | Launch obfuscated app |
| String Encryption | `test-obfuscator-strings-encryption.gd` | Toggle in Release Manager | `--strings` flag | Launch obfuscated app |
| Dead Code | `test-obfuscator-dead-code.gd` | Toggle in Release Manager | `--dead-code` flag | Launch obfuscated app |
| Opaque Predicates | `test-obfuscator-predicates.gd` | Toggle in Release Manager | `--predicates` flag | Launch obfuscated app |
| Control Flow | `test-obfuscator-control-flow.gd` | Toggle in Release Manager | `--control-flow` flag | Launch obfuscated app |

## Verification Strategy
- After each phase: run godot-valet's full test suite (99+ existing + new tests)
- After each phase: obfuscate suganote locally (GUI or CLI), launch the result, verify core functionality
- After each phase: diff input vs output to verify transformations are applied correctly
- Final: attempt decompilation with gdre_tools on fully obfuscated + encrypted build
- Performance check: measure obfuscation time on suganote codebase (should be < 30 seconds)
