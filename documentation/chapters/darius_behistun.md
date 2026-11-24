# داریوش و کتیبه‌ی بیستون (darius_behistun) — فصل ۹
- content_type: documented_history (مرحله‌ها بازآفرینی تخیلی‌اند و در متن برچسب خورده‌اند)
- review: **needs_editorial_review**

## آنچه کودک یاد می‌گیرد
کتیبه‌ی بیستون (کرمانشاه) را داریوش یکم به سه زبان و خط میخی (پارسی باستان، ایلامی، بابلی) حک کرد؛ رونویسی آن در سده‌ی نوزدهم کلید خواندنِ خط میخی شد. و باز همان درسِ فصل ۶: این روایتِ خودِ شاه است و برخی پژوهشگران در درستی آن تردید دارند.

## Sources (accessed 17 Nov 2026; a human reviewer must re-check each claim)
- UNESCO World Heritage Centre, "Behistun" (ref. 1222, inscribed 2006) and the nomination file (the monument ~100 m above the plain; three languages; "the oldest is an Elamite text ... followed by a Babylonian version ... the last phase: Old Persian"; Darius had the Old Persian script made for the inscription).
- Encyclopaedia Britannica, "Bīsitūn": Darius I (reigned 522–486 BC) records that after the death of Cambyses II he killed the usurper Gaumata and defeated the rebels; written in Babylonian, Old Persian and Elamite; Rawlinson's work on the Old Persian text led to the decipherment.
- World History Encyclopedia (J. J. Mark), "Behistun Inscription": carved ~100 m up the cliff in Kermanshah; the account is Darius's own and "the truth of it has been challenged by a number of modern-day scholars".
- Wikipedia "Behistun Inscription" (secondary, for the story of Rawlinson crossing the gap with planks to copy the Elamite text, 1843).

## Story beats -> levels
| Level | Beat | What the player physically does | Mechanic reused | Honest label |
|---|---|---|---|---|
| 33 `behistun_panels` | the inscription was composed in three languages (Elamite oldest, then Babylonian, last Old Persian — UNESCO) | carries three panels to three places in that order | carry (`carry_visual: stone`, `carry_msg_prefix: panel`) | the panels/places are game reconstruction; the real text is carved in the rock |
| 34 `behistun_cliff` | Rawlinson bridged a gap on the cliff with planks to copy the Elamite text | crosses shaky ledges between fixed rest pads | sinking stones (`stones_*_msg: cliff_*`, `water: false`) | the crumbling ledges are invented; only the planks story is documented |
| 35 `darius_quiz` | what the sources say, including that the account is Darius's own | four question stands | quiz hall | from the sources above |

## Deliberately left out
- Exact line counts of each version (sources disagree: Elamite 260 vs 593 lines).
- Who climbed to the Babylonian text (a local boy; accounts vary).
- The year numbers of Rawlinson's decipherment (sources differ: 1838/1846/1847).
- Any claim that Darius's account of Gaumata is true or false: only "his own account, contested by some scholars".

## Knowledge entries
`k_behistun`, `k_rawlinson`, `k_behistun_quiz`.
