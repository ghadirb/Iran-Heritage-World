# هفت‌خانِ رستم (۲): دو خانِ نخست (haft_khan_first) — فصل ۱۱
- content_type: **literary_myth**
- review: **needs_editorial_review**

## آنچه کودک یاد می‌گیرد
در نخستین خان، رستم در نیزار می‌خوابد و رخش از او نگهبانی می‌کند؛ در دومین خان، رستم و رخش در بیابانی بی‌آب می‌مانند و قوچی آن‌ها را به چشمه می‌رساند. این دو خان در فصل ۸ نبودند (در آنجا سه خانِ سوم، چهارم و هفتم بود).

## Sources (accessed 17 Nov 2026; a human reviewer must re-check each claim)
- Primary (lines NOT yet recorded): Ferdowsi, *Shahnameh*, the first and second labours of Rostam. Edition and lines must be added by a human reviewer.
- Encyclopaedia Iranica, "Rostam": first labour: he falls asleep and is attacked by a lion, but Rakhsh fights the beast and kills it; second: he crosses a desert where he almost perishes, but is shown the way to a watering place by a divine guide in the shape of a wild ram.
- Metropolitan Museum of Art, folios 69.74.8 and 69.74.9 ("Rakhsh Kills a Lion while Rustam is Asleep"): the first ordeal is the frequently illustrated Rakhsh and the lion; the second, rarely depicted, has Rustam and Rakhsh nearly die of heat and thirst in the desert before, with divine providence, they find a spring.
- FEZANA Lesson 8 (grades 4–5): Rostam sleeps among the reeds, a fierce lion attacks Rakhsh, who fights it with teeth and heels; Rostam wakes, heals Rakhsh and continues; second stage: the waterless desert.
- Smithsonian Freer|Sackler "Rustam & Rakhsh": Rakhsh seizes the beast by the neck "without disturbing the sleeping Rustam".
- Wikipedia "Rostam's Seven Labours": traditional order; second labour: a sheep passes by, "the harbinger of good".

## Story beats -> levels
| Level | Beat | What the player physically does | Mechanic | Honest label |
|---|---|---|---|---|
| 38 `haft_khan_lion` | first labour: Rostam sleeps, Rakhsh guards him | circles lions around the sleeping hero; runs into a charging lion to make it back off; enough repelled and the labour is done; a lion that reaches Rostam only startles him | **new**: guard (`guard` in level data) | the player guards in Rakhsh's place; the fight is not shown; in the story the lion attacks Rakhsh |
| 39 `haft_khan_desert` | second labour: a ram leads Rostam to a spring | follows a wild ram through the desert to a spring; blue mirages off the path vanish if entered | **new**: follow (`follow` in level data) | the mirages are invented and are not in the story |
| 40 `haft_khan_quiz` | what the story says | three question stands | quiz hall | from the sources above |

## Deliberately left out
- That the lion is killed; the game only has it "back off" (violence toward an animal).
- That the ram is a "divine guide" as a statement of fact: the story says so, the game says "in the story".
- Rakhsh being wounded and Rostam healing him (could be a later level).

## Knowledge entries
`k_haft_khan_lion`, `k_haft_khan_ram`, `k_haft_khan_first_quiz`.
