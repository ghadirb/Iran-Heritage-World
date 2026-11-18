class_name CutsceneData
extends RefCounted
## Story clips (Ogg Theora in res://video/, produced by tools/convert_video.py from assets-source/Video).
## Levels reference them with "cutscene_before" (played once before the level intro) and
## "cutscene_after" (played once when the level is completed). Players can switch clips off in the settings
## and watch them again from "کلیپ‌های داستان".

const CLIPS := {
	"zal_nest": {
		"path": "res://video/zal_nest.ogv",
		"title": "زال در آشیانه",
		"caption": "تصویرسازی هنری از روایت شاهنامه؛ تصویر تاریخی نیست.",
	},
	"simorgh_flight": {
		"path": "res://video/simorgh_flight.ogv",
		"title": "پرواز سیمرغ",
		"caption": "تصویرسازی هنری از روایت شاهنامه؛ تصویر تاریخی نیست.",
	},
	"simorgh_feather": {
		"path": "res://video/simorgh_feather.ogv",
		"title": "پرِ سیمرغ",
		"caption": "تصویرسازی هنری از روایت شاهنامه؛ تصویر تاریخی نیست.",
	},
}

## Order shown in the "watch again" list (story order).
const ORDER := ["zal_nest", "simorgh_flight", "simorgh_feather"]

static func has_clip(id: String) -> bool:
	return CLIPS.has(id)

static func path_of(id: String) -> String:
	return str((CLIPS[id] as Dictionary)["path"]) if CLIPS.has(id) else ""

## True when the clip file exists and loads as a video stream (checked by the self-test).
static func is_valid(id: String) -> bool:
	var p := path_of(id)
	return p != "" and ResourceLoader.exists(p) and load(p) is VideoStream
