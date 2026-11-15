# کاوه و ضحاک (kaveh_zahhak) — فصل ۴
- content_type: literary_myth (روایت حماسی از شاهنامه؛ مرحله‌ها بازآفرینی تخیلی‌اند و در متن برچسب خورده‌اند)
- review: **needs_editorial_review** (متن توسط هوش مصنوعی نوشته شده؛ بازبین انسانی باید با متن شاهنامه تطبیق دهد)

## آنچه کودک یاد می‌گیرد
کاوه آهنگر که در روایت شاهنامه در برابر ستمِ ضحاک برمی‌خیزد، پیش‌بندِ چرمینِ خود را بر نیزه می‌کند (درفش کاویانی)، و ضحاک در پایان در دماوند به بند کشیده می‌شود. این روایتی حماسی است، نه سندِ تاریخی.

## Sources
- Primary (to be recorded by a human reviewer): Ferdowsi, *Shahnameh* — the episodes of Zahhak, Kaveh the blacksmith and Fereydun. **Edition, section and lines are NOT yet recorded.** Every claim below must be checked against the text.
- Secondary sources used only to outline the beats (web summaries, not citations): Kheradgan (en.kheradgan.ir, summary of Kaveh's uprising and "why Zahhak fell"), godsandmonsters.info (Kaveh the Blacksmith), Wikipedia (Kaveh the Blacksmith). They agree on the core beats; they differ on details.

## Story beats -> levels
| Level | Beat (what the text says, in our words) | What the player physically does | Mechanic reused | Honest label |
|---|---|---|---|---|
| 18 `kaveh_forge` | Kaveh is a blacksmith who stands up against Zahhak's tyranny and raises his leather apron on a spear (the Kaviani banner) | carries firewood to three furnaces in order (near -> far); a wrong furnace returns the wood | carry firewood (`log` + `brazier`, `no_fire_riddle` keeps its own text) | furnaces, fuel and the route are game reconstruction |
| 19 `damavand_path` | Zahhak is finally bound (not killed) on Mount Damavand | crosses crumbling mountain stones; wooden pads are safe checkpoints | sinking stones (`sinking_stones`, own messages `summit_*`) | the stones and pads are game reconstruction |
| 20 `kaveh_quiz` | what the story says, and that it is literary myth | walks to three question stands | quiz hall (`hall`) | questions come from the narrative itself |

## Deliberately left out / vague
- The number of Kaveh's sons: retellings differ, so no number appears anywhere.
- Who exactly binds Zahhak and the heavenly voice that stops Fereydun from killing him: kept out of the text until a reviewer fixes the wording from the primary source (level 19 says only that he is bound on Damavand).
- Any claim about later history of the banner.

## Knowledge entries (each needs the primary-source check)
`k_kaveh`, `k_damavand`, `k_kaviani`. Damavand being the highest peak of Iran in the Alborz range is a geographic fact (check a reference before `verified`).

## Open questions for the reviewer
1. Edition, section and lines for every beat above.
2. Is "Kaveh raised the apron as a banner of uprising against tyranny" worded safely for children?
3. Level 19 lines: confirm "bound on Damavand rather than killed" against the text.
4. Voices: all new lines use the narrator, "سنگ‌نوشته" and "راهنمای تالار" voices (no new character was added).
