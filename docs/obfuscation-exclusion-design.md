# Obfuscation Exclusion System - Design Document

## Problem Statement

The current obfuscator is too aggressive and breaks code by obfuscating:
1. Built-in Godot method names (`.size()`, `.append()`, `.has()`, etc.)
2. Built-in Godot class names (`Array`, `Dictionary`, `Node`, `Control`, etc.)
3. External plugin classes (`SQLite`, Supabase classes, etc.)
4. Signal names declared with `signal my_signal`
5. Class names in type hints and inheritance

## Core Philosophy

**Be Conservative**: Only obfuscate symbols we're CERTAIN are user-defined and safe to rename.

**Default to Exclusion**: If there's any doubt whether a symbol is built-in or external, DON'T obfuscate it.

## Exclusion Categories

### 1. Built-In Method Names (CRITICAL)

**Problem**: User-defined `func size():` causes ALL instances of `size` to be obfuscated, breaking `arr.size()`.

**Solution Options:**

#### Option A: Comprehensive Built-In Method Blacklist (RECOMMENDED)
- Maintain a curated list of ALL common Godot built-in methods
- Check against this list before adding functions to symbol map
- **Pros**: Simple, predictable, works for all Godot versions
- **Cons**: Requires maintenance when Godot adds new methods

#### Option B: Context-Aware Detection
- Only obfuscate `size` if it's NEVER used in a member access context (`.size()`)
- **Pros**: More flexible, catches edge cases
- **Cons**: Complex, error-prone, slower

**Recommendation**: Start with Option A (blacklist), add Option B refinements later.

