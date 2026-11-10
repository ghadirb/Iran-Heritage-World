extends Node
## Global state: touch input, saved progress, quality settings.

signal quality_changed
signal ui_changed

const SAVE_PATH := "user://progress.json"

var move_vector := Vector2.ZERO      # written by TouchControls (virtual stick)
var ui_blocked := true               # true while any panel is open
var current_level := 0
var unlocked_level := 0              # highest level index the player may play
var stars: Dictionary = {}           # level index (String) -> 0..3
var knowledge: Array = []            # ids of unlocked encyclopedia entries
var quality := 0                     # 0 light, 1 medium, 2 high (weak-phone safe default)
var shadows := false
var ui_scale_index := 1              # 0 normal, 1 large, 2 extra large (text/buttons size)
var ui_saved := false
const UI_SCALES := [1.0, 1.25, 1.4]
var music_volume := 0.7              # 0..1
var ambience_volume := 0.8           # wind + water
var voice_mode := 2                  # 0 off, 1 manual button, 2 automatic (default)
var voice_chosen := false            # true once the player changed it in settings
var quality_saved := false           # false on first run -> pick a safe default
const GUARD_PATH := "user://loading.flag"
var safe_mode_triggered := false

## Quality presets: 3D resolution scale, shadow atlas size, MSAA.
const RENDER_SCALE := [0.6, 0.8, 1.0]
const SHADOW_SIZE := [1024, 2048, 4096]

func _ready() -> void:
	load_game()
	if not quality_saved:
		# First run: weak phones must never start on "high".
		quality = 0 if OS.has_feature("mobile") else 2
		shadows = not OS.has_feature("mobile")
	# Crash guard: if the previous launch died while building a level, force the lightest mode.
	if FileAccess.file_exists(GUARD_PATH):
		quality = 0
		shadows = false
		safe_mode_triggered = true
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GUARD_PATH))
	if not ui_saved:
		ui_scale_index = 1 if OS.has_feature("mobile") else 0
	apply_engine_quality()
	apply_ui_scale()

func apply_ui_scale() -> void:
	var win := get_window()
	if win == null:
		return
	var f: float = UI_SCALES[ui_scale_index]
	win.content_scale_size = Vector2i(roundi(1280.0 / f), roundi(720.0 / f))

func set_ui_scale(value: int) -> void:
	ui_scale_index = clampi(value, 0, 2)
	ui_saved = true
	apply_ui_scale()
	ui_changed.emit()
	save_game()

func begin_loading_guard() -> void:
	var f := FileAccess.open(GUARD_PATH, FileAccess.WRITE)
	if f:
		f.store_string("1")

func end_loading_guard() -> void:
	if FileAccess.file_exists(GUARD_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GUARD_PATH))

func apply_engine_quality() -> void:
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_SIZE[quality], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		[RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW][quality])
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = RENDER_SCALE[quality]
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality] if not OS.has_feature("mobile") or quality == 2 else Viewport.MSAA_DISABLED

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	unlocked_level = int(data.get("unlocked_level", 0))
	stars = data.get("stars", {})
	knowledge = data.get("knowledge", [])
	quality = int(data.get("quality", 0))
	quality_saved = data.has("quality")
	ui_scale_index = clampi(int(data.get("ui_scale", 1)), 0, 2)
	ui_saved = data.has("ui_scale")
	music_volume = clampf(float(data.get("music_volume", 0.7)), 0.0, 1.0)
	ambience_volume = clampf(float(data.get("ambience_volume", 0.8)), 0.0, 1.0)
	voice_chosen = bool(data.get("voice_chosen", false))
	voice_mode = clampi(int(data.get("voice_mode", 2)), 0, 2) if voice_chosen else 2
	shadows = bool(data.get("shadows", false))

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"unlocked_level": unlocked_level,
		"stars": stars,
		"knowledge": knowledge,
		"quality": quality,
		"shadows": shadows,
		"ui_scale": ui_scale_index,
		"music_volume": music_volume,
		"ambience_volume": ambience_volume,
		"voice_mode": voice_mode,
		"voice_chosen": voice_chosen,
	}))

func complete_level(index: int, star_count: int, knowledge_id: String) -> void:
	var key := str(index)
	stars[key] = maxi(int(stars.get(key, 0)), star_count)
	unlocked_level = maxi(unlocked_level, index + 1)
	if knowledge_id != "" and not knowledge.has(knowledge_id):
		knowledge.append(knowledge_id)
	save_game()

func set_quality(value: int) -> void:
	quality = clampi(value, 0, 2)
	quality_saved = true
	apply_engine_quality()
	save_game()
	quality_changed.emit()

func set_shadows(value: bool) -> void:
	shadows = value
	save_game()
	quality_changed.emit()

func set_audio(music_v: float, ambience_v: float, voice_m: int) -> void:
	music_volume = clampf(music_v, 0.0, 1.0)
	ambience_volume = clampf(ambience_v, 0.0, 1.0)
	if clampi(voice_m, 0, 2) != voice_mode:
		voice_chosen = true
	voice_mode = clampi(voice_m, 0, 2)
	save_game()
