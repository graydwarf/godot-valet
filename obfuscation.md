# Function Obfuscation Improvements Plan

## Current State Analysis

The obfuscator.gd file has a basic function obfuscation system with the following characteristics:

**Strengths:**
- Two-pass architecture (symbol map building, then replacement)
- String literal preservation to avoid breaking string-based function references
- Special string preservation for `has_method()` patterns (lines 260-277)
- Reserved keyword protection (_godotReservedKeywords array)

**Limitations:**
1. Only handles `has_method()` pattern - missing `call()` support
2. Lines 466-468: Skips all functions starting with `_` (assumes PascalCase only)
3. No user-configurable whitelist for functions that shouldn't be obfuscated
4. Only detects `has_method()` - missing other reflection methods like `get_method_list()`, `connect()`, `disconnect()`, etc.

---

## Implementation Order (4 Phases)

### **Phase 1: Add `call()` Pattern Support** (Low risk, Low complexity)

**Files to modify:** `scripts/obfuscator.gd`

**Changes:**

1. **Update `PreserveSpecialStrings()` (line 263):**
   ```gdscript
   # BEFORE:
   stringRegex.compile(r'has_method\("([^"\\]*)"\)')

   # AFTER - Match all call variants:
   stringRegex.compile(r'(?:has_method|call(?:_deferred|_thread_safe|v)?)\s*\(\s*"([^"\\]*)"\s*')
   ```

2. **Update `FindFunctionSymbol()` (lines 205-206):**
   ```gdscript
   # BEFORE:
   regex.compile('.*\\.has_method\\(\\"')
   return !!regex.search(before)

   # AFTER:
   regex.compile('.*\\.(?:has_method|call(?:_deferred|_thread_safe|v)?)\\s*\\(\\s*\\"')
   return !!regex.search(before)
   ```

**What this fixes:**
- `call("function_name")` patterns preserved
- `call_deferred("function_name")` preserved
- `call_thread_safe("function_name")` preserved
- `callv("function_name", [])` preserved
- Multi-parameter `call("func", arg1, arg2)` preserved

**Testing:**
- Create test code with all call variants
- Verify function names in strings are NOT obfuscated
- Verify actual function declarations ARE obfuscated

---

### **Phase 2: Support snake_case Functions** (Medium risk, Low complexity)

**Files to modify:** `scripts/obfuscator.gd`

**Current problematic code (lines 465-469):**
```gdscript
# TODO:
# Assumes PasalCase function names (for now)
# - Assuming this will need modification for snake_case
if not symbolName.begins_with("_"):
    symbolMap[symbolName] = { "kind": "function" }
```

**Issue:** Skips ALL functions starting with `_`, including user-defined private functions you might want to obfuscate.

**Replace with:**
```gdscript
# Skip Godot reserved lifecycle functions (always start with underscore)
# But allow obfuscation of user-defined private functions
if symbolName in _godotReservedKeywords:
    continue

# Add to symbol map - will be obfuscated
symbolMap[symbolName] = { "kind": "function" }
```

**What this enables:**
- Obfuscation of `snake_case_functions()`
- Obfuscation of `camelCaseFunctions()`
- Obfuscation of `PascalCaseFunctions()`
- Obfuscation of `_user_private_functions()`
- Still protects Godot built-ins like `_ready()`, `_process()` via `_godotReservedKeywords`

**Testing:**
- Test functions with various naming conventions
- **CRITICAL:** Verify Godot built-ins (`_ready`, `_process`, etc.) are still protected
- Test user private functions are obfuscated

---

### **Phase 3: Add Whitelist System** (Low risk, Medium complexity)

**Files to modify:**
- `scripts/obfuscator.gd`
- `scenes/release-manager/release-manager.gd`
- `scenes/release-manager/release-manager.tscn`
- `scenes/project-item/project-item.gd`

**obfuscator.gd changes:**

