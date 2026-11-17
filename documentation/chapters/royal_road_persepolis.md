# راه شاهی و تخت‌جمشید (royal_road_persepolis) — فصل ۷
- content_type: documented_history (مرحله‌ها بازآفرینی تخیلی‌اند و در متن برچسب خورده‌اند)
- review: **needs_editorial_review**

## آنچه کودک یاد می‌گیرد
هخامنشیان راهی داشتند که ایستگاه‌هایش پیک‌ها را پشت سر هم به هم می‌رساند (هرودوت)، و تخت‌جمشید، که داریوش یکم حدود ۵۱۸ پیش از میلاد ساختنش را آغاز کرد، روی پلکان‌هایش هیئت‌هایی را با هدیه نشان می‌دهد.

## Sources (accessed 16 Nov 2026; a human reviewer must re-check each claim)
- Herodotus, *Histories* 5.52–53 (Royal Road between Sardis and Susa, royal stations, 111 stages in total) and 8.98 (mounted couriers: as many horses and men as days of the journey, each appointed for one day's journey; "neither snow nor rain nor heat nor darkness of night" prevents them; passing the message on is compared to the Greek torch race). Translations quoted via Perseus/Livius/Wikipedia; only paraphrased in the game.
- Livius.org, "Royal Road" (notes that Persepolis tablets mention the horse-changing system, Elamite/OP *pirradaziš*).
- Persepolis: UNESCO World Heritage List (inscribed 1979, ref. 114); World History Encyclopedia "Persepolis" (construction began c. 518–515 BC under Darius I, continued under Xerxes I and Artaxerxes I; Apadana reliefs show 23 delegations with gifts); Smarthistory / Khan Academy "Persepolis: The Audience Hall of Darius and Xerxes".

## Story beats -> levels
| Level | Beat | What the player physically does | Mechanic reused | Honest label |
|---|---|---|---|---|
| 26 `royal_road_relay` | couriers pass the message from station to station, in snow, rain, heat and night (Hdt 8.98) | runs a stage and times the passing of storm columns (gusts), then reaches the station (چاپارخانه) | wind course (`wind_msg_prefix: relay`) | the storm columns and the stage are game reconstruction |
| 27 `persepolis_gift` | delegations bring gifts up the staircases of the Apadana | carries a golden cup (a gift) calmly to the Gate of All Nations | calm carry (`item: gift`, `lamp_msg_prefix: gift`) | the gift, the stands and the gate are game reconstruction (no stairs are modelled) |
| 28 `persepolis_quiz` | what the sources say | four question stands | quiz hall | from the sources above |

## Deliberately left out
- "Persepolis was built for Nowruz celebrations": often repeated, not clearly documented; not stated as fact.
- Why/how Persepolis was destroyed (330 BC): motives are debated; saved for a later, careful chapter.
- The exact length of the Royal Road in km and the exact route in Iran.
- The claim that this was the "first postal system" (Herodotus calls the method a Persian invention; earlier Near-Eastern postal systems existed).

## Knowledge entries
`k_royal_road`, `k_persepolis`, `k_chapar_quiz`.
