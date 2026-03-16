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
static var _isObfuscatingFunctions := false
static var _isObfuscatingVariables := false
static var _isObfuscatingComments := false
static var _functionExcludeList : Array[String] = []
static var _variableExcludeList : Array[String] = []
static var _enumValueExcludeList : Array[String] = []
static var _signalExcludeList : Array[String] = []  # Auto-detected signal names
static var _classNameExcludeList : Array[String] = []  # Auto-detected class_name declarations
static var _externalPluginClasses : Array[String] = []  # User-configured external plugin class names
static var _isInliningConstants := false
static var _constantMap : Dictionary = {}  # original_name -> literal_value
static var _constantExcludeList : Array[String] = []
static var _skipDirectories : Array[String] = []
static var _dotAccessedProperties : Dictionary = {}  # Properties accessed via obj.property across files
static var _isInjectingDeadCode := false
static var _isEncryptingStrings := false
static var _encryptionKey : PackedByteArray = []
static var _extraBuiltInMethods : Array[String] = []

# GDScript reserved keywords — must NEVER be obfuscated or inlined
const _gdscriptReservedKeywords := [
	"if", "elif", "else", "for", "while", "match", "break", "continue",
	"pass", "return", "class", "class_name", "extends", "is", "in", "as",
	"self", "signal", "func", "static", "const", "enum", "var", "breakpoint",
	"preload", "await", "yield", "assert", "void", "PI", "TAU", "INF", "NAN",
	"and", "or", "not", "true", "false", "null", "super", "when",
	"int", "float", "bool", "String",
]

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

	# Object methods and properties (base class - VERY common)
	"script",  # Object.script — not always in ClassDB but used in every .tscn file
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
	"open", "remove", "remove_absolute", "rename", "rename_absolute",

	# JSON methods
	"parse", "stringify", "get_data", "get_error_line", "get_error_message", "get_parsed_text",

	# PopupMenu / ItemList / Tree methods
	"add_item", "add_icon_item", "add_check_item", "add_radio_check_item", "add_submenu_item",
	"add_separator", "get_item_count", "get_item_text", "get_item_id", "set_item_text",
	"set_item_checked", "set_item_disabled", "set_item_icon", "set_item_metadata",
	"get_item_metadata", "is_item_checked", "is_item_disabled", "clear_items",
	"get_selected_items", "select", "deselect", "deselect_all", "is_selected",

	# HTTPRequest methods
	"request", "cancel_request", "get_body_size", "get_downloaded_bytes",
	"set_download_file", "set_use_threads",

	# Tween methods
	"tween_property", "tween_method", "tween_callback", "tween_interval",
	"set_ease", "set_trans", "set_parallel", "set_loops", "set_speed_scale",
	"chain", "parallel", "finished",

	# Timer methods
	"start", "stop", "is_stopped", "get_time_left",

	# Crypto/Hash methods
	"update", "finish", "hmac_digest",

	# GDScript global functions
	"range", "preload", "load", "assert", "type_string", "typeof",

	# Common Node/Control properties used as assignments (e.g. name = "X")
	"name", "visible", "modulate", "position", "rotation", "scale", "offset",
	"text", "icon", "tooltip_text", "placeholder_text", "theme",
	"title", "color", "size_flags_horizontal", "size_flags_vertical",
	"custom_minimum_size", "anchors_preset", "mouse_filter",

	# OS / Engine methods
	"execute", "kill", "shell_open", "get_executable_path", "get_environment",
	"get_user_data_dir", "get_data_dir", "get_config_dir", "get_cache_dir",

	# TLSOptions / network factory methods
	"client", "server", "client_unsafe",

	# Common patterns: singleton/factory
	"get_instance", "instance", "new",

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

static var _runtimeBuiltInMethods: Dictionary = {}
static var _runtimeBuiltInClasses: Dictionary = {}
static var _runtimeBuiltInProperties: Dictionary = {}

# Build comprehensive built-in name sets from ClassDB at runtime
# This supplements the manual lists with every method/property/class the engine knows about
static func BuildBuiltInSetsFromClassDB() -> void:
	if not _runtimeBuiltInMethods.is_empty():
		return  # Already built

	for class_name_str in ClassDB.get_class_list():
		_runtimeBuiltInClasses[class_name_str] = true

		for method_info in ClassDB.class_get_method_list(class_name_str, true):
			var method_name = method_info["name"]
			if method_name.length() > 2:
				_runtimeBuiltInMethods[method_name] = true

		for prop_info in ClassDB.class_get_property_list(class_name_str, true):
			var prop_name = prop_info["name"]
			if prop_name.length() > 2 and not "/" in prop_name:
				_runtimeBuiltInProperties[prop_name] = true

	for signal_info_class in ClassDB.get_class_list():
		for signal_info in ClassDB.class_get_signal_list(signal_info_class, true):
			var signal_name = signal_info["name"]
			if signal_name.length() > 2:
				_runtimeBuiltInMethods[signal_name] = true

static func IsBuiltInMethod(symbolName: String) -> bool:
	return symbolName in _godotBuiltInMethods or _runtimeBuiltInMethods.has(symbolName) or _runtimeBuiltInProperties.has(symbolName) or symbolName in _extraBuiltInMethods

static func IsBuiltInClass(symbolName: String) -> bool:
	return symbolName in _godotBuiltInClasses or _runtimeBuiltInClasses.has(symbolName)

static func ObfuscateScripts(inputDir: String, outputDir: String, isObfuscatingFunctions : bool, isObfuscatingVariables : bool, isObfuscatingComments : bool, isInliningConstants := false, isInjectingDeadCode := false, isEncryptingStrings := false):
	_inputDir = inputDir
	_outputDir = outputDir
	_isObfuscatingFunctions = isObfuscatingFunctions
	_isObfuscatingVariables = isObfuscatingVariables
	_isObfuscatingComments = isObfuscatingComments
	_isInliningConstants = isInliningConstants
	_isInjectingDeadCode = isInjectingDeadCode
	_isEncryptingStrings = isEncryptingStrings
	if _isEncryptingStrings:
		_encryptionKey = GenerateEncryptionKey()

	# Build runtime built-in sets from ClassDB (first call only)
	BuildBuiltInSetsFromClassDB()

	if inputDir == "":
		printerr("Invalid input directory for obfuscation. Please specify a valid directory containing a Godot project.")
		return -1

	if outputDir == "":
		printerr("Invalid output directory for obfuscation. Please specify a directory outside of your project.")
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

static func SetConstantExcludeList(excludeList: Array[String]) -> void:
	_constantExcludeList = excludeList

