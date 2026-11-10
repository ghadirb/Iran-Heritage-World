extends Node
## Global state: touch input, saved progress, quality settings.

signal quality_changed

const SAVE_PATH := "user://progress.json"

var move_vector := Vector2.ZERO      # written by TouchControls (virtual stick)
var ui_blocked := true               # true while any panel is open
var current_level := 0
var unlocked_level := 0              # highest level index the player may play
var stars: Dictionary = {}           # level index (String) -> 0..3
var knowledge: Array = []            # ids of unlocked encyclopedia entries
var quality := 2                     # 0 light, 1 medium, 2 high
var shadows := true

func _ready() -> void:
	load_game()

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
	quality = int(data.get("quality", 2))
	shadows = bool(data.get("shadows", true))

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
	save_game()
	quality_changed.emit()

func set_shadows(value: bool) -> void:
	shadows = value
	save_game()
	quality_changed.emit()
