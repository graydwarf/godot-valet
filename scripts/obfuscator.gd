extends Node
class_name ObfuscateHelper

# README - BETA BETA BETA - EARLY ACCESS - UNTESTED
#
# USE AT YOUR OWN RISK <- Read that again.
#
# This is an open source project. Review any and all code
# and ensure it does what you expect before using it. 
#
# A couple important things:
# - Do not proceed without source control (backing up)
# - Do not release without comprehensive testing.
#
# You SHOULD NOT use obfuscation without testing every nook and
# cranny of your game. Launching is not enough. Obfuscation touches
# every little thing in your project so you have to test every little
# thing to be certain nothing is broken. I do mean every little thing.
# Unit tests can be a big help in this regard if you have them. Once 
# you've refined & stabalized the obfuscation (and tested every aspect
# of your game) you should only need to test where you've made changes
# from there on out. If you make changes to the obfuscator, a full test
# pass is recommended (generally required). 
#
# This initial version is rudamtary at best. It was designed based on
# a single project which means no real testing has occured yet. I use 
# a mix of camelCase, PascalCase and kebab-case so this could be completely 
# busted for styles.
#
# You will most likely need to massage your code to work well with 
# obfuscation (renaming problematic things) as well as updating the
# obfuscator where it's lacking or maybe even wrong. Again, this feature
# is largely untested.
#
# There are other obfuscator projects out there that are way more 
# sofisticated including plug-ins for godot. 
#
# If you make improvements that others can benefit from, 
# please publish a PR. 
#

# Notes:
# Key things to keep in mind.
# - A global symbol map is used (we crawl through all the files looking for
#	all function and variable names.
# - We use that global symbol map to replace function/variable 
# 	name regardless of local/global state so every instance of a name
# 	gets replaced with the same replacement name across all files.
# 	This generally works for most things but can trip up.
# 
# Open Issues: (to name a few)
# - Just about any call made with a string to a
# 	function is at risk if duplicate names are present.
#
# - Calls to functions using string representation such 
#	as: .set("_rotationSpeed", ...) especially if that variable
#	was set with @export.
#
# - Calls to variables in other classes where the variable 
# 	is an @export AND that same variable name is defined elsewhere.

static var _inputDir : String = ""
static var _outputDir : String = ""
static var _usedNames : Dictionary = {}
static var _exportVariableNames := []
static var _isObfuscatingFunctions := false
static var _isObfuscatingVariables := false
static var _isObfuscatingComments := false
static var _functionExcludeList : Array[String] = []
static var _variableExcludeList : Array[String] = []
static var _enumValueExcludeList : Array[String] = []
static var _signalExcludeList : Array[String] = []  # Auto-detected signal names
static var _classNameExcludeList : Array[String] = []  # Auto-detected class_name declarations
static var _externalPluginClasses : Array[String] = []  # User-configured external plugin class names

# Godot lifecycle methods (virtual methods that must not be obfuscated)
const _godotLifecycleMethods := [
	"_ready", "_process", "_physics_process", "_input", "_unhandled_input", "_init",
	"_enter_tree", "_exit_tree", "_notification", "_draw", "_gui_input", "_get_property_list",
	"_get", "_set", "_to_string", "_save", "_load", "_input_event", "_unhandled_key_input",
	"_physics_process", "_integrate_forces", "_get_configuration_warnings"
]