static func SetSkipDirectories(dirs: Array[String]) -> void:
	_skipDirectories = dirs

static func SetExtraBuiltInMethods(methods: Array[String]) -> void:
	_extraBuiltInMethods = methods

# Extracts enum type names and values from code and adds them to exclusion list
# Enum type names and values should never be obfuscated as they're runtime constants
static func AddEnumValuesToExcludeList(content: String) -> void:
	var regex := RegEx.new()
	# Match: enum EnumName { ... } or enum { ... }
	# Capture group 1 = enum type name (optional), capture group 2 = enum body
	regex.compile(r"enum\s+(\w+)?\s*\{([^}]+)\}")

	for match in regex.search_all(content):
		# Extract enum type name (if present) and add to exclusion list
		var enum_name = match.get_string(1)
		if enum_name != "" and enum_name not in _enumValueExcludeList:
			_enumValueExcludeList.append(enum_name)

		var enum_body = match.get_string(2)

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

static var _currentFileLocalNames: Array[String] = []

# Extract function parameter names and local variable names from inside function bodies
# These should not be replaced by the global map when they collide with function names
static func ExtractLocalNames(content: String) -> Array[String]:
	var local_names: Array[String] = []
	var in_func := false
	var func_param_regex := RegEx.new()
	func_param_regex.compile(r"(?:static\s+)?func\s+\w+\s*\(([^)]*)\)")
	var local_var_regex := RegEx.new()
	local_var_regex.compile(r"^\t+var\s+(\w+)")
	var class_var_regex := RegEx.new()
	class_var_regex.compile(r"^var\s+(\w+)")

	for line in content.split("\n"):
		var stripped := line.strip_edges()

		# Detect class-level variable declarations (no indent)
		# These prevent function-name collisions from replacing class vars
		var class_var_match = class_var_regex.search(line)
		if class_var_match and not in_func:
			local_names.append(class_var_match.get_string(1))

		# Detect function start — extract parameter names
		var func_match = func_param_regex.search(line)
		if func_match:
			in_func = true
			var params_str = func_match.get_string(1)
			for param in params_str.split(","):
				param = param.strip_edges()
				# Extract name before : or = or end
				var name_regex := RegEx.new()
				name_regex.compile(r"^(\w+)")
				var name_match = name_regex.search(param)
				if name_match:
					local_names.append(name_match.get_string(1))

		# Detect local variables (indented var declarations inside functions)
		if in_func:
			var local_match = local_var_regex.search(line)
			if local_match:
				local_names.append(local_match.get_string(1))

		# Detect function end (next top-level line that isn't blank/comment)
		if in_func and not line.begins_with("\t") and not line.begins_with(" ") and stripped != "" and not stripped.begins_with("#"):
			if not func_match:  # Don't end on the func line itself
				in_func = false

	return local_names

static func ApplyBasicObfuscation(contentPayload : ContentPayload , globalObfuscationMap: Dictionary) -> void:
	for obfuscationKey in globalObfuscationMap.keys():
		# Skip replacement if this name is a local variable/parameter in the current file
		# AND the global map has it as a function (name collision between func and local var)
		if obfuscationKey in _currentFileLocalNames and globalObfuscationMap[obfuscationKey].get("kind") == "function":
			# Local variable shadows a global function name — only replace dot-prefixed method calls
			# e.g. .query() is replaced but "var query =" is not
			contentPayload.SetContent(ReplacePattern(contentPayload.GetContent(), obfuscationKey, globalObfuscationMap[obfuscationKey], true))
			continue
		contentPayload.SetContent(ReplacePattern(contentPayload.GetContent(), obfuscationKey, globalObfuscationMap[obfuscationKey]))

static func ReplacePattern(content: String, obfuscationKey: String, globalObfuscationMap: Dictionary, dotCallOnly: bool = false) -> String:
	var pattern := RegEx.new()
	pattern.compile("\\b" + obfuscationKey + "\\b")

	var matches := pattern.search_all(content)
	if matches.is_empty():
		return content

	var result := ""
	var lastIndex := 0

	for match in matches:
		var start := match.get_start()
		var end := match.get_end()
		var replacement = GetObfuscationReplacement(content, obfuscationKey, globalObfuscationMap, start, end, dotCallOnly)
		result += content.substr(lastIndex, start - lastIndex)
		result += replacement
		lastIndex = end

	result += content.substr(lastIndex)
	return result

static func GetObfuscationReplacement(content: String, symbol: String, globalObfuscationMap: Dictionary, start: int, end: int, dotCallOnly: bool = false) -> String:
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
		# In dot-call-only mode, skip replacements where the symbol is NOT preceded by "."
		# This prevents renaming local variables that shadow a global function name
		if dotCallOnly and prevChar != ".":
			return symbol
		if FindFunctionSymbol(before, prevChar, nextChar, content, start, end):
			return globalObfuscationMap.replacement
		else:
			return symbol
	elif _isObfuscatingVariables && globalObfuscationMap.kind == "variable":
		# Don't obfuscate property access (dot notation)
		# Example: json.data - 'data' here is a property, not our local variable
		if prevChar == ".":
			return symbol

		return globalObfuscationMap.replacement

	return symbol

static func FindFunctionSymbol(before, prevChar, nextChar, content: String, start: int, end: int):
	var regex := RegEx.new()

	# Match function declaration: "func MyFunction("
	regex.compile('^(static\\s+)?func\\s*$')
	if regex.search(before):
		return true

	# Match function call: "MyFunction(" or ".MyFunction("
	if nextChar == "(" or (prevChar == "." and nextChar == "("):
		return true

	# Match callable reference passed as argument: "function)" or "obj.function)"
	# Examples: sort_custom(my_sort), signal.connect(my_function), sort_custom(CommonHelper.SortAscending)
	# Only match if preceded by ( or , inside a function call — NOT inside [] arrays or % format args
	if nextChar == ")" or nextChar == ",":
		# Check if we're inside a function call context (preceded by "(" or "word(")
		# vs an array literal [...], dictionary {...}, or format string % [...]
		var context_before := content.substr(max(start - 100, 0), start - max(start - 100, 0))
		# Find the most recent unmatched ( or [ to determine context
		var paren_depth := 0
		var bracket_depth := 0
		var in_func_call := false
		for ci in range(context_before.length() - 1, -1, -1):
			var ch = context_before[ci]
			if ch == ")": paren_depth += 1
			elif ch == "(":
				if paren_depth > 0:
					paren_depth -= 1
				else:
					in_func_call = true
					break
			elif ch == "]": bracket_depth += 1
			elif ch == "[":
				if bracket_depth > 0:
					bracket_depth -= 1
				else:
					in_func_call = false  # Inside array literal
					break
		if in_func_call:
			return true

	# Match Callable methods: "MyFunction.bind(", "MyFunction.call_deferred(", etc.
	if nextChar == ".":
		# Look ahead to see what comes after the dot
		var after_dot = content.substr(end + 1, 20)
		if after_dot.begins_with("bind(") or after_dot.begins_with("unbind(") or \
		   after_dot.begins_with("call(") or after_dot.begins_with("callv(") or \
		   after_dot.begins_with("call_deferred(") or after_dot.begins_with("call_thread_safe("):
			return true

	# Match callable assignment: "callback = my_function" where next is }, \n, or ,
	# This handles dictionary callable values like {callback = my_func}
	if nextChar == "}" or nextChar == "\n" or nextChar == "\r" or nextChar == "":
		regex.compile('=\\s*$')
		if regex.search(before):
			return true

	# Detect has_method() and all call() variants — obfuscate method name inside string
	# Supports both obj.call_deferred("method") and bare call_deferred("method")
	regex.compile('\\.?(?:has_method|call(?:_deferred|_thread_safe|v)?)\\s*\\(\\s*\\"')
	return !!regex.search(before)
	