1. **Add static variables (after line 71):**
   ```gdscript
   static var _functionWhitelist : Array[String] = []
   static var _variableWhitelist : Array[String] = []
   ```

2. **Add setter functions (after line 114):**
   ```gdscript
   static func SetFunctionWhitelist(whitelist: Array[String]) -> void:
       _functionWhitelist = whitelist

   static func SetVariableWhitelist(whitelist: Array[String]) -> void:
       _variableWhitelist = whitelist
   ```

3. **Modify `AddFunctionsToSymbolMap()` (after line 462):**
   ```gdscript
   # After checking _godotReservedKeywords:
   # Skip user-whitelisted functions
   if symbolName in _functionWhitelist:
       continue
   ```

4. **Modify `AddVariablesToSymbolMap()` (after line 492):**
   ```gdscript
   # After checking for duplicates:
   # Skip user-whitelisted variables
   if symbolName in _variableWhitelist:
       continue
   ```

**release-manager.gd changes:**

1. **Add UI references (after line 31):**
   ```gdscript
   @onready var _functionWhitelistTextEdit = %FunctionWhitelistTextEdit
   @onready var _variableWhitelistTextEdit = %VariableWhitelistTextEdit
   ```

2. **Load whitelist in `ConfigureReleaseManagementForm()` (after line 141):**
   ```gdscript
   %FunctionWhitelistTextEdit.text = selectedProjectItem.GetFunctionWhitelist()
   %VariableWhitelistTextEdit.text = selectedProjectItem.GetVariableWhitelist()
   ```

3. **Save whitelist in `SaveSettings()` (after line 176):**
   ```gdscript
   _selectedProjectItem.SetFunctionWhitelist(%FunctionWhitelistTextEdit.text)
   _selectedProjectItem.SetVariableWhitelist(%VariableWhitelistTextEdit.text)
   ```

4. **Pass to obfuscator in `ObfuscateSource()` (before line 566):**
   ```gdscript
   # Parse whitelists (comma or newline separated)
   var funcWhitelist = _parse_whitelist(%FunctionWhitelistTextEdit.text)
   var varWhitelist = _parse_whitelist(%VariableWhitelistTextEdit.text)
   ObfuscateHelper.SetFunctionWhitelist(funcWhitelist)
   ObfuscateHelper.SetVariableWhitelist(varWhitelist)
   ```

5. **Add helper function:**
   ```gdscript
   func _parse_whitelist(text: String) -> Array[String]:
       var result: Array[String] = []
       # Split by newline or comma, trim whitespace
       var items = text.replace(",", "\n").split("\n")
       for item in items:
           var cleaned = item.strip_edges()
           if cleaned != "":
               result.append(cleaned)
       return result
   ```

**release-manager.tscn changes:**

Add UI section after ObfuscationContainer (around line 396):
```gdscript
[node name="WhitelistContainer" type="HBoxContainer" parent="VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer"]
layout_mode = 2

[node name="WhitelistLabel" type="Label" parent="VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/WhitelistContainer"]
custom_minimum_size = Vector2(165, 0)
layout_mode = 2
tooltip_text = "Functions/variables to NEVER obfuscate (comma or newline separated)"
text = "Whitelist:"
horizontal_alignment = 2
vertical_alignment = 1

[node name="VBoxContainer" type="VBoxContainer" parent="VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/WhitelistContainer"]
layout_mode = 2
size_flags_horizontal = 3

[node name="FunctionWhitelistTextEdit" type="TextEdit" parent="VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/WhitelistContainer/VBoxContainer"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 60)
layout_mode = 2
placeholder_text = "Functions (e.g., SaveGame, LoadData)"

[node name="VariableWhitelistTextEdit" type="TextEdit" parent="VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/WhitelistContainer/VBoxContainer"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 60)
layout_mode = 2
placeholder_text = "Variables (e.g., player_health, score)"
```

**project-item.gd changes:**

