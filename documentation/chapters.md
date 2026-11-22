# Chapters (فصل) and how to continue the game — READ BEFORE ADDING ANYTHING

Terms: **level = مرحله** (one playable 3D course, an entry in `LevelData.LEVELS`),
**chapter = فصل** (a group of consecutive levels that tell ONE story, an entry in `LevelData.CHAPTERS`).
The main menu shows chapters; a chapter opens its own level screen (`show_chapter_menu`).
The first screen therefore stays short however many levels exist.

## Where the project stands (honest status)
| Chapter | Levels | Content | Status |
|---|---|---|---|
| `zal_simorgh` فصل ۱ | 1–6 | Zal and the Simorgh (Shahnameh). Levels 1–3 are the story; 4–6 are game reconstructions around it | needs editorial review, exact edition/lines still to be recorded |
| `arash` فصل ۲ | 7 | Arash the archer (folklore) — a single level | needs editorial review, sources to be recorded |
| `skills` فصل ۳ | 8–17 | Ten **skill levels** with an Iranian look (wind, water, bridge, caravan lamp, mosaic, mirrors, night courier, ice, river stones). They were built to try mechanics; they are NOT tied to a specific event or period | **frozen** — do not add levels here |
| `kaveh_zahhak` فصل ۴ | 18–20 | Kaveh the blacksmith and Zahhak (Shahnameh) — first chapter built content-first; brief in `documentation/chapters/kaveh_zahhak.md` | needs editorial review, primary-source lines still to be recorded |
| `jamshid_nowruz` فصل ۵ | 21–22 | Jamshid and Nowruz: Shahnameh myth separated from the UN/UNESCO documented facts; brief in `documentation/chapters/jamshid_nowruz.md` | needs editorial review, Shahnameh lines still to be recorded |
| `cyrus_achaemenids` فصل ۶ | 23–25 | Cyrus and the Achaemenids (documented history): the Cyrus Cylinder (British Museum BM 90920) and Pasargadae; ends with a quiz that separates what the object says from what was later claimed; brief in `documentation/chapters/cyrus_achaemenids.md` | needs editorial review, sources listed in the brief |
| `royal_road_persepolis` فصل ۷ | 26–28 | Royal Road couriers (Herodotus 5.52–53, 8.98) and Persepolis (Darius I c. 518 BC, UNESCO 1979, Apadana delegations); brief in `documentation/chapters/royal_road_persepolis.md` | needs editorial review |
| `rostam_haft_khan` فصل ۸ | 29–32 | Rostam's Seven Labours (literary myth, Shahnameh): dragon (3rd), witch (4th), White Div cure (7th) + quiz "myth or history?"; brief in `documentation/chapters/rostam_haft_khan.md` | needs editorial review; primary-text lines not yet recorded |
| `darius_behistun` فصل ۹ | 33–35 | Darius I and the Behistun Inscription (documented history; UNESCO 2006; trilingual; Rawlinson); quiz stresses it is the king's own account; brief in `documentation/chapters/darius_behistun.md` | needs editorial review |
| `rostam_rakhsh` فصل ۱۰ | 36–37 | Rostam chooses Rakhsh with a lasso (literary myth; Smithsonian, FEZANA, Wikipedia); first level with the new **lasso** mechanic; brief in `documentation/chapters/rostam_rakhsh.md` | needs editorial review; Shahnameh lines not yet recorded |
| `haft_khan_first` فصل ۱۱ | 38–40 | Rostam's first two labours (literary myth): Rakhsh guards the sleeping hero from lions, a ram leads to a spring; two new mechanics (**guard**, **follow**); brief in `documentation/chapters/haft_khan_first.md` | needs editorial review; Shahnameh lines not yet recorded |

Mistake we made and must not repeat: after chapter 7 we kept inventing new *mechanics* (13–17) without a story,
period or source behind them. The game drifted from its purpose (Iran, its history and myths).
**From now on the content decides the level, not the other way round.**

## Content-first rule (mandatory)
1. A new chapter starts from a **real story, period or place** (a Shahnameh episode, a documented historical
   event, a monument, a custom with known sources). Not from a mechanic.
