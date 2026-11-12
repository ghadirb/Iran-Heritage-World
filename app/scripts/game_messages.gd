class_name GameMessages
extends RefCounted
## Short in-game messages (toasts). The text lives here ONCE: the game shows it and VoiceLines lists it
## for recording (key "game__<id>"). Never hard-code these strings elsewhere.

const TEXT := {
	"nothing_near": "به یکی از نشانه‌های درخشان نزدیک شو و دکمه «تعامل» را بزن.",
	"log_pick": "هیزم برداشتی و کندتر می‌دوی. در آتشدان تعامل بزن؛ دور از آتشدان، هیزم را زمین می‌گذارد.",
	"log_drop": "هیزم را زمین گذاشتی.",
	"need_log": "برای روشن کردن آتش، نخست یک هیزم بردار و بیاور.",
	"fall": "از لبه افتادی؛ دوباره تلاش کن.",
	"level_complete": "مرحله کامل شد!",
	"quiz_correct": "درست!",
	"quiz_wrong": "پاسخ درست نیست؛ دوباره فکر کن.",
	# interaction is for conversation only; everything else is physical
	"nothing_to_talk": "دکمه‌ی تعامل فقط برای گفت‌وگوست؛ به یک شخصیت یا پایه‌ی پرسش نزدیک شو.",
	"log_carry": "هیزم برداشتی و کندتر می‌دوی. آن را تا آتشدان ببر.",
	"bridge_built": "پل ساخته شد! از آن بگذر.",
	"bridge_more": "یک تنه‌ی دیگر هم لازم است؛ آن را هم به لبه‌ی رود برسان.",
	"trunk_lost": "تنه به رود افتاد؛ تنه‌ای تازه سر جای خود آمد.",
}
const FIRE_LIT := "%s روشن شد."
const GO_FINALE := "همه‌ی بخش‌ها کامل شد. به سراغ «%s» برو."

## Easy shows the colours; harder variants show the riddle (level["order_hint"]).
static func wrong_order(level: Dictionary) -> String:
	return "ترتیب درست نبود؛ آتش‌ها خاموش شدند. " + str(level.get("order_hint", "سرخ، آبی، زرد، سبز."))
