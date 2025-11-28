extends Control
class_name SoundPlayer

# Sound Player component for File Explorer
# Provides playback controls for audio files with license management

signal LicenseRequested(soundPath: String)

var _soundPath: String = ""
var _audioPlayer: AudioStreamPlayer
var _hasLicense: bool = false

@onready var _playButton: Button = %PlayButton
@onready var _loopCheckBox: CheckBox = %LoopCheckBox
@onready var _volumeSlider: HSlider = %VolumeSlider
@onready var _muteButton: Button = %MuteButton
@onready var _pitchSlider: HSlider = %PitchSlider
@onready var _filePathLabel: Label = %FilePathLabel
@onready var _licenseButton: Button = %LicenseButton
@onready var _volumeLabel: Label = %VolumeLabel
@onready var _pitchLabel: Label = %PitchLabel

func _ready():
	# Create audio player
	_audioPlayer = AudioStreamPlayer.new()
	add_child(_audioPlayer)
	_audioPlayer.finished.connect(_on_audio_finished)

	# Connect signals
	_playButton.pressed.connect(_on_play_button_pressed)
	_muteButton.pressed.connect(_on_mute_button_pressed)
	_loopCheckBox.toggled.connect(_on_loop_toggled)
	_volumeSlider.value_changed.connect(_on_volume_changed)
	_pitchSlider.value_changed.connect(_on_pitch_changed)
	_licenseButton.pressed.connect(_on_license_button_pressed)

	# Set initial values
	_volumeSlider.min_value = 0
	_volumeSlider.max_value = 100
	_volumeSlider.value = 100

	_pitchSlider.min_value = 0.5
	_pitchSlider.max_value = 2.0
	_pitchSlider.value = 1.0
	_pitchSlider.step = 0.1

	UpdateVolumeLabel()
	UpdatePitchLabel()

func LoadSound(soundPath: String):
	_soundPath = soundPath
	_filePathLabel.text = soundPath.get_file()
	_filePathLabel.tooltip_text = soundPath

	# Stop current playback
	if _audioPlayer.playing:
		_audioPlayer.stop()

	# Load audio file
	var audioStream = LoadAudioStream(soundPath)
	if audioStream:
		_audioPlayer.stream = audioStream
		_playButton.disabled = false
	else:
		_playButton.disabled = true
		print("Failed to load audio: ", soundPath)

	# Check for license file
	CheckLicenseFile()

func LoadAudioStream(path: String) -> AudioStream:
	var extension = path.get_extension().to_lower()

	# For files within the project, use the resource loader
	if path.begins_with("res://"):
		return load(path) as AudioStream

	# Check if this is a file inside a zip archive
	if "::" in path:
		return LoadAudioStreamFromZip(path, extension)

	# For external files, load from filesystem
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("Failed to open audio file: ", path)
		return null

	var data = file.get_buffer(file.get_length())
	file.close()

	match extension:
		"wav":
			# Use Godot's built-in WAV loader
			return AudioStreamWAV.load_from_file(path)
		"mp3":
			# MP3 uses the data property approach
			var stream = AudioStreamMP3.new()
			stream.data = data
			return stream
		"ogg":
			# OGG Vorbis loader - load_from_file is a static method
			return AudioStreamOggVorbis.load_from_file(path)
		_:
			return null

func LoadAudioStreamFromZip(path: String, extension: String) -> AudioStream:
	# Split the path into zip file and internal path
	var parts = path.split("::")
	if parts.size() != 2:
		print("Invalid zip path format: ", path)
		return null

	var zipPath = parts[0]
	var internalPath = parts[1]

	# Open the zip file
	var zip = ZIPReader.new()
	var error = zip.open(zipPath)
	if error != OK:
		print("Failed to open zip file: ", zipPath, " Error: ", error)
		return null

	# Read the audio file data from zip
	var data = zip.read_file(internalPath)
	zip.close()

	if data.is_empty():
		print("Failed to read file from zip: ", internalPath)
		return null

	# Load audio stream from byte data
	match extension:
		"wav":
			# WAV format requires parsing - create from data
			var stream = AudioStreamWAV.new()
			stream.data = data
			stream.format = AudioStreamWAV.FORMAT_16_BITS  # Default format
			return stream
		"mp3":
			# MP3 uses the data property approach
			var stream = AudioStreamMP3.new()
			stream.data = data
			return stream
		"ogg":
			# OGG Vorbis from packet data
			var stream = AudioStreamOggVorbis.new()
			var packet_sequence = OggPacketSequence.new()
			# This is a simplified approach - may need refinement
			stream.packet_sequence = packet_sequence
			stream.packet_sequence.packet_data = data
			return stream
		_:
			return null

func CheckLicenseFile():
	var licensePath = _soundPath + ".license"
	_hasLicense = FileAccess.file_exists(licensePath)
	UpdateLicenseButton()

func UpdateLicenseButton():
	if _hasLicense:
		_licenseButton.text = "📝"
		_licenseButton.tooltip_text = "Edit License (license file exists)"
	else:
		_licenseButton.text = "📄"
		_licenseButton.tooltip_text = "Add License (no license file)"

func GetLicensePath() -> String:
	return _soundPath + ".license"

func _on_play_button_pressed():
	if _audioPlayer.playing:
		_audioPlayer.stop()
		_playButton.text = "▶"
	else:
		_audioPlayer.play()
		_playButton.text = "⏸"

func _on_audio_finished():
	# If looping is enabled, restart playback
	if _loopCheckBox.button_pressed:
		_audioPlayer.play()
	else:
		_playButton.text = "▶"

func _on_loop_toggled(_toggled: bool):
	# Loop is handled in _on_audio_finished, no need to modify stream properties
	pass

func _on_volume_changed(value: float):
	var db = linear_to_db(value / 100.0)
	_audioPlayer.volume_db = db
	UpdateVolumeLabel()

func _on_pitch_changed(value: float):
	_audioPlayer.pitch_scale = value
	UpdatePitchLabel()

func _on_mute_button_pressed():
	_audioPlayer.volume_db = -80.0 if _audioPlayer.volume_db > -80 else linear_to_db(_volumeSlider.value / 100.0)
	_muteButton.text = "🔇" if _audioPlayer.volume_db <= -80 else "🔊"

func _on_license_button_pressed():
	LicenseRequested.emit(_soundPath)

func UpdateVolumeLabel():
	_volumeLabel.text = "Volume: %d%%" % _volumeSlider.value

func UpdatePitchLabel():
	_pitchLabel.text = "Pitch: %.1fx" % _pitchSlider.value

func Cleanup():
	if _audioPlayer and _audioPlayer.playing:
		_audioPlayer.stop()