2. Write the chapter brief (template below) BEFORE any code and put it in `documentation/chapters/<id>.md`.
3. Every level's *action* must be a verb of that story (Kaveh forges / raises the banner, Arash shoots, the
   courier rides ...). If the action has no link to the story, the level does not belong in the chapter.
4. Reuse existing mechanics (table in `AGENTS.md`) before writing a new one. A new mechanic is allowed only when
   no existing one fits the story beat, and it still needs difficulty knobs and a selftest bot.
5. Myth, folklore and literature are labelled as such (`content_type`); history needs a cited source.
   Never present a myth as history, and never invent a historical claim. When sources disagree, say so or leave
   the detail out (e.g. the number of Kaveh's sons differs between retellings — do not state a number).
6. Knowledge entries (دانشنامه) are short, factual, sourced in the chapter brief, and mark what is a game
   reconstruction. AI-written text is `draft` until a human reviewer sets `verified` (see `historical-integrity.md`).
7. Do not add levels to the frozen `skills` chapter. Never reorder or insert levels in the middle of
   `LEVELS` (saved progress is keyed by index): append at the end, inside a NEW chapter.

## Chapter brief template (`documentation/chapters/<id>.md`)
```
# <Persian title> (<id>)
- content_type: literary_myth | mythology | folklore | documented_history | creative_reconstruction
- review: draft | needs_editorial_review | verified | published
- What the child should learn (2-3 sentences, Persian)
- Sources: author/work, edition, section/lines/page, access date (a human must be able to check each claim)
- Story beats -> levels: one row per level: beat | what the player physically does | mechanic reused | difficulty knobs
- What is invented for the game (must be labelled "بازآفرینی تخیلی")
- Knowledge entries and quiz questions (each with its source)
- Open questions for the human reviewer
```

## Steps to add a chapter
1. Brief (above) and owner/reviewer agreement on the story beats.
2. Add the chapter to `LevelData.CHAPTERS` (`sources` is required for myth/folklore/history; selftest enforces it).
3. Append its levels at the END of `LEVELS`, each with `"chapter": "<id>"` (copy the nearest level, follow the
   checklist in `AGENTS.md`). Chapter levels must be consecutive and in the same order as `CHAPTERS`.
4. Difficulty knobs, selftest bot, `--jumptest` when reachability changes, voice script export (see `AGENTS.md`).
5. **Look at it**: take a screenshot (`--shot`, see `AGENTS.md`) of every new level and of the menu
   (`--menu=main` / `--menu=<chapter index>`). Logic tests alone missed visual bugs before (mirror beams drawn as slabs).
6. Update README, `roadmap.md`, `game-design-rules.md`; commit with symptom + root cause.
7. The owner records the new voice lines (`documentation/voice-missing.csv`); convert only the new mp3 files
   (CI converts everything; do not commit `.ogg` of later chapters).

## Chapter queue (proposals — each needs its brief, sources and owner approval first)
Sources named below are starting points to verify, not citations.
1. **Kaveh and Zahhak** (Shahnameh) — Zahhak's tyranny, Kaveh refuses and raises his leather apron on a spear
   (the Kaviani banner), Fereydun takes the throne, Zahhak is bound on Mount Damavand rather than killed.
   Natural verbs: forge/hammer rhythm, carry and raise the banner, climb Damavand, bind (not kill) the tyrant.
   Detail to keep vague: the number of Kaveh's sons (retellings differ). Label what the game invents.
2. **Jamshid and Nowruz** (Shahnameh / Nowruz tradition) — separate the mythic origin story from the documented
   customs of Nowruz; a good place to teach the `literary_myth` vs `documented_history` difference.
3. **Cyrus and the Achaemenids** (documented history) — needs primary/secondary sources (e.g. the Cyrus Cylinder
   as an object in the British Museum, Herodotus) and careful reviewer-approved wording.
4. **Persepolis / the Royal Road and couriers** (documented history) — would give the frozen `night_courier`
   idea a real basis (Herodotus on Persian couriers); rebuild it as part of this chapter, not as a loose level.
5. **Rostam's journey** (Shahnameh) — adventure beats suit many existing mechanics (rolling, bridges, archery).