# Comprehensive list of built-in Godot method names
# These should NEVER be obfuscated as they're called by the engine or are built-in to core types
const _godotBuiltInMethods := [
	# Array/Dictionary/Collection methods
	"size", "append", "clear", "has", "erase", "find", "insert", "pop_back", "pop_front",
	"push_back", "push_front", "remove", "resize", "reverse", "shuffle", "sort", "sort_custom",
	"keys", "values", "duplicate", "is_empty", "pop_at", "slice", "assign", "fill",
	"max", "min", "any", "all", "map", "filter", "reduce", "pick_random", "front", "back",
	"bsearch", "bsearch_custom", "count", "rfind", "find_last", "hash", "make_read_only",
	"is_read_only", "merge", "get_typed_builtin", "get_typed_class_name", "get_typed_script",
	"is_typed", "is_same_typed", "set_typed",

	# String methods
	"begins_with", "ends_with", "capitalize", "casecmp_to", "contains", "format",
	"get_base_dir", "get_basename", "get_extension", "get_file", "hex_to_int", "is_absolute_path",
	"is_relative_path", "is_valid_float", "is_valid_hex_number", "is_valid_html_color",
	"is_valid_identifier", "is_valid_int", "is_valid_ip_address", "is_valid_filename", "join",
	"json_escape", "left", "length", "lpad", "lstrip", "match", "matchn", "md5_buffer", "md5_text",
	"naturalnocasecmp_to", "nocasecmp_to", "num", "pad_decimals", "pad_zeros", "path_join",
	"repeat", "replace", "replacen", "rfind", "rfindn", "right", "rpad", "rsplit", "rstrip",
	"sha1_buffer", "sha1_text", "sha256_buffer", "sha256_text", "similarity", "simplify_path",
	"split", "split_floats", "strip_edges", "strip_escapes", "substr", "to_ascii_buffer",
	"to_camel_case", "to_float", "to_int", "to_lower", "to_pascal_case", "to_snake_case",
	"to_upper", "to_utf8_buffer", "to_utf16_buffer", "to_utf32_buffer", "to_wchar_buffer",
	"trim_prefix", "trim_suffix", "unicode_at", "uri_decode", "uri_encode", "validate_node_name",
	"xml_escape", "xml_unescape", "indent", "dedent", "bin_to_int", "c_escape", "c_unescape",
	"get_slice", "get_slice_count", "get_slicec", "hex_encode", "humanize_size", "is_subsequence_of",
	"is_subsequence_ofn", "num_int64", "num_scientific", "num_uint64", "reverse",

	# Node methods
	"add_child", "add_sibling", "add_to_group", "can_process", "create_tween",
	"find_child", "find_children", "find_parent", "get_child", "get_child_count",
	"get_children", "get_groups", "get_index", "get_node", "get_node_and_resource", "get_node_or_null",
	"get_parent", "get_path", "get_path_to", "get_physics_process_delta_time", "get_process_delta_time",
	"get_tree", "get_viewport", "get_window", "has_node", "has_node_and_resource", "is_ancestor_of",
	"is_displayed_folded", "is_editable_instance", "is_greater_than", "is_in_group", "is_inside_tree",
	"is_node_ready", "is_processing", "is_processing_input", "is_processing_internal", "is_processing_unhandled_input",
	"is_processing_unhandled_key_input", "move_child", "print_orphan_nodes", "print_tree", "print_tree_pretty",
	"propagate_call", "propagate_notification", "queue_free", "remove_child", "remove_from_group",
	"reparent", "replace_by", "request_ready", "set_display_folded", "set_editable_instance",
	"set_owner", "set_physics_process", "set_physics_process_internal", "set_process", "set_process_input",
	"set_process_internal", "set_process_unhandled_input", "set_process_unhandled_key_input",
	"set_process_mode", "set_scene_instance_load_placeholder", "update_configuration_warnings",
	"get_multiplayer_authority", "set_multiplayer_authority", "rpc", "rpc_id", "is_multiplayer_authority",

	# Object methods (base class - VERY common)
	"get", "set", "get_class", "get_instance_id", "get_meta", "get_meta_list", "get_method_list",
	"get_property_list", "get_script", "get_signal_connection_list", "get_signal_list", "has_meta",
	"has_method", "has_signal", "has_user_signal", "is_class", "is_connected", "is_queued_for_deletion",
	"notification", "notify_property_list_changed", "remove_meta", "set_block_signals", "set_indexed",
	"set_message_translation", "set_meta", "set_script", "to_string", "tr", "tr_n", "free",
	"call", "call_deferred", "callv", "connect", "disconnect", "emit_signal", "is_blocking_signals",
	"set_deferred", "add_user_signal", "can_translate_messages", "get_incoming_connections",

	# Resource methods
	"get_local_scene", "get_rid", "setup_local_to_scene", "take_over_path", "emit_changed",
	"get_path", "set_path", "set_local_to_scene",

	# PackedArray methods (common across all packed array types)
	"to_byte_array", "compress", "decompress", "decode_double", "decode_float", "decode_half",
	"decode_s16", "decode_s32", "decode_s64", "decode_s8", "decode_u16", "decode_u32", "decode_u64",
	"decode_u8", "decode_var", "decode_var_size", "encode_double", "encode_float", "encode_half",
	"encode_s16", "encode_s32", "encode_s64", "encode_s8", "encode_u16", "encode_u32", "encode_u64",
	"encode_u8", "encode_var", "get_string_from_ascii", "get_string_from_utf16", "get_string_from_utf32",
	"get_string_from_utf8", "get_string_from_wchar", "hex_encode", "has_encoded_var",

	# Math/Vector methods
	"abs", "absf", "absi", "acos", "acosh", "angle_difference", "asin", "asinh", "atan", "atan2",
	"atanh", "bezier_derivative", "bezier_interpolate", "ceil", "ceilf", "ceili", "clamp", "clampf",
	"clampi", "cos", "cosh", "cubic_interpolate", "cubic_interpolate_angle", "cubic_interpolate_angle_in_time",
	"cubic_interpolate_in_time", "db_to_linear", "deg_to_rad", "ease", "error_string", "exp", "floor",
	"floorf", "floori", "fmod", "fposmod", "hash", "instance_from_id", "inverse_lerp", "is_equal_approx",
	"is_finite", "is_inf", "is_instance_id_valid", "is_instance_valid", "is_nan", "is_same", "is_zero_approx",
	"lerp", "lerp_angle", "lerpf", "linear_to_db", "log", "max", "maxf", "maxi", "min", "minf", "mini",
	"move_toward", "nearest_po2", "pingpong", "posmod", "pow", "print", "print_rich", "print_verbose",
	"printerr", "printraw", "prints", "printt", "push_error", "push_warning", "rad_to_deg", "rand_from_seed",
	"randf", "randf_range", "randfn", "randi", "randi_range", "randomize", "remap", "rid_allocate_id",
	"rid_from_int64", "rotate", "rotated", "round", "roundf", "roundi", "seed", "sign", "signf", "signi",
	"sin", "sinh", "smoothstep", "snapped", "snappedf", "snappedi", "sqrt", "step_decimals", "str",
	"str_to_var", "tan", "tanh", "type_convert", "type_string", "typeof", "var_to_bytes", "var_to_bytes_with_objects",
	"var_to_str", "weakref", "wrap", "wrapf", "wrapi",

	# Control/CanvasItem methods
	"accept_event", "grab_click_focus", "grab_focus", "has_focus", "release_focus", "set_anchors_and_offsets_preset",
	"set_anchors_preset", "set_begin", "set_default_cursor_shape", "set_drag_forwarding", "set_drag_preview",
	"set_end", "set_focus_mode", "set_focus_neighbor", "set_focus_next", "set_focus_previous",
	"set_global_position", "set_offsets_preset", "set_position", "set_size", "warp_mouse",
	"draw_arc", "draw_char", "draw_circle", "draw_colored_polygon", "draw_line", "draw_mesh",
	"draw_multiline", "draw_multiline_colors", "draw_multimesh", "draw_polygon", "draw_polyline",
	"draw_polyline_colors", "draw_primitive", "draw_rect", "draw_set_transform", "draw_set_transform_matrix",
	"draw_string", "draw_string_outline", "draw_style_box", "draw_texture", "draw_texture_rect",
	"force_update_transform", "get_canvas", "get_canvas_item", "get_canvas_transform", "get_global_mouse_position",
	"get_global_transform", "get_global_transform_with_canvas", "get_local_mouse_position", "get_screen_transform",
	"get_transform", "get_viewport_rect", "get_viewport_transform", "get_visibility_layer_bit",
	"hide", "is_local_transform_notification_enabled", "is_transform_notification_enabled", "is_visible",
	"is_visible_in_tree", "make_canvas_position_local", "make_input_local", "queue_redraw", "set_clip_children_mode",
	"set_modulate", "set_notify_local_transform", "set_notify_transform", "set_self_modulate",
	"set_visibility_layer", "set_visibility_layer_bit", "set_visible", "show",

	# Common utility methods
	"bind", "unbind", "get_bound_arguments", "get_bound_arguments_count", "get_method", "get_object",
	"get_object_id", "is_custom", "is_null", "is_standard", "is_valid", "call_deferred",

	# File/Directory methods
	"file_exists", "open", "open_encrypted", "open_encrypted_with_pass", "open_compressed", "close",
	"get_path_absolute", "get_as_text", "get_buffer", "get_csv_line", "get_double", "get_error",
	"get_float", "get_hidden_attribute", "get_length", "get_line", "get_md5", "get_modified_time",
	"get_pascal_string", "get_position", "get_real", "get_sha256", "get_var", "eof_reached",
	"seek", "seek_end", "store_buffer", "store_csv_line", "store_double", "store_float", "store_line",
	"store_pascal_string", "store_real", "store_string", "store_var", "flush",
	"copy", "current_is_dir", "dir_exists", "get_current_dir", "get_current_drive", "get_directories",
	"get_directories_at", "get_drive_count", "get_drive_name", "get_files", "get_files_at", "get_space_left",
	"list_dir_begin", "list_dir_end", "make_dir", "make_dir_absolute", "make_dir_recursive",
	"open", "remove", "remove_absolute", "rename", "rename_absolute"
]