# Extracts const declarations with literal values (numbers, booleans) from code
# Skips string consts, preload/load consts, and expression consts (e.g. MAX * 2)
static func ExtractConstantsFromContent(content: String) -> Dictionary:
	var constants := {}
	var regex := RegEx.new()
	# Match: const NAME = value  or  const NAME: Type = value  or  const NAME := value
	regex.compile(r"const\s+(\w+)\s*(?::\s*\w+)?\s*:?=\s*(.+)")

	for match in regex.search_all(content):
		var const_name := match.get_string(1)
		var const_value := match.get_string(2).strip_edges()

		# Skip if in exclude list
		if const_name in _constantExcludeList:
			continue

		# Skip GDScript reserved keywords
		if const_name in _gdscriptReservedKeywords:
			continue

		# Skip built-in Godot class names (e.g. const Vector2 = 0 in test files)
		if IsBuiltInClass(const_name):
			continue

		# Only inline literal values: integers, floats, booleans
		# Skip strings, preload(), load(), expressions with operators
		if const_value.begins_with('"') or const_value.begins_with("'"):
			continue
		if const_value.begins_with("preload(") or const_value.begins_with("load("):
			continue
		# Skip expressions (contain operators or function calls beyond simple literals)
		if "+" in const_value or "-" in const_value or "*" in const_value or "/" in const_value:
			# Allow negative numbers like -1, -3.14
			var is_negative_number := const_value.begins_with("-") and not " " in const_value
			if not is_negative_number:
				continue
		if "(" in const_value:
			continue

		# Validate it's a literal: int, float, or bool
		if const_value == "true" or const_value == "false":
			constants[const_name] = const_value
		elif const_value.is_valid_int() or const_value.is_valid_float():
			constants[const_name] = const_value
		elif const_value.begins_with("-"):
			var positive := const_value.substr(1)
			if positive.is_valid_int() or positive.is_valid_float():
				constants[const_name] = const_value

	return constants

# Extracts enum values with their computed ordinal indices
# Returns dictionary: { "EnumName.VALUE": "ordinal", "VALUE": "ordinal" }
static func ExtractEnumValuesWithIndices(content: String) -> Dictionary:
	var result := {}
	var regex := RegEx.new()
	regex.compile(r"enum\s+(\w+)?\s*\{([^}]+)\}")

	for match in regex.search_all(content):
		var enum_name := match.get_string(1)  # May be empty for anonymous enums
		var enum_body := match.get_string(2)

		var value_regex := RegEx.new()
		value_regex.compile(r"\b(\w+)(?:\s*=\s*([^,}]+))?")

		var current_ordinal := 0
		for value_match in value_regex.search_all(enum_body):
			var val_name := value_match.get_string(1)
			var explicit_val := value_match.get_string(2).strip_edges()

			# Skip if in exclude list
			if val_name in _constantExcludeList:
				current_ordinal += 1
				continue

			# Skip GDScript reserved keywords
			if val_name in _gdscriptReservedKeywords:
				current_ordinal += 1
				continue

			if explicit_val != "" and explicit_val.is_valid_int():
				current_ordinal = explicit_val.to_int()

			var ordinal_str := str(current_ordinal)

			# Add qualified reference: EnumName.VALUE -> ordinal
			if enum_name != "":
				result[enum_name + "." + val_name] = ordinal_str
			else:
				# Skip built-in Godot class names for anonymous enums only
				# (bare keys like "JSON" would collide with the built-in class)
				if IsBuiltInClass(val_name):
					current_ordinal += 1
					continue
				# Only add bare references for anonymous enums (no qualified form available)
				# Named enum values are too likely to collide with unrelated identifiers
				# (class names, signal params, keywords) when replaced globally
				result[val_name] = ordinal_str

			current_ordinal += 1

	return result