**Built-In Methods to Exclude** (initial list):
```gdscript
# Array/Dictionary methods
["size", "append", "clear", "has", "erase", "find", "insert", "pop_back", "pop_front",
 "push_back", "push_front", "remove", "resize", "reverse", "shuffle", "sort", "sort_custom",
 "keys", "values", "duplicate", "is_empty", "pop_at", "slice", "assign", "fill",
 "max", "min", "any", "all", "map", "filter", "reduce", "pick_random", "front", "back"]

# String methods
["begins_with", "ends_with", "capitalize", "casecmp_to", "contains", "count", "format",
 "get_base_dir", "get_basename", "get_extension", "get_file", "hex_to_int", "is_absolute_path",
 "is_relative_path", "is_valid_float", "is_valid_hex_number", "is_valid_html_color",
 "is_valid_identifier", "is_valid_int", "join", "json_escape", "left", "length", "lpad",
 "lstrip", "match", "matchn", "md5_buffer", "md5_text", "naturalnocasecmp_to", "nocasecmp_to",
 "num", "pad_decimals", "pad_zeros", "path_join", "repeat", "replace", "replacen", "rfind",
 "rfindn", "right", "rpad", "rsplit", "rstrip", "sha1_buffer", "sha1_text", "sha256_buffer",
 "sha256_text", "similarity", "simplify_path", "split", "split_floats", "strip_edges",
 "strip_escapes", "substr", "to_ascii_buffer", "to_camel_case", "to_float", "to_int",
 "to_lower", "to_pascal_case", "to_snake_case", "to_upper", "to_utf8_buffer", "to_utf16_buffer",
 "to_utf32_buffer", "to_wchar_buffer", "trim_prefix", "trim_suffix", "unicode_at", "uri_decode",
 "uri_encode", "validate_node_name", "xml_escape", "xml_unescape"]

# Node methods
["add_child", "add_sibling", "add_to_group", "call_deferred", "call_thread_safe", "can_process",
 "duplicate", "find_child", "find_children", "find_parent", "get_child", "get_child_count",
 "get_children", "get_groups", "get_index", "get_node", "get_node_and_resource", "get_node_or_null",
 "get_parent", "get_path", "get_path_to", "get_physics_process_delta_time", "get_process_delta_time",
 "get_tree", "get_viewport", "get_window", "has_node", "has_node_and_resource", "is_ancestor_of",
 "is_displayed_folded", "is_editable_instance", "is_greater_than", "is_in_group", "is_inside_tree",
 "is_node_ready", "is_processing", "is_processing_input", "is_processing_internal", "is_processing_unhandled_input",
 "is_processing_unhandled_key_input", "move_child", "print_orphan_nodes", "print_tree", "print_tree_pretty",
 "propagate_call", "propagate_notification", "queue_free", "remove_child", "remove_from_group",
 "reparent", "replace_by", "request_ready", "set_deferred", "set_display_folded", "set_editable_instance",
 "set_owner", "set_physics_process", "set_physics_process_internal", "set_process", "set_process_input",
 "set_process_internal", "set_process_unhandled_input", "set_process_unhandled_key_input",
 "set_process_mode", "set_scene_instance_load_placeholder", "update_configuration_warnings"]

# Object methods (base class - VERY common)
["get", "set", "get_class", "get_instance_id", "get_meta", "get_meta_list", "get_method_list",
 "get_property_list", "get_script", "get_signal_connection_list", "get_signal_list", "has_meta",
 "has_method", "has_signal", "has_user_signal", "is_class", "is_connected", "is_queued_for_deletion",
 "notification", "notify_property_list_changed", "remove_meta", "set_block_signals", "set_indexed",
 "set_message_translation", "set_meta", "set_script", "to_string", "tr", "tr_n"]

# Resource methods
["duplicate", "emit_changed", "get_local_scene", "get_path", "get_rid", "setup_local_to_scene",
 "take_over_path"]

# PackedArray methods (common across all packed array types)
["bsearch", "count", "duplicate", "fill", "has", "is_empty", "reverse", "rfind", "size", "slice", "sort", "to_byte_array"]

# Math/Vector methods
["abs", "acos", "asin", "atan", "atan2", "ceil", "clamp", "cos", "cosh", "deg2rad", "ease",
 "exp", "floor", "fmod", "fposmod", "hash", "inverse_lerp", "is_equal_approx", "is_finite",
 "is_inf", "is_nan", "is_zero_approx", "lerp", "lerp_angle", "linear2db", "log", "max", "min",
 "move_toward", "nearest_po2", "pingpong", "posmod", "pow", "rad2deg", "randi", "randf", "randf_range",
 "randi_range", "randomize", "round", "sign", "sin", "sinh", "smoothstep", "snapped", "sqrt",
 "step_decimals", "tan", "tanh", "wrap", "wrapf", "wrapi"]
```

### 2. Built-In Class Names (CRITICAL)

**Problem**: Type hints like `var arr: Array` or `extends Node` cause `Array`/`Node` to be obfuscated.

**Solution**: Detect class name usage contexts and exclude them.

**Detection Patterns:**
```gdscript
# Type hints
var my_var: ClassName
func my_func() -> ClassName:
func my_func(param: ClassName):

# Instantiation
var obj = ClassName.new()
var obj: ClassName = ClassName.new()

# Inheritance
extends ClassName
class_name MyClass extends ClassName

# Type checks
if obj is ClassName:
obj as ClassName
```