# Comprehensive list of built-in Godot class names
# These should NEVER be obfuscated as they're part of the engine
const _godotBuiltInClasses := [
	# Core variant types
	"Variant", "bool", "int", "float", "String", "Vector2", "Vector2i", "Vector3", "Vector3i",
	"Transform2D", "Vector4", "Vector4i", "Plane", "Quaternion", "AABB", "Basis", "Transform3D",
	"Projection", "Color", "StringName", "NodePath", "RID", "Object", "Callable", "Signal",
	"Dictionary", "Array", "PackedByteArray", "PackedInt32Array", "PackedInt64Array",
	"PackedFloat32Array", "PackedFloat64Array", "PackedStringArray", "PackedVector2Array",
	"PackedVector3Array", "PackedColorArray", "PackedVector4Array", "Rect2", "Rect2i",

	# Core scene tree nodes
	"Node", "Node2D", "Node3D", "CanvasItem", "Control", "Window", "Viewport", "SubViewport",
	"CanvasLayer", "CanvasModulate", "HTTPRequest", "Timer", "ResourcePreloader",

	# UI Control nodes
	"Button", "Label", "LineEdit", "TextEdit", "CodeEdit", "RichTextLabel", "CheckBox", "CheckButton",
	"ColorPicker", "ColorPickerButton", "MenuButton", "MenuBar", "OptionButton", "PopupMenu", "ProgressBar",
	"ScrollBar", "HScrollBar", "VScrollBar", "Slider", "HSlider", "VSlider", "SpinBox", "Range",
	"TextureRect", "VideoStreamPlayer", "LinkButton", "TabBar", "ItemList", "Tree", "FileDialog",
	"AcceptDialog", "ConfirmationDialog", "EditorFileDialog", "Popup", "PopupPanel", "WindowDialog",

	# Container nodes
	"Container", "BoxContainer", "HBoxContainer", "VBoxContainer", "GridContainer", "MarginContainer",
	"PanelContainer", "ScrollContainer", "SplitContainer", "HSplitContainer", "VSplitContainer",
	"TabContainer", "Panel", "ColorRect", "NinePatchRect", "ReferenceRect", "AspectRatioContainer",
	"CenterContainer", "FlowContainer", "HFlowContainer", "VFlowContainer", "GraphNode", "GraphEdit",
	"SubViewportContainer",

	# 2D nodes
	"Sprite2D", "AnimatedSprite2D", "Polygon2D", "Line2D", "MeshInstance2D", "MultiMeshInstance2D",
	"Skeleton2D", "Bone2D", "SkeletonModification2D", "TileMap", "TileMapLayer", "ParallaxBackground", "ParallaxLayer",
	"TouchScreenButton", "Camera2D", "AudioListener2D", "Marker2D", "RemoteTransform2D",
	"VisibleOnScreenNotifier2D", "VisibleOnScreenEnabler2D", "CollisionObject2D", "Area2D",
	"PhysicsBody2D", "StaticBody2D", "AnimatableBody2D", "RigidBody2D", "CharacterBody2D",
	"CollisionShape2D", "CollisionPolygon2D", "RayCast2D", "ShapeCast2D",

	# 3D nodes
	"MeshInstance3D", "CSGMesh3D", "ImmediateMesh", "Sprite3D", "AnimatedSprite3D", "Label3D",
	"Camera3D", "AudioListener3D", "Marker3D", "RemoteTransform3D", "VisibleOnScreenNotifier3D",
	"VisibleOnScreenEnabler3D", "CollisionObject3D", "Area3D", "PhysicsBody3D", "StaticBody3D",
	"AnimatableBody3D", "RigidBody3D", "CharacterBody3D", "CollisionShape3D", "CollisionPolygon3D",
	"RayCast3D", "ShapeCast3D", "DirectionalLight3D", "OmniLight3D", "SpotLight3D",

	# Resource types
	"Resource", "Texture", "Texture2D", "Texture3D", "CompressedTexture2D", "CompressedTexture3D",
	"AtlasTexture", "MeshTexture", "CurveTexture", "CurveXYZTexture", "GradientTexture1D",
	"GradientTexture2D", "AnimatedTexture", "ImageTexture", "PortableCompressedTexture2D",
	"Image", "Font", "FontFile", "FontVariation", "SystemFont", "StyleBox", "StyleBoxEmpty",
	"StyleBoxFlat", "StyleBoxLine", "StyleBoxTexture", "Theme", "Shader", "ShaderInclude",
	"Material", "ShaderMaterial", "CanvasItemMaterial", "ParticleProcessMaterial", "StandardMaterial3D",
	"ORMMaterial3D", "Mesh", "ArrayMesh", "PrimitiveMesh", "BoxMesh", "CapsuleMesh", "CylinderMesh",
	"PlaneMesh", "PrismMesh", "QuadMesh", "SphereMesh", "TorusMesh", "TubeTrailMesh", "RibbonTrailMesh",
	"PackedScene", "Animation", "AnimationLibrary", "AudioStream", "AudioStreamWAV", "AudioStreamOggVorbis",
	"AudioStreamMP3", "BitMap", "Gradient", "Curve", "Curve2D", "Curve3D",

	# Animation/Tween
	"AnimationPlayer", "AnimationTree", "AnimationNodeStateMachine", "Tween", "PropertyTweener",
	"IntervalTweener", "CallbackTweener", "MethodTweener",

	# Audio
	"AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D",

	# Other common nodes/classes
	"MultiplayerSpawner", "MultiplayerSynchronizer", "NavigationAgent2D", "NavigationAgent3D",
	"Path2D", "PathFollow2D", "Path3D", "PathFollow3D", "CPUParticles2D", "CPUParticles3D",
	"GPUParticles2D", "GPUParticles3D", "Joint2D", "PinJoint2D", "GrooveJoint2D", "DampedSpringJoint2D",
	"Joint3D", "PinJoint3D", "HingeJoint3D", "SliderJoint3D", "ConeTwistJoint3D", "Generic6DOFJoint3D",

	# System/Utility classes
	"FileAccess", "DirAccess", "JSON", "XMLParser", "ConfigFile", "RegEx", "RegExMatch",
	"Thread", "Mutex", "Semaphore", "IP", "StreamPeer", "StreamPeerBuffer", "StreamPeerTCP",
	"PacketPeer", "PacketPeerUDP", "UDPServer", "TCPServer", "WebSocketPeer",
	"JavaScriptBridge", "JavaScriptObject", "Engine", "OS", "Time", "Performance", "ProjectSettings",
	"EditorSettings", "SceneTree", "MultiplayerAPI", "MultiplayerPeer", "Input", "InputEvent",
	"InputEventAction", "InputEventKey", "InputEventMouse", "InputEventMouseButton", "InputEventMouseMotion",
	"RandomNumberGenerator", "Marshalls", "ClassDB", "ResourceLoader", "ResourceSaver"
]