# Replaces constant and enum references with their literal values
# Processes qualified references (State.IDLE) before bare references (IDLE) to avoid State.0
static func InlineConstants(contentPayload: ContentPayload) -> void:
	var content := contentPayload.GetContent()

	# Sort keys: qualified (containing ".") first, then bare names
	var qualified_keys := []
	var bare_keys := []
	for key in _constantMap.keys():
		if "." in key:
			qualified_keys.append(key)
		else:
			bare_keys.append(key)

	# Replace qualified references first (e.g. State.IDLE -> 0)
	for key in qualified_keys:
		var parts = key.split(".")
		var pattern := RegEx.new()
		# Match EnumName.VALUE as whole word boundary on both sides
		pattern.compile("\\b" + parts[0] + "\\." + parts[1] + "\\b")
		# Process matches individually to skip deeper qualified refs (e.g. ClassName.EnumName.VALUE)
		var q_matches := pattern.search_all(content)
		if q_matches.is_empty():
			continue
		var q_result := content
		for qi in range(q_matches.size() - 1, -1, -1):
			var qm = q_matches[qi]
			# Skip if preceded by "." (deeper qualified reference like ClassName.EnumName.VALUE)
			if qm.get_start() > 0 and content[qm.get_start() - 1] == ".":
				continue
			q_result = q_result.substr(0, qm.get_start()) + _constantMap[key] + q_result.substr(qm.get_end())
		content = q_result

	# Replace bare references (e.g. MAX_SPEED -> 100, IDLE -> 0)
	for key in bare_keys:
		# Skip reserved keywords that may have entered the constant map
		if key in _gdscriptReservedKeywords:
			continue

		var pattern := RegEx.new()
		pattern.compile("\\b" + key + "\\b")

		var matches := pattern.search_all(content)
		if matches.is_empty():
			continue

		# Process matches in reverse to preserve indices
		var _content_array := content.split("")
		var _result_parts := []
		var _last_end := content.length()

		# Collect matches and filter out declaration-site references
		var valid_replacements := []
		for m in matches:
			var start := m.get_start()
			# Skip if this is part of a const declaration or enum definition
			var line_start := content.rfind("\n", start)
			if line_start == -1:
				line_start = 0
			else:
				line_start += 1
			var line := content.substr(line_start, start - line_start)

			# Skip const declaration lines and enum body lines
			# Use lstrip to preserve trailing content (strip_edges removes trailing space before name)
			var trimmed_line := line.lstrip(" \t")
			if trimmed_line.begins_with("const ") or trimmed_line == "const":
				continue
			if trimmed_line.begins_with("enum ") or trimmed_line == "enum":
				continue
			# Skip signal declarations (parameter names must not be replaced)
			if trimmed_line.begins_with("signal "):
				continue
			# Skip function signatures (parameter names must not be replaced)
			if trimmed_line.begins_with("func ") or trimmed_line.begins_with("static func "):
				continue
			# Skip if preceded by dot (qualified reference - already handled)
			if start > 0 and content[start - 1] == ".":
				continue

			valid_replacements.append(m)

		# Apply replacements in reverse order
		var result := content
		for i in range(valid_replacements.size() - 1, -1, -1):
			var m = valid_replacements[i]
			result = result.substr(0, m.get_start()) + _constantMap[key] + result.substr(m.get_end())

		content = result

	contentPayload.SetContent(content)

# Removes const declaration lines from code
# Enum blocks are kept intact — they define types that may be referenced cross-file
static func RemoveConstantDeclarations(contentPayload: ContentPayload) -> void:
	var content := contentPayload.GetContent()

	# Don't remove constants from files with class_name — they may be referenced
	# cross-file as ClassName.CONSTANT and removing them would break those references
	var class_name_regex := RegEx.new()
	class_name_regex.compile(r"(?m)^\s*class_name\s+\w+")
	if class_name_regex.search(content):
		return

	var lines := content.split("\n")
	var result_lines := []

	# First pass: find constants still referenced in un-inlineable contexts
	# (function default params, annotations, etc.)
	var still_referenced := {}
	for line in lines:
		var stripped := line.strip_edges()
		if stripped.begins_with("const "):
			continue
		# Only check function signatures (default parameter values can't be inlined)
		if stripped.begins_with("func ") or stripped.begins_with("static func "):
			for const_name in _constantMap.keys():
				if const_name in stripped:
					still_referenced[const_name] = true

	for line in lines:
		var stripped := line.strip_edges()

		# Remove const lines with literal values (only those we inlined)
		# BUT keep constants that are still referenced (e.g. in default parameter values)
		if stripped.begins_with("const "):
			var const_regex := RegEx.new()
			const_regex.compile(r"const\s+(\w+)")
			var match := const_regex.search(stripped)
			if match:
				var const_name := match.get_string(1)
				if _constantMap.has(const_name) and not still_referenced.has(const_name):
					continue  # Safe to remove — fully inlined

		result_lines.append(line)

	contentPayload.SetContent("\n".join(result_lines))

static func ObfuscateDirectory(path: String, autoloads : Array) -> void:
	var fileFilters := ["gd"]
	var filteredFiles := FileHelper.GetFilesRecursive(path, fileFilters, _skipDirectories)
	var globalObfuscationMap := BuildGlobalObfuscationMap(filteredFiles)
	ObfuscateAllFiles(filteredFiles, globalObfuscationMap, autoloads)

	# Also process .tscn files to update signal connection method references
	# ONLY if function obfuscation is enabled (otherwise scene files call non-existent obfuscated methods)
	var sceneFilters := ["tscn"]
	var sceneFiles := FileHelper.GetFilesRecursive(path, sceneFilters, _skipDirectories)

	if _isObfuscatingFunctions or _isObfuscatingVariables:
		# Function/variable obfuscation enabled: Update scene file references to match obfuscated names
		ObfuscateSceneFiles(sceneFiles, globalObfuscationMap)
	else:
		# No function/variable obfuscation: Copy scene files as-is to preserve original names
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
	_constantMap.clear()
	_dotAccessedProperties.clear()

	# First pass: Extract ALL special symbols from ALL files before building symbol map
	# This ensures enum values, signals, and class names are in exclude lists before processing
	for fullPath in allFiles:
		var content := FileAccess.get_file_as_string(fullPath)
		AddEnumValuesToExcludeList(content)
		AddSignalNamesToExcludeList(content)
		AddClassNamesToExcludeList(content)
		_extract_dot_accessed_properties(content)

	# Constant extraction pass: Build global constant map from all files
	if _isInliningConstants:
		for fullPath in allFiles:
			var content := FileAccess.get_file_as_string(fullPath)
			var file_constants := ExtractConstantsFromContent(content)
			_constantMap.merge(file_constants)
			var enum_constants := ExtractEnumValuesWithIndices(content)
			_constantMap.merge(enum_constants)

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

	# Prune inlined constant/enum names from symbol map so they aren't renamed
	if _isInliningConstants:
		for const_name in _constantMap.keys():
			if obfuscationMap.has(const_name):
				obfuscationMap.erase(const_name)

	return obfuscationMap
				