**Built-In Classes to Exclude** (comprehensive list):
```gdscript
# Core types
["Variant", "bool", "int", "float", "String", "Vector2", "Vector2i", "Vector3", "Vector3i",
 "Transform2D", "Vector4", "Vector4i", "Plane", "Quaternion", "AABB", "Basis", "Transform3D",
 "Projection", "Color", "StringName", "NodePath", "RID", "Object", "Callable", "Signal",
 "Dictionary", "Array", "PackedByteArray", "PackedInt32Array", "PackedInt64Array",
 "PackedFloat32Array", "PackedFloat64Array", "PackedStringArray", "PackedVector2Array",
 "PackedVector3Array", "PackedColorArray"]

# Scene tree
["Node", "Node2D", "Node3D", "CanvasItem", "Control", "Window", "Viewport"]

# Common UI nodes
["Button", "Label", "LineEdit", "TextEdit", "RichTextLabel", "CheckBox", "CheckButton",
 "ColorPicker", "ColorPickerButton", "MenuButton", "OptionButton", "PopupMenu", "ProgressBar",
 "ScrollBar", "HScrollBar", "VScrollBar", "Slider", "HSlider", "VSlider", "SpinBox",
 "TextureRect", "VideoPlayer", "Container", "BoxContainer", "HBoxContainer", "VBoxContainer",
 "GridContainer", "MarginContainer", "PanelContainer", "ScrollContainer", "SplitContainer",
 "HSplitContainer", "VSplitContainer", "TabContainer", "Panel", "ColorRect", "NinePatchRect",
 "ReferenceRect", "AspectRatioContainer", "CenterContainer", "FlowContainer", "HFlowContainer",
 "VFlowContainer", "GraphNode", "GraphElement", "SubViewportContainer"]

# Resources
["Resource", "Texture", "Texture2D", "Texture3D", "Image", "Font", "StyleBox", "Theme",
 "Shader", "Material", "Mesh", "PackedScene", "Animation", "AudioStream"]

# Other common
["HTTPRequest", "Timer", "AnimationPlayer", "Tween", "FileAccess", "DirAccess", "JSON",
 "RegEx", "Thread", "Mutex", "Semaphore"]
```

### 3. External Plugin Classes (HIGH PRIORITY)

**Problem**: Plugin classes like `SQLite` are obfuscated, breaking binary native calls.

**Solution Options:**

#### Option A: Auto-Detect from project.godot
- Parse `project.godot` to find enabled plugins
- For each plugin, scan `addons/plugin_name/plugin.cfg` to get class names
- Auto-exclude those classes
- **Pros**: Zero config, automatic
- **Cons**: Requires parsing multiple files

#### Option B: Manual Configuration
- Add "External Plugin Classes" field to UI
- User enters comma-separated list: `SQLite,SupabaseAPI,SomeOtherPlugin`
- **Pros**: Simple, explicit
- **Cons**: Requires user action

#### Option C: Heuristic Detection
- Detect class names that appear in type hints but are never defined in user code
- Assume those are external
- **Pros**: Automatic, no config
- **Cons**: Could miss edge cases

**Recommendation**: Implement Option B immediately (manual config), add Option A later.

### 4. Signal Names (MEDIUM PRIORITY)

**Problem**: Signals declared with `signal my_signal` are obfuscated.

**Solution**: Detect `signal signal_name` declarations and add to exclusion list.

**Detection Pattern:**
```gdscript
signal my_signal
signal my_signal_with_args(arg1, arg2)
```

**Implementation:**
```gdscript
static func AddSignalNamesToExcludeList(content: String) -> void:
    var regex := RegEx.new()
    regex.compile(r"signal\s+(\w+)")
    for match in regex.search_all(content):
        var signal_name = match.get_string(1)
        if signal_name not in _signalExcludeList:
            _signalExcludeList.append(signal_name)
```

**Note**: This only handles signal DECLARATIONS. Signal connections via strings (`.connect("signal_name", ...)`) are already preserved by string literal protection.

### 5. Class Names in User Code (LOW-MEDIUM PRIORITY)

**Problem**: User-defined class names (from `class_name MyClass`) should be excluded if:
- Used in type hints elsewhere
- Used in `extends MyClass`
- Instantiated with `MyClass.new()`

**Solution**: Two-pass approach (similar to enum handling):
- Pass 1: Extract all `class_name ClassName` declarations
- Pass 2: Exclude those names from obfuscation

**Detection Pattern:**
```gdscript
class_name MyClassName
class_name MyClassName extends ParentClass
```

## Implementation Plan

### Phase 1: Critical Fixes (Immediate)
1. ✅ Add comprehensive built-in method blacklist (500+ methods)
2. ✅ Add comprehensive built-in class blacklist (100+ classes)
3. ✅ Add "External Plugin Classes" configuration field to UI
4. ✅ Update exclusion checks in `AddFunctionsToSymbolMap()` and `AddVariablesToSymbolMap()`