static func ObfuscateScripts(inputDir: String, outputDir: String, isObfuscatingFunctions : bool, isObfuscatingVariables : bool, isObfuscatingComments : bool):
	_inputDir = inputDir
	_outputDir = outputDir
	_isObfuscatingFunctions = isObfuscatingFunctions
	_isObfuscatingVariables = isObfuscatingVariables
	_isObfuscatingComments = isObfuscatingComments

	if inputDir == "":
		OS.alert("Invalid input directory for obfuscation. Please specify a valid directory containing a Godot project.")
		return -1

	if outputDir == "":
		OS.alert("Invalid output directory for obfuscation. Please specify a directory outside of your project.")
		return -1

	if not DirAccess.dir_exists_absolute(_inputDir):
		printerr("Input directory does not exist: ", _inputDir)
		return -1

	if not DirAccess.dir_exists_absolute(_outputDir):
		var created := DirAccess.make_dir_recursive_absolute(_outputDir)
		if created != OK:
			printerr("Failed to create output directory: ", _outputDir)
			return -1

	var autoloads = GetAutoloadGlobalNames()
	ObfuscateDirectory(_inputDir, autoloads)
	return OK

static func SetFunctionExcludeList(excludeList: Array[String]) -> void:
	_functionExcludeList = excludeList

static func SetVariableExcludeList(excludeList: Array[String]) -> void:
	_variableExcludeList = excludeList

static func SetExternalPluginClasses(classList: Array[String]) -> void:
	_externalPluginClasses = classList

