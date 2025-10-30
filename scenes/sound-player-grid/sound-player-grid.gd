extends Control
class_name SoundPlayerGrid

# Grid container for displaying multiple sound players

var _soundPlayerScene = preload("res://scenes/sound-player/sound-player.tscn")
var _licenseDialog: LicenseDialog
var _soundPlayers: Array[SoundPlayer] = []

@onready var _vboxContainer: VBoxContainer = %VBoxContainer

func _ready():
	# Create license dialog
	_licenseDialog = preload("res://scenes/license-dialog/license-dialog.tscn").instantiate()
	add_child(_licenseDialog)
	_licenseDialog.LicenseSaved.connect(_on_license_saved)

	# Customize scrollbar width
	var scroll_container = %ScrollContainer
	var v_scrollbar = scroll_container.get_v_scroll_bar()
	if v_scrollbar:
		v_scrollbar.custom_minimum_size = Vector2(18, 0)  # 1.5x the default ~12px width

func LoadSounds(soundPaths: Array[String]):
	ClearPlayers()

	for soundPath in soundPaths:
		var player = _soundPlayerScene.instantiate() as SoundPlayer
		_vboxContainer.add_child(player)
		player.LoadSound(soundPath)
		player.LicenseRequested.connect(_on_license_requested)
		_soundPlayers.append(player)

func ClearPlayers():
	for player in _soundPlayers:
		player.Cleanup()
		player.queue_free()
	_soundPlayers.clear()

func _on_license_requested(soundPath: String):
	_licenseDialog.ShowDialog(soundPath)

func _on_license_saved(soundPath: String, _licenseText: String):
	# Refresh the license button state for the affected player
	for player in _soundPlayers:
		if player._soundPath == soundPath:
			player.CheckLicenseFile()
			break
