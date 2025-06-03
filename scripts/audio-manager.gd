extends Node
class_name AudioManager

static var _masterBusIndex = 0
static var _voiceBusIndex = 1
static var _effectsBusIndex = 2
static var _musicBusIndex = 3

static var _masterVolume = 0.6
static var _effectsVolume = 0.5
static var _voiceVolume = 0.3
static var _musicVolume = 0.1

enum Bus {
	Master,
	Voice,
	Effects,
	Music
}

static func Init():
	UpdateMasterVolume(_masterVolume)
	UpdateEffectsVolume(_effectsVolume)
	UpdateVoiceVolume(_voiceVolume)
	UpdateMusicVolume(_musicVolume)

static func UpdateMasterVolume(value):
	if value == 0.0:
		AudioServer.set_bus_mute(_masterBusIndex, true)
	else:
		AudioServer.set_bus_mute(_masterBusIndex, false)

	AudioServer.set_bus_volume_db(_masterBusIndex, linear_to_db(value))
	SetMasterVolume(db_to_linear(AudioServer.get_bus_volume_db(_masterBusIndex)))

static func UpdateEffectsVolume(value : float):
	if value == 0.0:
		AudioServer.set_bus_mute(_effectsBusIndex, true)
	else:
		AudioServer.set_bus_mute(_effectsBusIndex, false)

	AudioServer.set_bus_volume_db(_effectsBusIndex, linear_to_db(value))
	SetEffectsVolume(db_to_linear(AudioServer.get_bus_volume_db(_effectsBusIndex)))

static func UpdateVoiceVolume(value):
	if value == 0.0:
		AudioServer.set_bus_mute(_voiceBusIndex, true)
	else:
		AudioServer.set_bus_mute(_voiceBusIndex, false)

	AudioServer.set_bus_volume_db(_voiceBusIndex, linear_to_db(value))
	SetVoiceVolume(db_to_linear(AudioServer.get_bus_volume_db(_voiceBusIndex)))

static func UpdateMusicVolume(value):
	if value == 0.0:
		AudioServer.set_bus_mute(_musicBusIndex, true)
	else:
		AudioServer.set_bus_mute(_musicBusIndex, false)

	AudioServer.set_bus_volume_db(_musicBusIndex, linear_to_db(value))
	SetMusicVolume(db_to_linear(AudioServer.get_bus_volume_db(_musicBusIndex)))

static func GetMasterVolume():
	return _masterVolume

static func SetMasterVolume(volume):
	_masterVolume = volume

static func GetEffectsVolume():
	return _effectsVolume

static func SetEffectsVolume(volume):
	_effectsVolume = volume

static func SetVoiceVolume(volume):
	_voiceVolume = volume

static func GetVoiceVolume():
	return _voiceVolume

static func SetMusicVolume(volume):
	_musicVolume = volume

static func GetMusicVolume():
	return _musicVolume