# Extracts enum values from code and adds them to exclusion list
# Enum values should never be obfuscated as they're runtime constants
static func AddEnumValuesToExcludeList(content: String) -> void:
	var regex := RegEx.new()
	# Match: enum EnumName { ... } or enum { ... }
	regex.compile(r"enum\s+\w*\s*\{([^}]+)\}")

	for match in regex.search_all(content):
		var enum_body = match.get_string(1)

		# Extract individual enum values (handle VALUE = 5, VALUE, etc.)
		var value_regex := RegEx.new()
		# Match enum value names, optionally followed by = and a number
		value_regex.compile(r"\b(\w+)(?:\s*=\s*[^,}]+)?")

		for value_match in value_regex.search_all(enum_body):
			var enum_value_name = value_match.get_string(1)
			if enum_value_name not in _enumValueExcludeList:
				_enumValueExcludeList.append(enum_value_name)

# Extracts signal names from code and adds them to exclusion list
# Signal names should never be obfuscated as they're referenced by name at runtime
static func AddSignalNamesToExcludeList(content: String) -> void:
	var regex := RegEx.new()
	# Match: signal signal_name or signal signal_name(arg1, arg2)
	regex.compile(r"\bsignal\s+(\w+)")

	for match in regex.search_all(content):
		var sig_name = match.get_string(1)
		if sig_name not in _signalExcludeList:
			_signalExcludeList.append(sig_name)

# Extracts class_name declarations from code and adds them to exclusion list
# User-defined class names should be excluded as they're used in type hints and extends
static func AddClassNamesToExcludeList(content: String) -> void:
	var regex := RegEx.new()
	# Match: class_name ClassName or class_name ClassName extends Parent
	regex.compile(r"\bclass_name\s+(\w+)")

	for match in regex.search_all(content):
		var cls_name = match.get_string(1)
		if cls_name not in _classNameExcludeList:
			_classNameExcludeList.append(cls_name)

# Generates a random name ensuring we haven't
# used the name before.
static func GenerateObfuscatedName()  -> String:
	var chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	while true:
		var obfuscatedName := ""
		for i in range(8):
			obfuscatedName += chars[randi() % chars.length()]
			
		if not _usedNames.has(obfuscatedName):
			_usedNames[obfuscatedName] = true
			return obfuscatedName
	
	return ""

static func ApplyBasicObfuscation(contentPayload : ContentPayload , globalObfuscationMap: Dictionary) -> void:
	for obfuscationKey in globalObfuscationMap.keys():
		contentPayload.SetContent(ReplacePattern(contentPayload.GetContent(), obfuscationKey, globalObfuscationMap[obfuscationKey]))

static func ReplacePattern(content: String, obfuscationKey: String, globalObfuscationMap: Dictionary) -> String:
	var pattern := RegEx.new()
	pattern.compile("\\b" + obfuscationKey + "\\b")

	var matches := pattern.search_all(content)
	if matches.is_empty():
		return content

	var result := ""
	var lastIndex := 0

	for match in matches:
		if _exportVariableNames.find(obfuscationKey) > -1:
			continue
			
		var start := match.get_start()
		var end := match.get_end()
		var replacement = GetObfuscationReplacement(content, obfuscationKey, globalObfuscationMap, start, end)
		result += content.substr(lastIndex, start - lastIndex)
		result += replacement
		lastIndex = end

	result += content.substr(lastIndex)
	return result

static func GetObfuscationReplacement(content: String, symbol: String, globalObfuscationMap: Dictionary, start: int, end: int) -> String:
	var before := content.substr(max(start - 20, 0), start - max(start - 20, 0))
	# var after := content.substr(end, 10)

	var prevChar := ""
	if start > 0:
		prevChar = content.substr(start - 1, 1)
		
	var nextChar := content.substr(end, 1)

	# Saving for future consideration.
	#if symbolMap.kind == "type":
		#if before.match(":\\s*$") or before.match("as\\s+$"):
			#return symbol  # Don't replace in type context
		#else:
			#return symbol  # Unknown context, skip for safety
			
	if _isObfuscatingFunctions && globalObfuscationMap.kind == "function":
		if FindFunctionSymbol(before, prevChar, nextChar, content, end):
			return globalObfuscationMap.replacement
		else:
			return symbol
	elif _isObfuscatingVariables && globalObfuscationMap.kind == "variable":
		# Check if we are obfuscating inside an @export declaration
		if before.contains("@export var"):
			_exportVariableNames.append(symbol)
			return symbol

		# Don't obfuscate property access (dot notation)
		# Example: json.data - 'data' here is a property, not our local variable
		if prevChar == ".":
			return symbol

		return globalObfuscationMap.replacement

	return symbol

static func FindFunctionSymbol(before, prevChar, nextChar, content: String, end: int):
	var regex := RegEx.new()

	# Match function declaration: "func MyFunction("
	regex.compile('^(static\\s+)?func\\s*$')
	if regex.search(before):
		return true

	# Match function call: "MyFunction(" or ".MyFunction("
	if nextChar == "(" or (prevChar == "." and nextChar == "("):
		return true

	# Match callable reference passed as argument: "function)" or "obj.function)" or "Class.StaticMethod)"
	# Examples: sort_custom(my_sort), signal.connect(my_function), sort_custom(CommonHelper.SortAscending)
	if nextChar == ")" or nextChar == ",":
		return true

	# Match Callable methods: "MyFunction.bind(", "MyFunction.unbind(", etc.
	if nextChar == ".":
		# Look ahead to see what comes after the dot
		var after_dot = content.substr(end + 1, 10)
		if after_dot.begins_with("bind(") or after_dot.begins_with("unbind(") or \
		   after_dot.begins_with("call(") or after_dot.begins_with("callv("):
			return true

	# Detect has_method() and all call() variants (string-based reflection - should NOT obfuscate)
	regex.compile('.*\\.(?:has_method|call(?:_deferred|_thread_safe|v)?)\\s*\\(\\s*\\"')
	return !!regex.search(before)
	