### Phase 2: Signal & Class Detection (Next)
1. Add `_signalExcludeList` and signal detection function
2. Add `_classNameExcludeList` and class name detection function
3. Call both in first pass of `BuildGlobalObfuscationMap()`

### Phase 3: Context-Aware Refinements (Later)
1. Detect class names from type hints and `extends`
2. Auto-detect plugins from project.godot
3. Add heuristic detection for external classes

### Phase 4: Testing & Validation
1. Create test cases for each exclusion category
2. Test against real projects with plugins (SQLite, Supabase)
3. Add comprehensive integration tests

## Configuration UI Changes

Add to Release Manager obfuscation section:

```
[Exclude-Lists Button] (existing)

[External Plugins] (NEW)
Text field: "SQLite,SupabaseAPI,MyCustomPlugin"
Tooltip: "Comma-separated list of external plugin class names to exclude from obfuscation"
```

## Backward Compatibility

- Existing exclude lists (functions/variables) continue to work
- New exclusions are additive (more conservative)
- No breaking changes to API

## Testing Strategy

### Unit Tests
- `test_builtin_methods_excluded()` - Verify Array.size(), String.split(), etc. not obfuscated
- `test_builtin_classes_excluded()` - Verify Node, Control, Array type hints not obfuscated
- `test_plugin_classes_excluded()` - Verify SQLite, custom plugin classes not obfuscated
- `test_signal_names_excluded()` - Verify signal declarations not obfuscated
- `test_class_name_declarations_excluded()` - Verify user class names not obfuscated

### Integration Tests
- Test obfuscation of real project using SQLite plugin
- Test obfuscation of project with Supabase integration
- Test project with signals and custom classes

## Open Questions

1. **Performance**: Will checking against 500+ method names slow down obfuscation?
   - **Answer**: Minimal impact - use Dictionary/Set lookups (O(1))

2. **Godot Version Compatibility**: Different Godot versions have different methods?
   - **Answer**: Include union of all methods from Godot 4.0-4.x
   - User can always add to exclude list if needed

3. **User-Defined Methods Conflicting with Built-Ins**: What if user has `func size():`?
   - **Answer**: That method WON'T be obfuscated (excluded by blacklist)
   - This is safer than breaking built-in calls
   - User can rename their method if they want it obfuscated

4. **Static Methods on Classes**: `MyClass.static_method()` - should we detect class membership?
   - **Answer**: Phase 3 enhancement - for now, rely on class name exclusion

## Success Criteria

- ✅ No more "Cannot find member 'SofAlEPD'" errors (built-in methods work)
- ✅ SQLite and other plugins work without manual exclude list entries
- ✅ Signals work correctly after obfuscation
- ✅ Type hints and inheritance work correctly
- ✅ User can obfuscate production game without runtime errors

## Risks & Mitigations

**Risk**: Too conservative - obfuscates less code
**Mitigation**: That's the point - safety over aggressiveness

**Risk**: Maintenance burden - keeping built-in lists updated
**Mitigation**: Lists are stable (Godot rarely removes methods), easy to update

**Risk**: User confusion - "why isn't my `size()` method obfuscated?"
**Mitigation**: Document in help dialog, explain safety rationale

---

## Decision Required

**Should we proceed with this design?**

Key design choices to confirm:
1. ✅ Use comprehensive blacklists for built-in methods/classes (vs. context-aware detection)
2. ✅ Manual "External Plugin Classes" config field (vs. auto-detect from project.godot)
3. ✅ Implement signal detection in Phase 2
4. ✅ Implement class name detection in Phase 2
5. ✅ Start with conservative approach, refine later

**Alternative**: Implement context-aware detection from the start?
- Pros: More flexible, fewer false exclusions
- Cons: Much more complex, error-prone, slower

**Recommendation**: Proceed with blacklist approach (Phase 1-2), add context-aware refinements in Phase 3 if needed.
