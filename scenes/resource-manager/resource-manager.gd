extends Panel

var _isDirty := false
var _selectedProjectItem
var _scriptFilePath : String

func _ready():
	LoadTheme()
	LoadBackgroundColor()
	InitSignals()

func InitSignals():
	pass
	
# Triggered when user closes via X or some other means.
# TODO: We need to block them from closing until we get 
# a prompt/response from the user when we have outstanding changes. 
# Currently forcing saves as that is preferred over losing data.
func _notification(notificationType):
	if notificationType == NOTIFICATION_WM_CLOSE_REQUEST:
		if _isDirty:
			SaveSettings()

func LoadBackgroundColor():
	var style_box = theme.get_stylebox("panel", "Panel") as StyleBoxFlat

	if style_box:
		style_box.bg_color = App.GetBackgroundColor()
	else:
		print("StyleBoxFlat not found!")

func LoadTheme():
	theme = load(App.GetThemePath())
	
func ConfigureResourceManager(selectedProjectItem):
	_selectedProjectItem = selectedProjectItem
	
func SaveSettings():
	_isDirty = false

func OpenTextureFromFile(filePath: String) -> Texture:
	var image := Image.new()
	var err := image.load(filePath)
	if err != OK:
		push_error("Failed to load image from file: %s" % filePath)
		return

	return ImageTexture.create_from_image(image)

func LoadSound(path: String) -> AudioStream:
	var audioStream = load(path)
	if audioStream is AudioStream:
		return audioStream
	push_error("Failed to load audio stream from: %s" % path)
	return null
	
func HidePreviewControls():
	%ImagePreviewTextureRect.visible = false
	
func LaunchPreviewOfImage():
	HidePreviewControls()
	%ImagePreviewTextureRect.visible = true
	%ImagePreviewTextureRect.texture = OpenTextureFromFile("C:\\dad\\poplava.png")

func LaunchPreviewOfSound():
	var volume = -20
	var bus = AudioManager.Bus.Effects
	var pitch = 1.0

	var stream = LoadWavFromDisk("C:\\dad\\sounds\\air.wav")
	if stream:
		%AudioStreamPlayer.stream = stream
		%AudioStreamPlayer.play()

# TODO: Place holder. Apparently .ogg files are special and 
# need to be copied to our user directory before we can play them.
func CopyToUserDir(source_path: String, dest_name: String) -> String:
	var dest_path = "user://" + dest_name
	var source_file = FileAccess.open(source_path, FileAccess.READ)
	var dest_file = FileAccess.open(dest_path, FileAccess.WRITE)
	if source_file and dest_file:
		dest_file.store_buffer(source_file.get_buffer(source_file.get_length()))
		source_file.close()
		dest_file.close()
		return dest_path
	return ""

func PlayOggDirect(path: String):
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream:
		%AudioStreamPlayer.stream = stream
		%AudioStreamPlayer.play()
	else:
		push_error("Failed to load OGG stream from: %s" % path)

func PlayWavWithFadeIn(stream: AudioStream):
	%AudioStreamPlayer.volume_db = -40  # Start very quiet
	%AudioStreamPlayer.stream = stream
	%AudioStreamPlayer.play()

	var tween := create_tween()
	tween.tween_property(%AudioStreamPlayer, "volume_db", 0, 0.05)  # Fade in over 50ms
	
func LoadWavFromDisk(path: String) -> AudioStreamWAV:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file: %s" % path)
		return null
	
	var buffer := file.get_buffer(file.get_length())
	file.close()

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false  # or true if stereo
	stream.mix_rate = 44100  # or match your file's sample rate
	stream.data = buffer

	return stream

func LoadScriptFile(scriptFilePath: String) -> void:
	_scriptFilePath = scriptFilePath
	var file := FileAccess.open(_scriptFilePath, FileAccess.READ)
	if file == null:
		push_error("Failed to open file: %s" % _scriptFilePath)
		return
	
	var script_text := file.get_as_text()
	file.close()
	%TextEdit.text = script_text

func SaveScriptFile() -> void:
	var file := FileAccess.open(_scriptFilePath, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for writing: %s" % _scriptFilePath)
		return
	
	file.store_string(%TextEdit.text)
	file.close()

func PlayZipFileSound(zipPath, fileName):
	var dest_path = ExtractSoundToUserDir(zipPath, fileName)
	PlayOggDirect(dest_path)
	
func ExtractSoundToUserDir(zip_path: String, file_inside_zip: String, output_name: String = "temp_audio.ogg") -> String:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		push_error("Failed to open zip: %s" % zip_path)
		return ""
	
	if not zip.file_exists(file_inside_zip):
		push_error("Missing file in zip: %s" % file_inside_zip)
		zip.close()
		return ""
	
	var data := zip.read_file(file_inside_zip)
	zip.close()

	var dest_path := "user://%s" % output_name
	var file := FileAccess.open(dest_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open output path: %s" % dest_path)
		return ""
	file.store_buffer(data)
	file.close()
	
	return dest_path

	
func _on_button_pressed() -> void:
	LaunchPreviewOfImage()

func _on_open_sound_button_pressed() -> void:
	LaunchPreviewOfSound()

func _on_open_ogg_button_pressed() -> void:
	PlayOggDirect("C:\\dad\\sounds\\pickup-sound.ogg")

func _on_play_wav_button_pressed() -> void:
	var stream = LoadWavFromDisk("C:\\dad\\sounds\\air.wav")
	PlayWavWithFadeIn(stream)

func _on_open_script_pressed() -> void:
	LoadScriptFile("C:\\dad\\audio-files.gd")

func _on_save_button_pressed() -> void:
	SaveScriptFile()

func _on_open_script_2_pressed() -> void:
	PlayZipFileSound("C:\\dad\\asdf.zip", "pickup-sound.ogg")