static func ObfuscateDirectory(path: String, autoloads : Array) -> void:
	var fileFilters := ["gd"]
	var filteredFiles := FileHelper.GetFilesRecursive(path, fileFilters)
	var globalObfuscationMap := BuildGlobalObfuscationMap(filteredFiles)
	ObfuscateAllFiles(filteredFiles, globalObfuscationMap, autoloads)

	# Also process .tscn files to update signal connection method references
	# ONLY if function obfuscation is enabled (otherwise scene files call non-existent obfuscated methods)
	var sceneFilters := ["tscn"]
	var sceneFiles := FileHelper.GetFilesRecursive(path, sceneFilters)

	if _isObfuscatingFunctions:
		# Function obfuscation enabled: Update scene file method references to match obfuscated names
		ObfuscateSceneFiles(sceneFiles, globalObfuscationMap)
	else:
		# Function obfuscation disabled: Copy scene files as-is to preserve original method names
		for scenePath in sceneFiles:
			var content := FileAccess.get_file_as_string(scenePath)
			if content == null or content == "":
				continue

			var relativePath: String = scenePath.replace(_inputDir, "")
			var outputPath: String = _outputDir + relativePath
			var outputDir: String = outputPath.get_base_dir()
			DirAccess.make_dir_recursive_absolute(outputDir)

			var file := FileAccess.open(outputPath, FileAccess.WRITE)
			if file:
				file.store_string(content)
				file.close()
			else:
				printerr("Failed to copy scene file: ", outputPath)

# Pass 1: Build global obfuscation map
static func BuildGlobalObfuscationMap(allFiles) -> Dictionary:
	var obfuscationMap : Dictionary = {}

	# Clear exclusion lists to avoid stale values from previous runs
	_enumValueExcludeList.clear()
	_signalExcludeList.clear()
	_classNameExcludeList.clear()

	# First pass: Extract ALL special symbols from ALL files before building symbol map
	# This ensures enum values, signals, and class names are in exclude lists before processing
	for fullPath in allFiles:
		var content := FileAccess.get_file_as_string(fullPath)
		AddEnumValuesToExcludeList(content)
		AddSignalNamesToExcludeList(content)
		AddClassNamesToExcludeList(content)

	# Second pass: Build symbol map (functions and variables)
	for fullPath in allFiles:
		var content := FileAccess.get_file_as_string(fullPath)
		BuildSymbolMap(content, obfuscationMap)

		for symbolName in obfuscationMap.keys():
			var kind = obfuscationMap[symbolName].get("kind")
			var replacement = GenerateObfuscatedName()

			obfuscationMap[symbolName] = {
				"kind": kind,
				"replacement": replacement
			}

	return obfuscationMap
				
static func PreserveStringLiterals(contentPayload : ContentPayload) -> void:
	var stringRegex := RegEx.new()
	stringRegex.compile(r'"([^"\\]|\\.)*"')
	var stringMatches := stringRegex.search_all(contentPayload.GetContent())

	var preservedStrings := {}

	# IMPORTANT NOTE: This replaces all string literals with
	# a temporary token so we don't obfuscate them.
	var index := 0
	for match in stringMatches:
		var key = "__STRING_TOKEN_" + str(index) + "__"
		preservedStrings[key] = match.get_string()
		contentPayload.SetContent(contentPayload.GetContent().replace(match.get_string(), key))
		index += 1

	contentPayload.SetPreservedStrings(preservedStrings)
	
# Put preserved strings back in
static func RestoreStringLiterals(contentPayload : ContentPayload) -> void:
	for key in contentPayload.GetPreservedStrings().keys():
		contentPayload.SetContent(contentPayload.GetContent().replace(key, contentPayload.GetPreservedStrings()[key]))

# Put special preserved strings back in
static func RestoreSpecialStrings(contentPayload : ContentPayload) -> void:
	for key in contentPayload.GetPreservedSpecialStrings().keys():
		contentPayload.SetContent(contentPayload.GetContent().replace(key, contentPayload.GetPreservedSpecialStrings()[key]))

# Note: Supports has_method and all call() variants.
static func PreserveSpecialStrings(contentPayload : ContentPayload) -> void:
	var stringRegex := RegEx.new()
	stringRegex.compile(r'(?:has_method|call(?:_deferred|_thread_safe|v)?)\s*\(\s*"([^"\\]*)"\s*')
	var stringMatches := stringRegex.search_all(contentPayload.GetContent())

	var preservedStrings := {}

	# IMPORTANT NOTE: This replaces all string literals with
	# a temporary token so we don't obfuscate them.
	var index := 0
	for match in stringMatches:
		var key = "__SPECIAL_STRING_TOKEN_" + str(index) + "__"
		preservedStrings[key] = match.get_string()
		contentPayload.SetContent(contentPayload.GetContent().replace(match.get_string(), key))
		index += 1
	
	contentPayload.SetPreservedSpecialStrings(preservedStrings)
	
