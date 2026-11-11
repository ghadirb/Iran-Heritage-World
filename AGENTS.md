# AGENTS.md — read this before changing the game

Project: **Iran Heritage World** (Godot 4.4.1, GL Compatibility, Android). A 3D educational
adventure for children based on Iranian history and myth. Branch in use: `codex/bootstrap-godot-mvp`.
Full design rules (Persian): `documentation/game-design-rules.md`.

## The one rule that defines how we build levels
**Every new level must contain a real physical action, not only "walk up and press Interact".**
Interact is for dialogue, reading, collecting and confirming. The *challenge* of a level must come
from movement and physics: jumping, timing, carrying, pushing, aiming, avoiding.
A level that is only "find 3 glowing things" is not acceptable as a new level.

Mechanics already in the game (reuse before inventing):
| Level | Real action | Where |
|---|---|---|
| stone_pass | jump across a chasm; some stones slide sideways and carry the player | `_build_platform_chain`, `_physics_process`, `DifficultyRules._pick_moving_stones` |
| simorgh_nest | fire puzzle (order from a riddle on medium/challenge) | `_use_brazier` |
| (planned) | carry firewood to braziers, push a log to bridge a river, bow aiming, chase/flee | see design doc section 4 |

## Difficulty is mandatory, not optional
Three levels: 0 easy (original data), 1 medium (default), 2 challenge. They are NOT hand-written
copies of levels. `LevelData` stays the easy/base version and `DifficultyRules.apply()` derives
harder variants at load time. When you add a mechanic, add its difficulty knobs in
`difficulty_rules.gd` (speed, count, distance, tolerance) so the same level suits a young child and
a faster player. Too easy ends the game in minutes; too hard makes a child quit: stay between.

## Hard constraints (do not break)
1. **A level must always be finishable.** Falling = respawn at the last *static* checkpoint (never
   on something that moves away). Nothing may be placed below `kill_y` or in the river.
2. **Run the self-test before every commit** and make sure it prints `SELFTEST OK`:
   ```
   godot --headless --editor --path app --quit          # import once
   godot --headless --path app -- --selftest            # loads every level at all 3 difficulties
   ```
   Add a check to `_selftest_difficulty_sanity()` / a carry-style physics test for every new mechanic.
3. **Voice narration**: recorded `.ogg` lines read the *original* text. If a difficulty variant changes
   intro/objective text, set `lv["no_level_voice"] = true` (see `DifficultyRules`). Do not change
   original `LevelData` text without updating `documentation/voice-script.csv` and the audio.
4. **Content honesty**: myth and literature are labelled as such (`content_type`). Quiz questions and
   knowledge entries must come from the sourced content in-game or be reviewed; never invent history.
   See `documentation/historical-integrity.md`.
5. **Weak phones**: keep the light default (quality 0, no shadows on mobile). Avoid heavy per-frame
   work; prefer procedural meshes/MultiMesh as now. Do not add large assets without need.
6. **Persian UI**: all player text in Persian, large touch targets, works with `ui_scale`.
7. **Small, surgical commits.** Commit message explains the *symptom* and the *root cause*, then the fix
   and how it was verified. Do not rewrite files wholesale.
8. **Never commit tokens/keys**, and never paste them into files or logs. Tokens are revoked by the owner.

## How to add a new level (checklist)
1. Add an entry to `LevelData.LEVELS` (copy the nearest existing one). Include `content_type`, intro,
   objective, `knowledge` entry.
2. Decide the **real action** and implement it generically (data keys, not hard-coded ids where possible).
3. Add difficulty knobs in `DifficultyRules` and make objective text number-free if counts change.
4. Extend the self-test (finishability, physics behaviour).
5. Update `README.md` level list, `documentation/roadmap.md` and the mechanics table above.
6. Test on a real phone via the *Build Android APK* workflow, then record findings in the roadmap.