Add getters/setters for whitelist storage.

**What this enables:**
- User control over what gets obfuscated
- Safety net for problematic function/variable names
- Comma or newline-separated input format
- Per-project whitelist persistence

**Configuration decisions:**
- **Case sensitivity:** YES (GDScript is case-sensitive)
- **Regex patterns:** NO (Phase 3 uses exact match only, regex can be future enhancement)
- **Partial matches:** NO (exact match only)

**Testing:**
- Add function to whitelist, verify it's NOT obfuscated
- Add variable to whitelist, verify it's NOT obfuscated
- Test comma-separated parsing
- Test newline-separated parsing
- Verify whitelist persists across sessions

---

### **Phase 4: Comprehensive Reflection Patterns** (High risk, Low complexity)

**Files to modify:** `scripts/obfuscator.gd`

**Godot reflection methods that need protection:**

| Method | Example | Risk Level |
|--------|---------|------------|
| `call()` | `call("jump")` | HIGH - covered in Phase 1 |
| `has_method()` | `has_method("can_jump")` | MEDIUM - already handled |
| `connect()` | `signal.connect("on_hit", callable)` | CRITICAL |
| `disconnect()` | `signal.disconnect("on_hit", callable)` | CRITICAL |
| `emit_signal()` | `emit_signal("enemy_died")` | CRITICAL |
| `set()` / `get()` | `set("position", val)` | CRITICAL |
| `set_deferred()` | `set_deferred("visible", true)` | CRITICAL |

**Changes:**

1. **Update `PreserveSpecialStrings()` (line 263) - Comprehensive pattern:**
   ```gdscript
   # Match ALL Godot reflection methods that take function/property/signal names
   stringRegex.compile(r'(?:has_method|call(?:_deferred|_thread_safe|v)?|connect|disconnect|emit_signal|set(?:_deferred)?|get)\s*\(\s*"([^"\\]*)"\s*')
   ```

2. **Update `FindFunctionSymbol()` (lines 205-206):**
   ```gdscript
   # Detect if we're in a context where function name is a string parameter
   regex.compile('.*\\.(?:has_method|call(?:_deferred|_thread_safe|v)?|connect|disconnect|emit_signal|set(?:_deferred)?|get)\\s*\\(\\s*\\"')
   return !!regex.search(before)
   ```

3. **Add new function - Auto-whitelist signals (after line 277):**
   ```gdscript
   # Preserves signal declarations - signals should never be obfuscated
   # as they're often connected via strings
   static func PreserveSignalNames(contentPayload: ContentPayload) -> void:
       var signalRegex := RegEx.new()
       signalRegex.compile(r'signal\s+(\w+)')
       var signalMatches := signalRegex.search_all(contentPayload.GetContent())

       # Add all signal names to whitelist automatically
       for match in signalMatches:
           var signalName = match.get_string(1)
           if not _functionWhitelist.has(signalName):
               _functionWhitelist.append(signalName)
   ```

4. **Call new function in `ObfuscateAllFiles()` (after line 285):**
   ```gdscript
   PreserveSpecialStrings(contentPayload)
   PreserveSignalNames(contentPayload)  # NEW - auto-whitelist signals
   PreserveStringLiterals(contentPayload)
   ```

**What this fixes:**
- Signal connections via `connect()` preserved
- Signal emissions via `emit_signal()` preserved
- Property access via `set()`/`get()` preserved
- All signal declarations automatically whitelisted
- Prevents silent runtime failures

**Edge cases:**
- @export properties already protected by `_exportVariableNames`
- Dynamic signal connections from variables cannot be detected (user must whitelist)
- Signals from parent classes only protected if in obfuscated files

**Testing:**
- Test signal declaration and usage
- Test `connect("signal_name", callable)`
- Test `emit_signal("signal_name")`
- Test `set("property", value)` and `get("property")`
- Test `set_deferred("property", value)`
- Verify all preserve correctly after obfuscation

