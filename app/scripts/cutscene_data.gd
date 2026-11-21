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
		"subtitles": [
			[0.2, 8.9, "در روزگاران کهن، در سرزمین ایران، کودکی با موهایی سپید زاده شد؛ نامش زال بود."],
			[9.6, 16.4, "پدرش، سام، از بیم داوری مردم، او را در کوهستان البرز رها کرد."],
			[16.9, 20.1, "اما سرنوشت زال، تنهایی نبود."],
			[20.4, 27.4, "سیمرغ، پرنده افسانه‌ای کوهستان، کودک را یافت و به آشیانه خود برد."],
			[27.9, 37.7, "از آن روز، داستانی شگفت آغاز شد؛ داستان پیوند انسان و یکی از رازآمیزترین موجودات اساطیر ایران."],
			[38.3, 42.2, "این، آغاز ماجرای زال و سیمرغ است."],
		],
	},
	"simorgh_flight": {
		"path": "res://video/simorgh_flight.ogv",
		"title": "پرواز سیمرغ",
		"caption": "تصویرسازی هنری از روایت شاهنامه؛ تصویر تاریخی نیست.",
		"subtitles": [
			[0.2, 8.5, "در بلندای کوهستان البرز، دور از چشم آدمیان، سیمرغ از زال نگهداری می‌کرد."],
			[9.0, 16.9, "روزها گذشت و کودک سپیدموی، در پناه پرنده افسانه‌ای، بالید و بزرگ شد."],
			[17.5, 23.0, "زال از سیمرغ آموخت که در برابر دشواری‌ها استوار بماند."],
			[23.5, 31.1, "اما سرنوشت، روزی او را از آشیانه کوهستان به سوی دنیای انسان‌ها فرا می‌خواند."],
			[31.6, 36.3, "روزی که گذشته و آینده به هم خواهند رسید..."],
		],
	},
	"simorgh_feather": {
		"path": "res://video/simorgh_feather.ogv",
		"title": "پرِ سیمرغ",
		"caption": "تصویرسازی هنری از روایت شاهنامه؛ تصویر تاریخی نیست.",
		"subtitles": [
			[0.2, 10.2, "سام برای بازگرداندن زال به کوه البرز آمد. سیمرغ با اندوه از او خداحافظی کرد و پری از بال خود به او داد."],
			[10.7, 18.4, "سپس گفت: «هرگاه گرفتار سختی شدی، این پر را بسوزان تا به یاری‌ات بیایم.»"],
			[18.9, 25.2, "زال همراه پدر بازگشت؛ اما هرگز سیمرغ را فراموش نکرد."],
		],
	},
}

## Subtitle cue under the playback position (seconds), or "" when nobody is speaking.
## Cues were timed from the pauses of the narration (ffmpeg silencedetect) and the owner's texts.
static func subtitle_at(id: String, t: float) -> String:
	if not CLIPS.has(id):
		return ""
	for cue in ((CLIPS[id] as Dictionary).get("subtitles", []) as Array):
		if t >= float(cue[0]) and t <= float(cue[1]):
			return str(cue[2])
	return ""

## Self-test helper: cues must be ordered, non-overlapping and carry text.
static func subtitles_ok(id: String) -> bool:
	var prev := -1.0
	for cue in ((CLIPS[id] as Dictionary).get("subtitles", []) as Array):
		if float(cue[0]) < prev or float(cue[1]) <= float(cue[0]) or str(cue[2]).strip_edges() == "":
			return false
		prev = float(cue[1])
	return true

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
