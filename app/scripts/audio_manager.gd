extends Node
## Global audio: calm music, wind and water ambience (looped, cross-faded) and
## optional pre-recorded narration. Narration files are optional: put
## res://audio/voice/<level_id>__<key>.(ogg|mp3|wav) and the game shows a
## "listen" button automatically (see documentation/voice-narration.md).

const MUSIC_PATH := "res://audio/music_calm.ogg"
const WIND_PATH := "res://audio/ambient_wind.ogg"
const WATER_PATH := "res://audio/ambient_water.ogg"
const VOICE_DIR := "res://audio/voice/"
const VOICE_EXT := ["ogg", "mp3", "wav"]

var music: AudioStreamPlayer
var wind: AudioStreamPlayer
var water: AudioStreamPlayer
var voice: AudioStreamPlayer

var _music_target := 0.0     # 0..1 linear, before user volume
var _wind_target := 0.0
var _water_target := 0.0
var _music_now := 0.0
var _wind_now := 0.0
var _water_now := 0.0
var _duck := 1.0
var _voice_queue: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = _make_player(MUSIC_PATH)
	wind = _make_player(WIND_PATH)
	water = _make_player(WATER_PATH)
	voice = AudioStreamPlayer.new()
	voice.finished.connect(_on_voice_finished)
	add_child(voice)

func _make_player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		var s := load(path)
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		p.stream = s
	p.volume_db = -80.0
	add_child(p)
	return p

func _notification(what: int) -> void:
	# Mute when the app goes to the background (Android).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		AudioServer.set_bus_mute(0, true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		AudioServer.set_bus_mute(0, false)

# ---------- scene control ----------

func enter_menu() -> void:
	_music_target = 0.8
	_wind_target = 0.0
	_water_target = 0.0
	stop_voice()

func play_level(level: Dictionary) -> void:
	var a: Dictionary = level.get("audio", {})
	_music_target = float(a.get("music", 0.5))
	_wind_target = float(a.get("wind", 0.3))
	_water_target = 0.0

## Called every frame by the world: ambience follows the player position.
func update_ambience(level: Dictionary, wind_height: float, river_distance: float) -> void:
	var a: Dictionary = level.get("audio", {})
	_wind_target = clampf(float(a.get("wind", 0.3)) + clampf(wind_height / 40.0, 0.0, 1.0) * 0.3, 0.0, 1.0)
	if river_distance >= 0.0:
		_water_target = float(a.get("water", 1.0)) * clampf(1.0 - (river_distance - 2.0) / 22.0, 0.0, 1.0)
	else:
		_water_target = 0.0

func _process(delta: float) -> void:
	var duck_target := 0.35 if voice.playing else 1.0
	_duck = move_toward(_duck, duck_target, delta * 1.5)
	var k := clampf(delta * 1.2, 0.0, 1.0)
	_music_now = lerpf(_music_now, _music_target, k)
	_wind_now = lerpf(_wind_now, _wind_target, k)
	_water_now = lerpf(_water_now, _water_target, k)
	_apply(music, _music_now * _duck * GameState.music_volume * 0.55)
	_apply(wind, _wind_now * GameState.ambience_volume * 0.6)
	_apply(water, _water_now * GameState.ambience_volume * 0.7)
	voice.volume_db = 0.0

func _apply(p: AudioStreamPlayer, linear: float) -> void:
	if p.stream == null:
		return
	if linear < 0.004:
		if p.playing:
			p.stop()
		return
	p.volume_db = linear_to_db(linear)
	if not p.playing:
		p.play(randf() * 4.0)

# ---------- narration ----------

func voice_path(key: String) -> String:
	for ext in VOICE_EXT:
		var path := "%s%s.%s" % [VOICE_DIR, key, ext]
		if ResourceLoader.exists(path):
			return path
	return ""

func has_voice(key: String) -> bool:
	return GameState.voice_mode != 0 and voice_path(key) != ""

func play_voice(key: String) -> bool:
	return play_voice_sequence([key])

func play_voice_sequence(keys: Array) -> bool:
	stop_voice()
	for k in keys:
		if voice_path(str(k)) != "":
			_voice_queue.append(str(k))
	if _voice_queue.is_empty():
		return false
	_play_next()
	return true

func _play_next() -> void:
	while not _voice_queue.is_empty():
		var key: String = _voice_queue.pop_front()
		var path := voice_path(key)
		if path == "":
			continue
		voice.stream = load(path)
		voice.play()
		return

func _on_voice_finished() -> void:
	_play_next()

func stop_voice() -> void:
	_voice_queue.clear()
	if voice and voice.playing:
		voice.stop()

func is_voice_playing() -> bool:
	return voice != null and voice.playing