---

## Configuration Questions

Before implementation, clarify:

1. **Whitelist regex support:** Should whitelists support regex patterns (e.g., `Save.*` matches `SaveGame`, `SaveData`)?
   - **Recommendation:** NO for Phase 3 (exact match only, simpler). Add regex as future enhancement.

2. **Auto-whitelist signals:** Should signal names automatically be protected?
   - **Recommendation:** YES (signals commonly used in string-based connections)

3. **Case sensitivity:** Should whitelist be case-sensitive?
   - **Recommendation:** YES (GDScript is case-sensitive)

---

## Risk Assessment Summary

| Phase | Risk Level | Impact | Testing Complexity |
|-------|-----------|--------|-------------------|
| #1 - call() support | LOW | High - fixes major gap | Simple |
| #2 - snake_case | MEDIUM | Medium - enables more naming styles | Medium |
| #3 - Whitelist | LOW | High - user control | Simple |
| #4 - Reflection patterns | HIGH | CRITICAL - prevents silent failures | Complex |

---

## Testing Checklist

### Phase 1 - call() Patterns:
- [ ] `call("function_name")` preserved
- [ ] `call_deferred("function_name")` preserved
- [ ] `call_thread_safe("function_name")` preserved
- [ ] `callv("function_name", [])` preserved
- [ ] Multi-parameter `call("func", arg1, arg2)` preserved

### Phase 2 - snake_case:
- [ ] `func snake_case_function()` obfuscated
- [ ] `func PascalCaseFunction()` obfuscated
- [ ] `func camelCaseFunction()` obfuscated
- [ ] `func _user_private()` obfuscated
- [ ] `func _ready()` NOT obfuscated (protected)
- [ ] `func _process(delta)` NOT obfuscated (protected)

### Phase 3 - Whitelist:
- [ ] UI loads existing whitelist
- [ ] UI saves whitelist to project config
- [ ] Whitelisted function NOT obfuscated
- [ ] Non-whitelisted function still obfuscated
- [ ] Comma-separated parsing works
- [ ] Newline-separated parsing works

### Phase 4 - Reflection Patterns:
- [ ] `connect("signal_name", callable)` preserved
- [ ] `disconnect("signal_name", callable)` preserved
- [ ] `emit_signal("signal_name")` preserved
- [ ] `set("property", value)` preserved
- [ ] `set_deferred("property", value)` preserved
- [ ] `get("property")` preserved
- [ ] `signal player_died` auto-whitelisted
- [ ] Signal emission `player_died.emit()` works after obfuscation

---

## Files Modified Summary

| File | Changes |
|------|---------|
| **scripts/obfuscator.gd** | - Add whitelist variables<br>- Modify `PreserveSpecialStrings()`<br>- Modify `FindFunctionSymbol()`<br>- Modify `AddFunctionsToSymbolMap()`<br>- Modify `AddVariablesToSymbolMap()`<br>- Add `SetFunctionWhitelist()`<br>- Add `PreserveSignalNames()` |
| **scenes/release-manager/release-manager.gd** | - Add whitelist UI references<br>- Add save/load whitelist logic<br>- Add `_parse_whitelist()` helper<br>- Call obfuscator setters |
| **scenes/release-manager/release-manager.tscn** | - Add WhitelistContainer UI section |
| **scenes/project-item/project-item.gd** | - Add GetFunctionWhitelist()<br>- Add SetFunctionWhitelist()<br>- Add GetVariableWhitelist()<br>- Add SetVariableWhitelist()<br>- Add persistence logic |

---

## Implementation Strategy

**Recommended approach:** Implement phases sequentially, testing thoroughly after each phase before proceeding.

**Backup strategy:** Maintain source control before each phase. Test obfuscation on copy of project, not production code.

**Rollback plan:** If phase causes issues, revert to previous commit and reassess approach.
