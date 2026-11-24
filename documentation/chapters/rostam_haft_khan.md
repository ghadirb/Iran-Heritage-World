# سفر رستم (rostam_haft_khan) — فصل ۸
- content_type: **literary_myth** (افسانه‌ی شاهنامه؛ تاریخ نیست)
- review: **needs_editorial_review**

## آنچه کودک یاد می‌گیرد
«هفت‌خان رستم» بخشی از شاهنامه‌ی فردوسی است. کیکاووس در مازندران گرفتار دیوان می‌شود و رستم با اسبش رخش از راهی کوتاه و پُرخطر برای رهاندن او می‌رود. روایت افسانه است، نه تاریخ؛ و بازی فقط سه خان را با کنش بازآفرینی می‌کند.

## Sources (accessed 16 Nov 2026; a human reviewer must re-check each claim)
- Primary (to be recorded by a human reviewer): Ferdowsi, *Shahnameh*, the story of Kay Kavus in Mazandaran and Rostam's seven labours. **Edition, section and lines are NOT yet recorded.** Every claim below must be checked against the text.
- Secondary used to fix the traditional order and details: Wikipedia "Rostam's Seven Labours" (order: lion, desert, dragon, witch, Olad, rescue of the king, White Demon; the blood/heart of the White Demon restores Kay Kavus's sight); FEZANA Lesson 8 "Seven Labors of Rostam" (grades 4–5, same order); Encyclopaedia Iranica "Rostam" (first labour: Rakhsh kills the lion while Rostam sleeps; second: a wild ram guides him to water). These are secondary sources only.
- Details of the later labours (the dark land, Olad, Arzhang, how the witch is revealed) differ between retellings and are NOT stated in the game.

## Story beats -> levels
| Level | Beat | What the player physically does | Mechanic reused | Honest label |
|---|---|---|---|---|
| 29 `haft_khan_dragon` | third labour: Rostam, helped by Rakhsh, overcomes a dragon | crosses the dragon's breath columns with timing | timed gusts (`wind_msg_prefix: dragon`) | breath columns are game reconstruction; the story's fight is not played |
| 30 `haft_khan_witch` | fourth labour: a sorceress who looks like a beautiful woman is revealed | turns mirrors so a beam reaches a lantern, "revealing" the true form | mirror hall (`mirror_msg_prefix: witch`) | the light puzzle is invented; the story says nothing about mirrors |
| 31 `haft_khan_div` | seventh labour: the White Div is overcome and a cure for Kay Kavus's blindness is made from his heart | carries a fragile phial calmly to the king's tent | calm carry (`item: vial`, `lamp_msg_prefix: vial`) | the carrying and the tent are game reconstruction |
| 32 `rostam_quiz` | what the story is and is not | four question stands | quiz hall | questions come from the sources above |

## Deliberately left out / to decide
- Labours 1, 2, 5, 6 (lion, desert, Olad, the king's city): left for a later extension of this chapter.
- Violence is only named, not shown (Rostam's victories are described in one neutral sentence).
- Whether to mention Rostam's origin (Zabolistan) or later tragedy (Sohrab): not in this chapter.

## Knowledge entries
`k_haft_khan`, `k_witch_light`, `k_white_div`, `k_haft_khan_quiz`.
