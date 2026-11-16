# کوروش و هخامنشیان (cyrus_achaemenids) — فصل ۶
- content_type: documented_history (تاریخ مستند؛ مرحله‌ها بازآفرینی تخیلی‌اند و در متن برچسب خورده‌اند)
- review: **needs_editorial_review** (متن توسط هوش مصنوعی نوشته شده؛ بازبین انسانی باید تطبیق دهد)

## آنچه کودک یاد می‌گیرد
کوروش بزرگ بنیان‌گذار شاهنشاهی هخامنشی بود. «استوانه‌ی کوروش» شیئی واقعی از گل پخته است که پس از گرفتنِ بابل در ۵۳۹ پیش از میلاد نوشته شد و امروز در موزه‌ی بریتانیا است؛ پاسارگاد نخستین پایتخت هخامنشیان است. و یک درس مهم: استوانه خودش چه می‌گوید و بعدها دیگران درباره‌اش چه گفته‌اند، دو چیزِ جدا است.

## Sources (accessed 16 Nov 2026; a human reviewer must re-check each claim)
- British Museum, object **BM 90920** "The Cyrus Cylinder" (object page, curator's comments and translation page): baked clay, Babylonian cuneiform, deposited after Cyrus took Babylon in 539 BC, text incomplete, found in several fragments, dated 539–530 BC, discovered 1879 (excavations of Hormuzd Rassam), "records ... restoration to various temples of statues removed by Nabonidus".
- A. Simonin, "The Cyrus Cylinder", World History Encyclopedia (18 Jan 2012): the text is considered royal propaganda by many historians; reading it as the "first charter of human rights" is a modern interpretation (1970s) and is called an anachronism.
- Irving Finkel (British Museum), talk reported by Yale Peabody Museum ("Cyrus and his Cylinder: What Was He Thinking?"): there were no human rights in antiquity; the object is a symbol today.
- Encyclopaedia Britannica, "Pasargadae": first dynastic capital of the Achaemenids, designated UNESCO World Heritage in 2004; UNESCO World Heritage List (Pasargadae 2004; Persepolis 1979).
- Not yet used here: Herodotus, Histories (Royal Road couriers: book 8.98, stations: book 5.52–54) — reserved for the next chapter.

## Story beats -> levels
| Level | Beat | What the player physically does | Mechanic reused | Honest label |
|---|---|---|---|---|
| 23 `cylinder_deposit` | After the fall of Babylon (539 BC) a clay cylinder was made and placed in a foundation (BM) | carries a fragile clay cylinder with calm steps (running/jumping cracks it), rests it on cushioned stands, lays it at the wall foundation | calm carry (`lamp_road`, `item: cylinder`, messages `cyl_*`) | the carrying, stands and wall are game reconstruction |
| 24 `pasargadae_tomb` | Pasargadae, first Achaemenid capital (UNESCO 2004), with a stone tomb regarded as Cyrus's | carries three building stones to three footings in order near->far | carry (`log`+`brazier`, `carry_visual: stone`, `place: stone`) | footings and the way stones are carried are game reconstruction, not how the tomb was built |
| 25 `cyrus_quiz` | what the cylinder is and says, and what later readers claimed | walks to three question stands | quiz hall | questions come from the sources above |

## Deliberately left out / vague
- The exact find spot inside Babylon (Esagila vs. another mound): sources differ, only "Babylon, 1879" is stated.
- The exact date of the text: "539–530 BC" as the museum says.
- Any statement that the cylinder abolished slavery or "gave" rights; the Cylinder's own text (restoring gods to shrines, returning people to settlements) is described neutrally.
- Number of tiers/steps of the tomb.

## Knowledge entries (each needs the source check)
`k_cyrus_cylinder`, `k_pasargadae`, `k_cylinder_debate`.

## Open questions for the reviewer
1. Is "the tomb at Pasargadae regarded as Cyrus's" worded safely?
2. Is the "propaganda / human-rights reading is modern" sentence fair and child-safe?
3. Voices: only existing speakers (narrator, "سنگ‌نوشته", "راهنمای تالار").
