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
| simorgh_nest | **carry firewood** (slows you down) to the fires; fire order from a riddle on medium/challenge; wrong fire returns the wood | `_pick_log`, `_drop_log`, `_return_log`, `_use_brazier`, `DifficultyRules._scatter_logs` |
| return_to_plain | push tree trunks (`pushable` RigidBody3D) into the bridge slot | `_build_bridge`, `_update_bridge` |
| balance_gate | push weighted millstones onto a pan so the weights match the target | `_build_scale_gate`, `_update_scale` |
| archers_field | **bow shooting**: aim with the camera crosshair, shoot button (key F), arrow flies and sticks in the target; targets shrink/move with difficulty; stars from arrows per target | `_shoot`, `_update_archery`, `_target_hit`, `_selftest_archery` |
| misty_escape | **chase/escape**: run through the glowing gaps in mist gates before a non-violent shadow catches up; a catch resets to the fixed start | `chase_controller.gd`, `_update_chase`, `_selftest_chase` |
| wind_path | **timing/avoid**: wait for a moving gust to sweep aside, then run across its line; a hit returns to the last static checkpoint | `wind_course_controller.gd`, `_update_wind_course`, `_selftest_wind_course` |
| clay_waterway | **physical rolling**: push a clay ball down a guiding channel to its marker; a lost ball resets to its fixed home | `rolling_course_controller.gd`, `_update_rolling_course`, `_selftest_rolling_course` |
| turning_bridge | **balance/jump**: cross narrow rotating beams over a chasm; falling only returns to a static rest pad | `turning_bridge_controller.gd`, `_update_turning_bridge`, `_selftest_turning_bridge` |

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
   Also run `godot --headless --path app -- --jumptest` (a bot that really jumps across the stone pass at all 3
   difficulties; must print `JUMPTEST OK`). The chasm lips must stay sharp (`chasm.edge`), otherwise the player
   slides off a long slope and can never reach the first stone.
   Add a check to `_selftest_difficulty_sanity()` / a carry-style physics test for every new mechanic.
3. **Voice narration**: every narrated sentence is listed by `VoiceLines.all_lines()` (single source of truth).
   Recorded audio reads exact text, so: never edit existing `LevelData` text silently (it breaks the recording);
   a reworded difficulty variant gets its own key (`<level>__intro_d1`, `__objective_d2`, set via `lv["voice_*"]` in
   `DifficultyRules`); any new clue/quiz/NPC/`intro_extra` text is picked up by `VoiceLines` automatically.
   After adding text, run `godot --headless --path app -s ../tools/export_voice_script.gd`, commit the regenerated
   `documentation/voice-script.csv` and `voice-missing.csv` (the lines the owner must record). Missing audio is
   never an error: the game stays silent for that line. Short messages shown to the player (toasts) must come from
   `GameMessages` (text defined once, voiced as `game__<id>` / `<level>__fire_lit_<id>` ...), never as literals in
   `world_controller`; use `_say()` / `_msg()` so they are also spoken in automatic narration mode. Quiz answer options
   are narrated as `<quiz>_opt<N>` (N = original option number; the game shuffles options on medium/challenge). Use only voices from `documentation/voice-characters.md`;
   one character = one voice.
4. **Content honesty**: myth and literature are labelled as such (`content_type`). Quiz questions and
   knowledge entries must come from the sourced content in-game or be reviewed; never invent history.
   See `documentation/historical-integrity.md`.
5. **Weak phones**: keep the light default (quality 0, no shadows on mobile). Avoid heavy per-frame
   work; prefer procedural meshes/MultiMesh as now. Do not add large assets without need.
6. **Persian UI**: all player text in Persian, large touch targets, works with `ui_scale`.
7. **Small, surgical commits.** Commit message explains the *symptom* and the *root cause*, then the fix
   and how it was verified. Do not rewrite files wholesale.
8. **Never keep a freed node in an item dict**: after `queue_free()` set `it["node"] = null` (typed reads of freed nodes spam `SCRIPT ERROR`; the selftest log must have zero of them).
9. **Never commit tokens/keys**, and never paste them into files or logs. Tokens are revoked by the owner.

## How to add a new level (checklist)
1. Add an entry to `LevelData.LEVELS` (copy the nearest existing one). Include `content_type`, intro,
   objective, `knowledge` entry.
2. Decide the **real action** and implement it generically (data keys, not hard-coded ids where possible).
3. Add difficulty knobs in `DifficultyRules` and make objective text number-free if counts change.
4. Extend the self-test (finishability, physics behaviour).
5. Update `README.md` level list, `documentation/roadmap.md` and the mechanics table above.
6. Test on a real phone via the *Build Android APK* workflow, then record findings in the roadmap.

## Physical-action rule (owner decision)
The interact button is for **conversation only** (NPCs, question pedestals). Everything else is physical and automatic:
clues/banners are collected by walking into them, firewood is picked up by walking onto it and burned by walking
into the right fire, tree trunks are pushed by running into them (`pushable` RigidBody3D) until they reach the
bridge slot, millstones are pushed onto a pan (chapter 6, weights must sum to the target). Each chapter gets a
*different* real action. Chapter 7 (archers_field) adds bow shooting: the **shoot button** (`TouchControls.shoot_pressed`, key F) is the only
extra button and appears only in chapters that declare `"archery"`; the interact button stays conversation-only.
The arrow leaves the chest and converges on the crosshair ray at the depth of the target the crosshair is nearest to,
so what you aim at is what you hit (moving targets need a lead). Archery chapters use an over-the-shoulder camera
(`player.spring.position`, because `SpringArm3D` overrides a child camera's own position) so the character never
hides the target. Chapter 8 uses a nonviolent mist chase through moving safe gaps; chapter 9 uses timed
wind gusts, with collision returning the player only to their last static checkpoint. Chapter 10 has a physical clay-ball
rolling course; its ball is a RigidBody3D and its recovery point is fixed.
Chapter 11 uses rotating `AnimatableBody3D` beams with fixed rest-pad checkpoints.
Developer helper to look at a chapter without a phone (needs `xvfb-run` and mesa):
`xvfb-run -a godot --rendering-driver opengl3 --path app -- --shot=/tmp/a.png --level=6 --z=8 --shoot=40`
(`--shoot=N` fires at the first target and captures N physics frames later). The mist chase lives in
`chase_controller.gd`: it has no collision damage, a catch only resets to the fixed start, and the
three difficulty knobs stay in `DifficultyRules`. Every new mechanic
needs a headless bot/test in `--selftest` (see `_selftest_bridge`, `_selftest_logs`) and a `--jumptest`-style check
when it affects reachability.