# Pass #2: Obfuscate all files with global map
static func ObfuscateAllFiles(allFiles : Array, globalObfuscationMap : Dictionary, _autoloads : Array):
	for fullPath in allFiles:
		var fileContents := FileAccess.get_file_as_string(fullPath)
		var contentPayload := ContentPayload.new()
		contentPayload.SetContent(fileContents)
		PreserveSpecialStrings(contentPayload)
		PreserveStringLiterals(contentPayload)
		
		# We need these strings to be replaced as function names
		RestoreSpecialStrings(contentPayload)

		# Reset export var tracking per file. Anytime
		# we come across and @export var, we need to ignore
		# all other matches in the same file.
		_exportVariableNames.clear()
		
		# Obfuscate Functions and Variables
		ApplyBasicObfuscation(contentPayload, globalObfuscationMap)
		
		RestoreStringLiterals(contentPayload)
		
		# Removes all comments from the project
		if _isObfuscatingComments:
			RemoveCommentsFromCode(contentPayload)
		
		# Future obfuscations that are in development:
		# ObfuscateSignals(contentPayload, autoloads)
		# Minify(contentPayload)
		
		var relativePath = fullPath.replace(_inputDir, "")
		var outputPath = _outputDir + relativePath
		var outputDir = outputPath.get_base_dir()
		DirAccess.make_dir_recursive_absolute(outputDir)

		var file := FileAccess.open(outputPath, FileAccess.WRITE)
		if file:
			file.store_string(contentPayload.GetContent())
			file.close()
		else:
			printerr("Failed to open file for writing: ", outputPath)

# Process .tscn scene files to update method references in signal connections
static func ObfuscateSceneFiles(sceneFiles: Array, globalObfuscationMap: Dictionary) -> void:
	for fullPath in sceneFiles:
		var fileContents := FileAccess.get_file_as_string(fullPath)
		if fileContents == null or fileContents == "":
			continue

		var modified := false
		var lines := fileContents.split("\n")
		var result := ""

		for line in lines:
			var newLine := line

			# Find signal connection lines: [connection signal="..." from="..." to="..." method="method_name"]
			if line.begins_with("[connection "):
				var methodRegex := RegEx.new()
				# Match method="method_name" - capture the method name
				methodRegex.compile('method="([^"]+)"')
				var match := methodRegex.search(line)

				if match:
					var methodName := match.get_string(1)

					# Check if this method is in our obfuscation map
					if globalObfuscationMap.has(methodName):
						var obfuscatedMethod: String = globalObfuscationMap[methodName].get("replacement", "")
						if obfuscatedMethod != "":
							# Replace the method name in the connection line
							newLine = line.replace('method="' + methodName + '"', 'method="' + obfuscatedMethod + '"')
							modified = true

			result += newLine + "\n"

		# Write modified scene file to output directory
		if modified:
			var relativePath: String = fullPath.replace(_inputDir, "")
			var outputPath: String = _outputDir + relativePath
			var outputDir: String = outputPath.get_base_dir()
			DirAccess.make_dir_recursive_absolute(outputDir)

			var file := FileAccess.open(outputPath, FileAccess.WRITE)
			if file:
				file.store_string(result.trim_suffix("\n"))  # Remove trailing newline
				file.close()
			else:
				printerr("Failed to write scene file: ", outputPath)
		else:
			# No modifications needed - copy file as-is
			var relativePath: String = fullPath.replace(_inputDir, "")
			var outputPath: String = _outputDir + relativePath
			var outputDir: String = outputPath.get_base_dir()
			DirAccess.make_dir_recursive_absolute(outputDir)

			var file := FileAccess.open(outputPath, FileAccess.WRITE)
			if file:
				file.store_string(fileContents)
				file.close()
			else:
				printerr("Failed to copy scene file: ", outputPath)

static func RemoveCommentsFromCode(contentPayload: ContentPayload) -> void:
	var result := ""
	var in_string := false
	var current_string_char := ""
	var lines := contentPayload.GetContent().split("\n")
	
	for line in lines:
		var new_line := ""
		var i := 0
		while i < line.length():
			var current_char := line[i]

			if not in_string and (current_char == '"' or current_char == "'"):
				in_string = true
				current_string_char = current_char
			elif in_string and current_char == current_string_char:
				in_string = false

			if not in_string and current_char == "#":
				break  # Stop at comment start if not in string

			new_line += current_char
			i += 1
		
		result += new_line.rstrip("") + "\n"
	
	contentPayload.SetContent(result)

# TODO: 
# Need to handle globals (which look just like locals). Wondering
# if I can detect globals in project file and then match any
# <globalName>.connect or <globalName>.emit_signal.
# May take multiple passes
static func ObfuscateSignals(_contentPayload: ContentPayload, _autoloads : Array) -> void:
	pass

static func GetAutoloadGlobalNames() -> Array:
	var globals := []
	var config := ConfigFile.new()
	var err := config.load(_inputDir + "\\project.godot")
	if err != OK:
		OS.alert("Failed to load globals from project.godot. Did you rename it?")
		return []
	
	if config.has_section("autoload"):
		for global_name in config.get_section_keys("autoload"):
			globals.append(global_name)
	
	return globals

# TODO: This one is a challenge. So many things require preserving
# white-space. I think it will be insanely busy.
# This is a very simple tokenizer-style minifier. 
# It may not work correctly for complex syntax like
# multiline strings, comments inside strings, etc. 
# Use with caution or refine as needed.
static func Minify(_contentPayload: ContentPayload) -> void:
	return
	#var lines = contentPayload.GetContent().split("\n")
	#var result := ""
	#var lastLine = ""
#
	#for line in lines:
		#var trimmed = line.strip_edges()
		#if trimmed.begins_with("#") or trimmed == "":
			#continue
#
		#trimmed = CollapseOperatorWhitespace(trimmed)
#
		## Force newline after inline match clause
		#if "match " in trimmed and ":" in trimmed:
			#var match_split := RegExMatchReplace(trimmed, r"(match\s+[^\:]+:)", "$1\n")
			#for split_line in match_split.split("\n"):
				#if lastLine != "":
					#result += "\n" + split_line
				#else:
					#result += split_line
				#lastLine = split_line
			#continue
