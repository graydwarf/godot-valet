extends Node2D

# Reminder: Won't work if the main tree gets paused
func PlaySoundEffect(audioFilePath : String, volume = 0.0, busType : AudioManager.Bus = AudioManager.Bus.Effects, pitchScale = 1.0, delay = 0.0, globalPosition = Vector2.ZERO):
	var streamPlayer = null
	if globalPosition != Vector2.ZERO:
		streamPlayer = %AudioStreamPlayer2D
		streamPlayer.global_position = globalPosition
	else:
		streamPlayer = %AudioStreamPlayer
	
	if audioFilePath == "":
		print("Invalid audiFile")
		return
	
	# Optional delay
	await get_tree().create_timer(delay).timeout
	
	var fileToStream = load(audioFilePath)
	streamPlayer.set_stream(fileToStream)
	streamPlayer.volume_db = volume
	streamPlayer.bus = GetBusName(busType)
	streamPlayer.pitch_scale = pitchScale
	streamPlayer.play()
	
func GetBusName(busType : AudioManager.Bus):
	match busType:
		AudioManager.Bus.Master:
			return "Master"
		AudioManager.Bus.Voice:
			return "Voice"
		AudioManager.Bus.Effects:
			return "Effects"
		AudioManager.Bus.Music:
			return "Music"
		
func _on_audio_stream_player_2d_finished() -> void:
	queue_free()
