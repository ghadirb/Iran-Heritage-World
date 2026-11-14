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
	"target_hit": "عالی! هدف را زدی.",
	"scale_solved": "ترازو برابر شد؛ دروازه باز می‌شود.",
	"trunk_lost": "تنه به رود افتاد؛ تنه‌ای تازه سر جای خود آمد.",
	"chase_caught": "مه به تو رسید؛ از نقطه‌ی امن دوباره بدو.",
	"chase_safe": "از مه گذشتی و به پناهگاه رسیدی!",
	"wind_caught": "باد تو را برگرداند؛ کمی صبر کن و دوباره از شکاف بگذر.",
	"wind_safe": "از گذرگاه باد گذشتی!",
	"roll_lost": "گوی از راه‌آب بیرون رفت؛ دوباره از نقطه‌ی امن راهنمایی‌اش کن.",
	"roll_safe": "گوی به نشان پایان رسید!",
	"turning_safe": "از پلِ چرخان گذشتی!",
	"lamp_refill": "روغن چراغ پر شد؛ آرام ادامه بده.",
	"lamp_warn": "چراغ کم‌نور شده؛ آرام‌تر برو.",
	"lamp_low": "روغنِ چراغ برای رسیدن به برج کافی نیست؛ کنار کوزه‌ی روغن پرش کن.",
	"lamp_out": "چراغ خاموش شد؛ از آخرین کوزه‌ی روغن دوباره آرام آغاز کن.",
	"lamp_safe": "چراغ سالم به برج رسید!",
	"mosaic_watch": "کاشی‌ها را به‌دقت ببین؛ سپس به همان ترتیب روی آن‌ها بایست.",
	"mosaic_right": "درست بود! کاشی بعدی.",
	"mosaic_wrong": "ترتیب درست نبود؛ دوباره نگاه کن.",
	"mosaic_replay": "ترتیب دوباره نشان داده می‌شود.",
	"mosaic_solved": "ترتیب کاشی‌ها درست شد!",
	"mirror_watch": "پرتوِ نور را ببین؛ روی دیسک‌ها بایست تا آینه‌ها بچرخند.",
	"mirror_solved": "نور به فانوس رسید!",
	"watch_start": "برج‌ها نور می‌پراکنند؛ زیر سایه‌بان در امانی. وقتی پرتو گذشت، بدو.",
	"watch_seen": "نور بر تو افتاد؛ به آخرین سایه‌بان برگشتی.",
	"watch_safe": "از زیر نورها گذشتی و به ایستگاه رسیدی!",
}
const FIRE_LIT := "%s روشن شد."
const GO_FINALE := "همه‌ی بخش‌ها کامل شد. به سراغ «%s» برو."

## Easy shows the colours; harder variants show the riddle (level["order_hint"]).
static func wrong_order(level: Dictionary) -> String:
	return "ترتیب درست نبود؛ آتش‌ها خاموش شدند. " + str(level.get("order_hint", "سرخ، آبی، زرد، سبز."))
