extends RefCounted

var framework: TestFramework

var Cli = preload("res://scripts/obfuscate-cli.gd")

# --- _parse_csv tests ---

func test_parse_csv_basic():
	var result = Cli._parse_csv("alpha,beta,gamma")
	framework.assert_equal(result.size(), 3, "Should parse 3 items")
	framework.assert_equal(result[0], "alpha", "First item")
	framework.assert_equal(result[1], "beta", "Second item")
	framework.assert_equal(result[2], "gamma", "Third item")

func test_parse_csv_with_spaces():
	var result = Cli._parse_csv("  alpha , beta ,  gamma  ")
	framework.assert_equal(result.size(), 3, "Should parse 3 items with spaces trimmed")
	framework.assert_equal(result[0], "alpha", "First item trimmed")
	framework.assert_equal(result[1], "beta", "Second item trimmed")
	framework.assert_equal(result[2], "gamma", "Third item trimmed")

func test_parse_csv_empty_string():
	var result = Cli._parse_csv("")
	framework.assert_equal(result.size(), 0, "Empty string should return empty array")

func test_parse_csv_whitespace_only():
	var result = Cli._parse_csv("   ")
	framework.assert_equal(result.size(), 0, "Whitespace-only should return empty array")

func test_parse_csv_single_item():
	var result = Cli._parse_csv("only_one")
	framework.assert_equal(result.size(), 1, "Single item")
	framework.assert_equal(result[0], "only_one", "Should return the single item")

func test_parse_csv_skips_empty_entries():
	var result = Cli._parse_csv("alpha,,beta,,,gamma")
	framework.assert_equal(result.size(), 3, "Should skip empty entries between commas")

# --- _parse_args tests ---

func test_parse_args_key_value():
	var args = PackedStringArray(["--project-dir", "/some/path", "--output", "/out/path"])
	var result = Cli._parse_args(args)
	framework.assert_equal(result.get("project-dir", ""), "/some/path", "Should parse project-dir")
	framework.assert_equal(result.get("output", ""), "/out/path", "Should parse output")

func test_parse_args_equals_syntax():
	var args = PackedStringArray(["--config=/my/config.cfg"])
	var result = Cli._parse_args(args)
	framework.assert_equal(result.get("config", ""), "/my/config.cfg", "Should parse --key=value syntax")

func test_parse_args_boolean_flags():
	var args = PackedStringArray(["--functions", "--no-comments", "--help"])
	var result = Cli._parse_args(args)
	framework.assert_true(result.get("functions", false), "Should set functions to true")
	framework.assert_true(result.get("no-comments", false), "Should set no-comments to true")
	framework.assert_true(result.get("help", false), "Should set help to true")

func test_parse_args_empty():
	var args = PackedStringArray([])
	var result = Cli._parse_args(args)
	framework.assert_equal(result.size(), 0, "Empty args should return empty dictionary")

# --- _resolve_flag tests ---

func test_resolve_flag_explicit_true():
	var args = {"functions": true}
	var result = Cli._resolve_flag(args, "functions", false)
	framework.assert_true(result, "Explicit --functions should override config default of false")

func test_resolve_flag_explicit_no():
	var args = {"no-functions": true}
	var result = Cli._resolve_flag(args, "functions", true)
	framework.assert_false(result, "--no-functions should override config default of true")

func test_resolve_flag_falls_back_to_config():
	var args = {}
	var result_true = Cli._resolve_flag(args, "functions", true)
	var result_false = Cli._resolve_flag(args, "functions", false)
	framework.assert_true(result_true, "Should fall back to config default true")
	framework.assert_false(result_false, "Should fall back to config default false")

# --- _load_config tests ---

func test_load_config_empty_path():
	var result = Cli._load_config("")
	framework.assert_equal(result.size(), 0, "Empty path should return empty dictionary")

func test_load_config_missing_file():
	var result = Cli._load_config("/nonexistent/path/obfuscation.cfg")
	framework.assert_equal(result.size(), 0, "Missing file should return empty dictionary")

# --- skip-addons flag tests ---

func test_parse_args_skip_addons_flag():
	var args = PackedStringArray(["--skip-addons"])
	var result = Cli._parse_args(args)
	framework.assert_true(result.get("skip-addons", false), "Should parse --skip-addons as true")

func test_parse_args_no_skip_addons_flag():
	var args = PackedStringArray(["--no-skip-addons"])
	var result = Cli._parse_args(args)
	framework.assert_true(result.get("no-skip-addons", false), "Should parse --no-skip-addons as true")

func test_resolve_skip_addons_defaults_true():
	var args = {}
	var result = Cli._resolve_flag(args, "skip-addons", true)
	framework.assert_true(result, "skip-addons should default to true")