static func PreserveStringLiterals(contentPayload : ContentPayload) -> void:
	var stringRegex := RegEx.new()
	# Match triple-quoted strings first (""" and '''), then regular strings (" and ')
	# Order matters: triple-quoted must be tried before regular to avoid partial matches
	var triple_dq := "\"\"\"[\\s\\S]*?\"\"\""
	var triple_sq := "'''[\\s\\S]*?'''"
	var regular_dq := "\"([^\"\\\\\\n]|\\\\.)*\""
	var regular_sq := "'([^'\\\\\\n]|\\\\.)*'"
	stringRegex.compile(triple_dq + "|" + triple_sq + "|" + regular_dq + "|" + regular_sq)
	var stringMatches := stringRegex.search_all(contentPayload.GetContent())

	var preservedStrings := {}

	# Replace string literals with tokens using position-based replacement (last to first).
	# CRITICAL: Cannot use .replace() here because it does global substring matching,
	# which corrupts triple-quoted strings when "" (empty string) is replaced first.
	var content := contentPayload.GetContent()
	for i in range(stringMatches.size() - 1, -1, -1):
		var m = stringMatches[i]
		var key = "__STRING_TOKEN_" + str(i) + "__"
		preservedStrings[key] = m.get_string()
		content = content.substr(0, m.get_start()) + key + content.substr(m.get_end())
	contentPayload.SetContent(content)

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
	# Match string args that reference symbol names:
	# - call("method"), call_deferred("method"), has_method("method") — 1st arg
	# - tween_property(obj, "property", ...), tween_method(obj, "method", ...) — 2nd arg
	stringRegex.compile(r'(?:has_method|call(?:_deferred|_thread_safe|v)?)\s*\(\s*"([^"\\]*)"|(?:tween_property|tween_method)\s*\([^,]*,\s*"([^"\\]*)"')
	var stringMatches := stringRegex.search_all(contentPayload.GetContent())

	var preservedStrings := {}

	# Position-based replacement (last to first) to avoid .replace() substring issues
	var content := contentPayload.GetContent()
	for i in range(stringMatches.size() - 1, -1, -1):
		var m = stringMatches[i]
		var key = "__SPECIAL_STRING_TOKEN_" + str(i) + "__"
		preservedStrings[key] = m.get_string()
		content = content.substr(0, m.get_start()) + key + content.substr(m.get_end())
	contentPayload.SetContent(content)

	contentPayload.SetPreservedSpecialStrings(preservedStrings)
	
# Pass #2: Obfuscate all files with global map
static func ObfuscateAllFiles(allFiles : Array, globalObfuscationMap : Dictionary, _autoloads : Array):
	for fullPath in allFiles:
		var fileContents := FileAccess.get_file_as_string(fullPath)
		var contentPayload := ContentPayload.new()
		contentPayload.SetContent(fileContents)

		# Strip comments FIRST — prevents apostrophes in comments (e.g. "doesn't")
		# from being matched by single-quote string regex and consuming code blocks
		if _isObfuscatingComments:
			RemoveCommentsFromCode(contentPayload)

		PreserveSpecialStrings(contentPayload)
		PreserveStringLiterals(contentPayload)

		# We need these strings to be replaced as function names
		RestoreSpecialStrings(contentPayload)

		# Constant inlining runs BEFORE symbol obfuscation
		# so the obfuscator doesn't try to rename inlined-away names
		if _isInliningConstants:
			InlineConstants(contentPayload)
			RemoveConstantDeclarations(contentPayload)

		# Extract local names (function params + local vars) to prevent
		# collision with global function names of the same name
		_currentFileLocalNames = ExtractLocalNames(fileContents)

		# Obfuscate Functions and Variables
		ApplyBasicObfuscation(contentPayload, globalObfuscationMap)

		RestoreStringLiterals(contentPayload)

		# Dead code injection: append fake functions at end of file
		# Note: Inline call injection (InjectDeadCodeCalls) is disabled — it causes
		# runtime issues with drag-drop and potentially other signal-driven code paths
		# in Godot, even though the injected branches are provably unreachable.
		# The appended dead functions still add decompilation noise effectively.
		if _isInjectingDeadCode:
			var varNames := _get_obfuscated_names_by_kind(globalObfuscationMap, "variable")
			var result := GenerateDeadFunctions(varNames, randi_range(5, 10))
			contentPayload.SetContent(contentPayload.GetContent() + "\n" + result.code)

		# String encryption: replace string literals with XOR-encrypted equivalents
		if _isEncryptingStrings:
			EncryptStringLiterals(contentPayload)

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

			# Property assignment lines in [node] and [sub_resource] sections
			# Format: "property_name = value" (no leading whitespace, no [ prefix)
			# Renames @export variable properties to match obfuscated names in .gd files
			elif _isObfuscatingVariables and not line.begins_with("[") and not line.is_empty():
				var eq_pos := line.find(" = ")
				if eq_pos > 0:
					var prop_name := line.substr(0, eq_pos).strip_edges()
					# Skip path-based properties (theme_override_*, metadata/*, etc.)
					if "/" not in prop_name and globalObfuscationMap.has(prop_name):
						var entry: Dictionary = globalObfuscationMap[prop_name]
						if entry.get("kind") == "variable":
							var obfuscated: String = entry.get("replacement", "")
							if obfuscated != "":
								newLine = obfuscated + line.substr(eq_pos)
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

# Processes scene file content in-memory — replaces signal method names and variable property names
# Returns the modified content (or original if no changes needed)
static func ObfuscateSceneContent(sceneContent: String, globalObfuscationMap: Dictionary) -> String:
	var lines := sceneContent.split("\n")
	var result := ""

	for line in lines:
		var newLine := line

		# Signal connection lines
		if line.begins_with("[connection "):
			var methodRegex := RegEx.new()
			methodRegex.compile('method="([^"]+)"')
			var match := methodRegex.search(line)
			if match:
				var methodName := match.get_string(1)
				if globalObfuscationMap.has(methodName):
					var obfuscatedMethod: String = globalObfuscationMap[methodName].get("replacement", "")
					if obfuscatedMethod != "":
						newLine = line.replace('method="' + methodName + '"', 'method="' + obfuscatedMethod + '"')

		# Property assignment lines (variable obfuscation)
		elif _isObfuscatingVariables and not line.begins_with("[") and not line.is_empty():
			var eq_pos := line.find(" = ")
			if eq_pos > 0:
				var prop_name := line.substr(0, eq_pos).strip_edges()
				if "/" not in prop_name and globalObfuscationMap.has(prop_name):
					var entry: Dictionary = globalObfuscationMap[prop_name]
					if entry.get("kind") == "variable":
						var obfuscated: String = entry.get("replacement", "")
						if obfuscated != "":
							newLine = obfuscated + line.substr(eq_pos)

		result += newLine + "\n"

	return result.trim_suffix("\n")