#
		#if lastLine != "":
			#if lastLine.ends_with("):") or lastLine.ends_with(":"):
				#result += " " + trimmed
			#elif trimmed.begins_with("extends") or trimmed.begins_with("class_name") or trimmed.begins_with("func") or trimmed.begins_with("static func"):
				#result += "\n" + trimmed
			#elif trimmed.begins_with("if ") or trimmed.begins_with("for ") or trimmed.begins_with("while ") or trimmed.begins_with("match "):
				#result += "\n" + trimmed
			#elif " static func" in trimmed:
				#result += "\n" + trimmed
			#else:
				#result += ";" + trimmed
		#else:
			#result += trimmed
#
		#lastLine = trimmed
#
	#contentPayload.SetContent(result)


static func CollapseOperatorWhitespace(line: String) -> String:
	var replacements = [
		[r"\s*:=\s*", ":="],
		[r"\s*=\s*", "="],
		[r"\s*:\s*", ":"],
		[r"\s*,\s*", ","],
		[r"\s*\(\s*", "("],
		[r"\s*\)\s*", ")"],
		[r"\s*\[\s*", "["],
		[r"\s*\]\s*", "]"],
		[r"\s*\+\s*", "+"],
		[r"\s*-\s*", "-"],
		[r"\s*/\s*", "/"],
		[r"\s*\*\s*", "*"]
	]
	
	for pattern in replacements:
		line = RegExMatchReplace(line, pattern[0], pattern[1])
		
	return line

static func RegExMatchReplace(text: String, pattern: String, replacement: String) -> String:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex.sub(text, replacement, true)
	
static func BuildSymbolMap(content : String, symbolMap : Dictionary) -> void:
	# Extract special symbols from this content to ensure they're excluded
	# NOTE: BuildGlobalObfuscationMap() does a first pass to extract from ALL files,
	# but this ensures BuildSymbolMap() is self-contained for testing and direct usage
	AddEnumValuesToExcludeList(content)
	AddSignalNamesToExcludeList(content)
	AddClassNamesToExcludeList(content)

	# Build symbol map (functions and variables) - excludes symbols in exclusion lists
	AddFunctionsToSymbolMap(content, symbolMap)
	AddVariablesToSymbolMap(content, symbolMap)
	
static func AddFunctionsToSymbolMap(content: String, symbolMap) -> void:
	# Function declarations (including static)
	var regex := RegEx.new()
	regex.compile(r"(?:static\s+)?func\s+(\w+)\s*\(")
	for match in regex.search_all(content):
		var symbolName = match.get_string(1)

		# Don't add dupe symbolNames
		if symbolMap.has(symbolName):
			continue

		# CRITICAL: Skip Godot lifecycle methods (virtual methods)
		if symbolName in _godotLifecycleMethods:
			continue

		# CRITICAL: Skip built-in Godot methods (Array.size(), String.split(), etc.)
		if symbolName in _godotBuiltInMethods:
			continue

		# Skip user-excluded functions
		if symbolName in _functionExcludeList:
			continue

		# Skip enum values (in case an enum value name matches a function name)
		if symbolName in _enumValueExcludeList:
			continue

		# Skip signal names (in case a signal name matches a function name)
		if symbolName in _signalExcludeList:
			continue

		# Skip class names (in case a class name matches a function name)
		if symbolName in _classNameExcludeList:
			continue

		# Add to symbol map - will be obfuscated (including user-defined private functions)
		symbolMap[symbolName] = { "kind": "function" }

	# Saving for future consideration
	# Type references
	#regex = RegEx.new()
	#regex.compile(r"(?::|as)\s+(\w+)")
	#for match in regex.search_all(content):
		#var symbolName = match.get_string(1)
		#if symbolName in _godotReservedKeywords:
			#continue
		#if not map.has(symbolName):
			#map[symbolName] = { "kind": "type" }

static func AddVariablesToSymbolMap(content : String, symbolMap : Dictionary):
	var lines := content.split("\n")
	for line in lines:
		line = line.strip_edges()
		var regex := RegEx.new()
		regex.compile(r"\bvar\s+(\w+)")
		var match = regex.search(line)
		if match:
			var symbolName = match.get_string(1)
			if symbolMap.has(symbolName):
				continue

			# CRITICAL: Skip built-in Godot class names (Array, Node, Control, etc.)
			if symbolName in _godotBuiltInClasses:
				continue

			# CRITICAL: Skip built-in Godot methods (size, append, has, etc.)
			if symbolName in _godotBuiltInMethods:
				continue

			# CRITICAL: Skip external plugin classes (SQLite, SupabaseAPI, etc.)
			if symbolName in _externalPluginClasses:
				continue

			# Skip user-excluded variables
			if symbolName in _variableExcludeList:
				continue

			# Skip enum values
			if symbolName in _enumValueExcludeList:
				continue

			# Skip signal names (in case a signal name is used as a variable name)
			if symbolName in _signalExcludeList:
				continue

			# Skip class names (in case a class name is used as a variable name)
			if symbolName in _classNameExcludeList:
				continue

			symbolMap[symbolName] = { "kind": "variable" }

# Example of how you might test locally if needed.
static func GetTestContent() -> String:
	return """
	func Run():
		pass

	func _internal():
		pass

	func GetCurrentTipId():
		pass
		
	func Whatever():
		if TipManager.GetCurrentTipId() == 5:
			pass
		
	func GravSkimmer(param: int) -> void:
		pass

	var _gravSkimmer : GravSkimmer = null
	"""
