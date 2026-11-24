# هفت‌خانِ رستم (۳): اولاد و شهر مازندران (haft_khan_mazandaran) — فصل ۱۲
- content_type: **literary_myth**
- review: **needs_editorial_review**

## آنچه کودک یاد می‌گیرد
با این فصل هفت‌خان کامل می‌شود: فصل ۱۱ خان‌های ۱ و ۲، فصل ۸ خان‌های ۳، ۴ و ۷، و این فصل خان‌های ۵ و ۶. در خان پنجم اولاد، پهلوانِ مازندران، به رستم راه غارهای دیوان را نشان می‌دهد؛ در خان ششم رستم به شهر مازندران می‌رود و کیکاووسِ هنوز نابینا را آزاد می‌کند.

## Sources (accessed 22 Nov 2026; a human reviewer must re-check each claim)
- Primary (lines NOT yet recorded): Ferdowsi, *Shahnameh*, the fifth and sixth labours of Rostam. Edition and lines must be added by a human reviewer.
- Wikipedia "Rostam's Seven Labours": 5th: Rostam conquers the Mazandarani champion Olad, who describes the caves of the demons; 6th: Rostam enters the city of Mazandaran and releases Kay Kavus, still blind from the demons' sorcery (this article also places the killing of Arzhang Div here).
- FEZANA Lesson 8 (grades 4–5): fifth stage: Rostam conquers Olad, who describes the caves of the demons, and (in this source) kills Arzhang Div; sixth: Rostam enters the city and frees Kay Kavus, still blind.
- RISD Museum, "Rustam Compels Aulad to Lead Him to the White Demon" (Timurid school): Rustam forces the provincial king Aulad to guide him to the imprisoned Kay Kavus.
- Fitzwilliam Museum Shahnameh pages ("Rostam slays the White Div", Royal Asiatic Society MS 239): Rostam's "enforced guide" Owlad.
- The sources DISAGREE about where Arzhang Div is killed (5th or 6th labour); the game does not say.

## Story beats -> levels
| Level | Beat | What the player physically does | Mechanic | Honest label |
|---|---|---|---|---|
| 41 `haft_khan_olad` | fifth labour: Olad is made to guide Rostam towards the demons' caves | follows Olad through a dark forest; false torches off the path vanish if entered | follow (`follow.guide: "olad"`, `follow_msg_prefix: olad`) | the false torches are invented; the forest and pace are reconstruction |
| 42 `haft_khan_city` | sixth labour: Rostam enters the city of Mazandaran and frees Kay Kavus | slips between shade stands under the turning lantern beams of the city's watch | stealth timing (`night_watch`, `watch_msg_prefix: city`) | the watch lanterns and shade stands are invented |
| 43 `haft_khan_mazandaran_quiz` | what the story says | four question stands | quiz hall | from the sources above |

## Deliberately left out
- Any statement of where Arzhang Div dies (sources differ).
- The capture of Olad by force, and any killing (only "made to guide him").
- The White Div and the cure: they are in chapter 8 (level 31).

## Knowledge entries
`k_haft_khan_olad`, `k_haft_khan_city`, `k_haft_khan_mazandaran_quiz`.