static func RemoveCommentsFromCode(contentPayload: ContentPayload) -> void:
	var content := contentPayload.GetContent()
	var result := ""
	var i := 0
	var in_string := false
	var string_char := ""
	var in_triple := false

	while i < content.length():
		var ch := content[i]

		# Handle triple-quoted strings (""" or ''')
		if not in_string and i + 2 < content.length():
			var triple := content.substr(i, 3)
			if triple == '"""' or triple == "'''":
				in_string = true
				in_triple = true
				string_char = ch
				result += triple
				i += 3
				continue

		# Close triple-quoted string
		if in_triple and i + 2 < content.length():
			var triple := content.substr(i, 3)
			if triple == string_char + string_char + string_char:
				in_string = false
				in_triple = false
				result += triple
				i += 3
				continue

		# Handle escape sequences inside strings
		if in_string and ch == "\\" and i + 1 < content.length():
			result += ch + content[i + 1]
			i += 2
			continue

		# Handle regular string open/close
		if not in_string and not in_triple and (ch == '"' or ch == "'"):
			in_string = true
			string_char = ch
		elif in_string and not in_triple and ch == string_char:
			in_string = false

		# Strip comments (# to end of line) when not in a string
		if not in_string and ch == "#":
			# Skip to end of line
			while i < content.length() and content[i] != "\n":
				i += 1
			continue

		result += ch
		i += 1

	contentPayload.SetContent(result)

# --- Dead Code Injection + Opaque Predicates ---

# Extracts obfuscated replacement names from the global map filtered by kind
static func _get_obfuscated_names_by_kind(globalMap: Dictionary, kind: String) -> Array:
	var names := []
	for key in globalMap:
		if globalMap[key].get("kind", "") == kind and globalMap[key].has("replacement"):
			names.append(globalMap[key]["replacement"])
	return names

# Generates an opaque predicate (always-true or always-false condition)
static func GenerateOpaquePredicate(variables: Array, want_true: bool = true) -> String:
	var v: String
	if variables.size() > 0:
		v = variables[randi() % variables.size()]
	else:
		v = str(randi_range(2, 99))

	if want_true:
		var templates := [
			"((%s * %s) >= 0)",
			"((%s * (%s + 1)) %% 2 == 0)",
			"((%s | %s | 1) != 0)",
		]
		var t: String = templates[randi() % templates.size()]
		return t % [v, v]
	else:
		var templates := [
			"((%s * %s) < 0)",
			"((%s * %s + 1) < 0)",
		]
		var t: String = templates[randi() % templates.size()]
		return t % [v, v]

# Generates fake functions that blend in with obfuscated code
# All dead code uses int types to guarantee type-safe math operations
# Returns { "code": String, "names": Array }
static func GenerateDeadFunctions(_realVariables: Array, count: int) -> Dictionary:
	var code := ""
	var names := []

	for i in range(count):
		var funcName := GenerateObfuscatedName()
		names.append(funcName)

		var returnType: String = ["int", "void"][randi() % 2]

		code += "\nstatic func %s() -> %s:\n" % [funcName, returnType]

		# Generate 2-4 lines of plausible body
		var bodyLines := randi_range(2, 4)
		var localVarName := GenerateObfuscatedName()

		# First line: declare a local int variable
		code += "\tvar %s: int = %d\n" % [localVarName, randi_range(-100, 100)]

		# Middle lines: int-safe operations
		var intVars: Array = [localVarName]

		for _j in range(bodyLines - 1):
			match randi_range(0, 3):
				0:
					var predicate := GenerateOpaquePredicate(intVars, true)
					code += "\tif %s:\n" % predicate
					code += "\t\t%s = %s\n" % [localVarName, _dead_code_expression(intVars, localVarName)]
				1:
					var tmpName := GenerateObfuscatedName()
					code += "\tvar %s: int = %s\n" % [tmpName, _dead_code_expression(intVars, localVarName)]
					intVars.append(tmpName)
				2:
					code += "\t%s = %s\n" % [localVarName, _dead_code_expression(intVars, localVarName)]
				3:
					var predicate := GenerateOpaquePredicate(intVars, false)
					code += "\tif %s:\n" % predicate
					code += "\t\tpass\n"

		# Return line
		if returnType == "void":
			code += "\tpass\n"
		else:
			code += "\treturn %s\n" % localVarName

	return { "code": code, "names": names }

# Generates a plausible expression for dead code bodies
static func _dead_code_expression(paramNames: Array, localVar: String) -> String:
	var v: String
	if paramNames.size() > 0:
		v = paramNames[randi() % paramNames.size()]
	else:
		v = localVar

	var expressions := [
		"%s + %d" % [v, randi_range(1, 50)],
		"%s - %d" % [v, randi_range(1, 50)],
		"%s * %d" % [v, randi_range(2, 10)],
		"abs(%s)" % v,
		"%s" % str(randi_range(-100, 100)),
	]
	return expressions[randi() % expressions.size()]

# Injects unreachable calls to dead functions into existing function bodies
# Tracks brace/paren/bracket depth to avoid injecting inside multi-line expressions
static func InjectDeadCodeCalls(contentPayload: ContentPayload, deadFuncNames: Array, _variables: Array) -> void:
	if deadFuncNames.is_empty():
		return

	var lines := contentPayload.GetContent().split("\n")
	var result := PackedStringArray()
	var in_func := false
	var func_line_count := 0
	var deadFuncIndex := 0
	var expr_depth := 0  # Tracks nested (, [, { depth
	var in_match := false  # Inside a match block
	var match_indent := 0  # Indentation level of the match statement

	for i in range(lines.size()):
		var line: String = lines[i]
		result.append(line)

		var stripped := line.strip_edges()

		# Track expression depth across all lines
		for ch in stripped:
			if ch == "(" or ch == "[" or ch == "{":
				expr_depth += 1
			elif ch == ")" or ch == "]" or ch == "}":
				expr_depth = max(expr_depth - 1, 0)

		# Track backslash line continuations
		if stripped.ends_with("\\"):
			expr_depth = max(expr_depth, 1)  # Force depth > 0 for continuation lines

		# Track match blocks
		if stripped.begins_with("match ") and stripped.ends_with(":"):
			in_match = true
			var tabs := 0
			for ch in line:
				if ch == "\t":
					tabs += 1
				else:
					break
			match_indent = tabs

		# Detect function start
		if stripped.begins_with("func ") or stripped.begins_with("static func "):
			in_func = true
			func_line_count = 0
			expr_depth = 0
			in_match = false
			continue

		if in_func:
			# End of function: non-empty line with no indentation
			if stripped != "" and not line.begins_with("\t") and not line.begins_with(" "):
				in_func = false
				func_line_count = 0
				expr_depth = 0
				in_match = false
				continue

			# Detect end of match block (line at same or lesser indent than match)
			if in_match and stripped != "":
				var tabs := 0
				for ch in line:
					if ch == "\t":
						tabs += 1
					else:
						break
				if tabs <= match_indent and not stripped.begins_with("match "):
					in_match = false

			func_line_count += 1

			# Never inject inside multi-line expressions or match blocks
			if expr_depth > 0 or in_match:
				continue

			# Skip empty lines, comments, block openers
			if stripped == "" or stripped.begins_with("#") or stripped.ends_with(":"):
				continue

			# Inject approximately every 15 lines, matching the current line's indent
			if func_line_count > 0 and func_line_count % 15 == 0:
				# Use the current line's indentation level
				var currentIndent := ""
				for ch in line:
					if ch == "\t":
						currentIndent += "\t"
					else:
						break
				var literal := str(randi_range(2, 99))
				var predicate := GenerateOpaquePredicate([literal], false)
				var deadFunc: String = deadFuncNames[deadFuncIndex % deadFuncNames.size()]
				deadFuncIndex += 1
				result.append(currentIndent + "if %s:" % predicate)
				result.append(currentIndent + "\t%s()" % deadFunc)

	contentPayload.SetContent("\n".join(result))

# --- String Encryption ---

# Generates a random encryption key
static func GenerateEncryptionKey(length: int = 32) -> PackedByteArray:
	var key := PackedByteArray()
	key.resize(length)
	for i in range(length):
		key[i] = randi() % 256
	return key

# Encrypts string literals in-place, injecting a decrypt helper at the top of the file
static func EncryptStringLiterals(contentPayload: ContentPayload) -> void:
	var content := contentPayload.GetContent()

	# Reuse the same regex from PreserveStringLiterals
	var stringRegex := RegEx.new()
	var triple_dq := "\"\"\"[\\s\\S]*?\"\"\""
	var triple_sq := "'''[\\s\\S]*?'''"
	var regular_dq := "\"([^\"\\\\\\n]|\\\\.)*\""
	var regular_sq := "'([^'\\\\\\n]|\\\\.)*'"
	stringRegex.compile(triple_dq + "|" + triple_sq + "|" + regular_dq + "|" + regular_sq)

	var matches := stringRegex.search_all(content)
	if matches.is_empty():
		return

	var anyEncrypted := false

	# Replace last-to-first to preserve positions
	for i in range(matches.size() - 1, -1, -1):
		var m = matches[i]
		var matchedStr: String = m.get_string()

		if _should_skip_encryption(content, m.get_start(), matchedStr):
			continue

		# Strip quotes to get the raw string content
		var raw: String
		if matchedStr.begins_with('"""') or matchedStr.begins_with("'''"):
			raw = matchedStr.substr(3, matchedStr.length() - 6)
		else:
			raw = matchedStr.substr(1, matchedStr.length() - 2)

		# Handle escape sequences in the raw string
		raw = raw.replace("\\n", "\n").replace("\\t", "\t").replace("\\\\", "\\").replace('\\"', '"').replace("\\'", "'")

		var encrypted := _xor_encrypt(raw, _encryptionKey)
		var byteStrs := []
		for b in encrypted:
			byteStrs.append(str(b))
		var byteStr := ",".join(byteStrs)
		var replacement := "__d(PackedByteArray([%s]))" % byteStr

		content = content.substr(0, m.get_start()) + replacement + content.substr(m.get_end())
		anyEncrypted = true

	if anyEncrypted:
		content = _inject_decrypt_helper(content)

	contentPayload.SetContent(content)

# Determines whether a string match should be skipped for encryption
static func _should_skip_encryption(content: String, matchStart: int, matchedStr: String) -> bool:
	# Strip outer quotes for content check
	var inner: String
	if matchedStr.begins_with('"""') or matchedStr.begins_with("'''"):
		inner = matchedStr.substr(3, matchedStr.length() - 6)
	else:
		inner = matchedStr.substr(1, matchedStr.length() - 2)

	# Skip empty and single-char strings
	if inner.length() <= 1:
		return true

	# Skip resource/user paths
	if inner.begins_with("res://") or inner.begins_with("user://"):
		return true

	# Find the line containing this match
	var lineStart := content.rfind("\n", matchStart)
	if lineStart == -1:
		lineStart = 0
	else:
		lineStart += 1
	var lineEnd := content.find("\n", matchStart)
	if lineEnd == -1:
		lineEnd = content.length()
	var line := content.substr(lineStart, lineEnd - lineStart).strip_edges()

	# Skip const declarations (compile-time literal required)
	# Also check all lines between const start and its closing bracket
	if line.begins_with("const "):
		return true
	# Check if we're inside a multi-line const (scan backwards to find const opener)
	var scanPos := lineStart - 1
	var bracket_depth := 0
	while scanPos >= 0:
		var scanLineEnd := scanPos
		var scanLineStart := content.rfind("\n", scanPos - 1)
		if scanLineStart == -1:
			scanLineStart = 0
		else:
			scanLineStart += 1
		var scanLine := content.substr(scanLineStart, scanLineEnd - scanLineStart + 1).strip_edges()
		# Count brackets on this line
		for ch in scanLine:
			if ch == "[" or ch == "{":
				bracket_depth += 1
			elif ch == "]" or ch == "}":
				bracket_depth -= 1
		if scanLine.begins_with("const "):
			if bracket_depth > 0:
				return true  # Inside a multi-line const
			break
		# Stop scanning at function/class boundaries
		if scanLine.begins_with("func ") or scanLine.begins_with("static func ") or scanLine.begins_with("class ") or scanLine.begins_with("var "):
			break
		scanPos = scanLineStart - 1

	# Skip preload/load (resource paths)
	if "preload(" in line and matchStart > lineStart:
		var before := content.substr(lineStart, matchStart - lineStart)
		if "preload(" in before:
			return true
	if "load(" in line and matchStart > lineStart:
		var before := content.substr(lineStart, matchStart - lineStart)
		if "load(" in before and not "download" in before:
			return true

	# Skip all annotations (compile-time literal required)
	if line.begins_with("@"):
		return true

	# Skip StringName and NodePath literals (&"name" and ^"path")
	if matchStart > 0:
		var charBefore := content[matchStart - 1]
		if charBefore == "&" or charBefore == "^":
			return true

	# Skip default parameter values: func name(param = "default")
	if "func " in line:
		var before := content.substr(lineStart, matchStart - lineStart)
		if "=" in before and "(" in before:
			return true

	# Skip strings in contexts requiring compile-time literals:
	# - Dictionary keys: {"key": value}
	var trimmedLine := line.strip_edges()

	# Skip strings in contexts requiring compile-time literals:
	# - Dictionary keys: {"key": value}
	# - Match arm patterns: "pattern1", "pattern2":
	var afterPos := matchStart + matchedStr.length()
	if afterPos < content.length():
		var afterStr := content.substr(afterPos).strip_edges()
		if afterStr.begins_with(":") and not afterStr.begins_with("://"):
			return true
	# Match arm lines end with : and contain strings — skip all strings on them
	if trimmedLine.ends_with(":") and not trimmedLine.begins_with("var ") and not trimmedLine.begins_with("if ") and not trimmedLine.begins_with("func ") and not trimmedLine.begins_with("static func ") and not trimmedLine.begins_with("for ") and not trimmedLine.begins_with("while ") and not trimmedLine.begins_with("elif "):
		return true

	# Skip standalone string expressions (docstrings / string-only statements)
	if trimmedLine == matchedStr or trimmedLine == matchedStr + ";":
		return true

	return false

# XOR encrypts a string with the given key
static func _xor_encrypt(text: String, key: PackedByteArray) -> PackedByteArray:
	var bytes := text.to_utf8_buffer()
	var result := PackedByteArray()
	result.resize(bytes.size())
	for i in range(bytes.size()):
		result[i] = bytes[i] ^ key[i % key.size()]
	return result

# Builds the decrypt helper code block with a given indentation prefix
static func _build_decrypt_helper(indent: String, keyName: String) -> String:
	var keyBytes := []
	for i in range(_encryptionKey.size()):
		keyBytes.append(str(_encryptionKey[i]))
	var keyStr := ",".join(keyBytes)

	var helper := "\n%sstatic var %s:PackedByteArray=PackedByteArray([%s])\n" % [indent, keyName, keyStr]
	helper += "%sstatic func __d(s:PackedByteArray)->String:\n" % indent
	helper += "%s\tvar r:=PackedByteArray();r.resize(s.size())\n" % indent
	helper += "%s\tfor i in range(s.size()):r[i]=s[i]^%s[i%%%s.size()]\n" % [indent, keyName, keyName]
	helper += "%s\treturn r.get_string_from_utf8()\n" % indent
	return helper

# Injects the decrypt helper at file top and into any nested classes
static func _inject_decrypt_helper(content: String) -> String:
	var keyName := GenerateObfuscatedName()

	var lines := content.split("\n")

	# Find all insertion points: file top + each nested class declaration
	var insertions := []  # Array of [line_index, indent]

	# File top: after extends/class_name/@tool
	var topInsert := 0
	for i in range(min(lines.size(), 10)):
		var stripped := lines[i].strip_edges()
		if stripped.begins_with("extends ") or stripped.begins_with("class_name ") or stripped.begins_with("@tool"):
			topInsert = i + 1
	insertions.append([topInsert, ""])

	# Find nested class declarations and inject helper after extends line
	for i in range(lines.size()):
		var stripped := lines[i].strip_edges()
		if stripped.begins_with("class ") and ":" in stripped:
			# Get the indent of the class body (one level deeper than the class line)
			var classIndent := ""
			for ch in lines[i]:
				if ch == "\t":
					classIndent += "\t"
				else:
					break
			classIndent += "\t"
			# Insert after the class line (or after its extends if on next line)
			var insertAt := i + 1
			if insertAt < lines.size() and lines[insertAt].strip_edges().begins_with("extends "):
				insertAt += 1
			insertions.append([insertAt, classIndent])

	# Insert in reverse order to preserve line numbers
	insertions.reverse()
	for insertion in insertions:
		var helper := _build_decrypt_helper(insertion[1], keyName)
		lines.insert(insertion[0], helper)

	return "\n".join(lines)

# TODO:
# Need to handle globals (which look just like locals). Wondering
# if I can detect globals in project file and then match any
# <globalName>.connect or <globalName>.emit_signal.
# May take multiple passes
static func ObfuscateSignals(_contentPayload: ContentPayload, _autoloads : Array) -> void:
	pass

static func GetAutoloadGlobalNames() -> Array:
	var globals := []
	var project_path := _findProjectGodot(_inputDir)
	if project_path.is_empty():
		return []

	var config := ConfigFile.new()
	var err := config.load(project_path)
	if err != OK:
		printerr("Failed to load project.godot at: " + project_path)
		return []

	if config.has_section("autoload"):
		for global_name in config.get_section_keys("autoload"):
			globals.append(global_name)

	return globals

# Finds project.godot at the given path or in immediate subdirectories
static func _findProjectGodot(dir_path: String) -> String:
	var root_path := dir_path + "/project.godot"
	if FileAccess.file_exists(root_path):
		return root_path

	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var sub_path := dir_path + "/" + entry + "/project.godot"
			if FileAccess.file_exists(sub_path):
				return sub_path
		entry = dir.get_next()
	dir.list_dir_end()
	return ""

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

		# Skip short function names (1-2 chars) — too common, high collision risk
		if symbolName.length() <= 2:
			continue

		# Don't add dupe symbolNames
		if symbolMap.has(symbolName):
			continue

		# CRITICAL: Skip Godot lifecycle methods (virtual methods)
		if symbolName in _godotLifecycleMethods:
			continue

		# CRITICAL: Skip built-in Godot methods (Array.size(), String.split(), etc.)
		if IsBuiltInMethod(symbolName):
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

		# Skip GDScript reserved keywords
		if symbolName in _gdscriptReservedKeywords:
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

			# Skip short variable names (1-2 chars) — too common, high collision risk
			if symbolName.length() <= 2:
				continue

			if symbolMap.has(symbolName):
				continue

			# CRITICAL: Skip built-in Godot class names (Array, Node, Control, etc.)
			if IsBuiltInClass(symbolName):
				continue

			# CRITICAL: Skip built-in Godot methods/properties (size, append, name, etc.)
			if IsBuiltInMethod(symbolName):
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

			# Skip GDScript reserved keywords
			if symbolName in _gdscriptReservedKeywords:
				continue

			# Skip variables accessed via dot notation across files (obj.property)
			# Renaming the declaration would break cross-file property access
			if _dotAccessedProperties.has(symbolName):
				continue

			symbolMap[symbolName] = { "kind": "variable" }

# Extracts property names accessed via dot notation (obj.property_name)
# These must not be obfuscated to avoid breaking cross-file property access
# Only captures property access patterns, NOT method calls (.name( is excluded)
static func _extract_dot_accessed_properties(content: String) -> void:
	var regex := RegEx.new()
	# Match .property_name where NOT followed by ( (which would be a method call)
	# Property name must be 3+ chars and start with lowercase/underscore
	regex.compile(r"\.([a-z_]\w{2,})\b(?!\s*\()")
	for m in regex.search_all(content):
		var prop_name := m.get_string(1)
		_dotAccessedProperties[prop_name] = true

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
