# Progress Checkpoint

This file is the single source of truth for what's done and what's next.
Every work session (manual or scheduled) should: read this file, pick the
next unchecked item, implement it, verify with the headless smoke test,
update this file, then commit.

## How to verify changes (headless, no GPU/display needed)

```
~/.local/bin/godot4 --headless --path . --import      # catch import/parse errors
~/.local/bin/godot4 --headless --path . --quit-after 2 # catch runtime _ready() errors
```

Both should exit 0 with no `SCRIPT ERROR` / `push_error` output.

## Project spec (user requirements — treat as constraints, not suggestions)

- **Target platform: Windows, windowed** (not fullscreen). `project.godot`'s `[display]` section pins `window/size/mode=0` (windowed) — do not change this to fullscreen. Actually producing a distributable `.exe` still needs Godot's Windows export templates installed (see "Next up" — not done yet); until then "Windows windowed" is satisfied at the project-config level and by testing the editor/debug run, since this dev environment is Linux/WSL2 and can't launch a Windows binary directly.
- **Visual style: ASCII / text-only, deliberately, not a placeholder.** No sprites, no tilesets, no art asset sourcing — not now, not later, unless the user explicitly changes this requirement. Characters and maps are single-character glyphs in monospace-style grid cells. Do not "graduate" this to sprite art on your own initiative.

## Architecture

- `project.godot` — autoloads `DialogueManager` (scripts/dialogue_manager.gd), renderer set to gl_compatibility for headless-friendliness, `[display]` forces windowed mode at 720x480.
- `scenes/Main.tscn` (script `scripts/main.gd`) — the playable scene. On `_ready()` it renders the ASCII map (`_render_map()`) then scans `data/npcs/*.json` and spawns one `scenes/NPC.tscn` instance per file. **No scene editing needed to add an NPC or a map.**
- **ASCII rendering convention**: every visible entity (map tile, player, NPC) is a `Label` control sized to exactly one `TILE_SIZE` (24px) cell, showing one character, `horizontal_alignment`/`vertical_alignment` centered. This is why no monospace font is needed — alignment comes from the fixed-size cell, not from glyph width, so Godot's default font is fine. `main.gd`'s `TILE_SIZE`/`TILE_COLORS`/`tile_center()` are the shared constants; keep any new tile-placing code consistent with them (use `Main.tile_center(col, row)` to position entities on the grid, don't hand-compute pixel offsets).
- `data/maps/*.txt` — plain-text ASCII maps, one line per row, one character per column, all rows equal length. Currently: `#` wall (solid — see collision below), `.` floor. `main.gd._render_map()` reads `MAP_PATH` (currently hardcoded to `village.txt`) and spawns one Label per character via `TILE_COLORS`. Any glyph in `WALL_GLYPHS` also gets a `StaticBody2D` + `RectangleShape2D` covering its tile, so the player collides with it — add new solid glyphs to `WALL_GLYPHS`, not by special-casing `"#"` elsewhere.
- `scenes/Player.tscn` / `scripts/player.gd` — top-down WASD/arrow movement (`CharacterBody2D`), frozen while `DialogueManager.is_active`. Visual is a `Label` showing `@`.
- `scenes/NPC.tscn` / `scripts/npc.gd` — reusable NPC: `Area2D` proximity detection, "!" prompt, `E` to talk. Exported fields (`npc_name`, `dialogue_path`, `portrait_color`, `glyph`) are set programmatically by `main.gd` from the NPC's JSON file, not hand-edited in the scene. Visual is a `Label` showing the one-character `glyph`, tinted `portrait_color`.
- `scripts/game_state.gd` — autoload singleton (`GameState`). Holds a `flags: Dictionary` of story flags, persisted immediately to `user://save.json` on every `set_flag()` call. This is a flags-only save system — player position/inventory aren't tracked (see Next up).
- `scripts/dialogue_manager.gd` — autoload singleton. Loads a dialogue JSON graph, walks nodes, tracks `is_active`. A node with `"set_flag": "name"` sets that `GameState` flag when shown. A choice with `"requires_flag": "name"` / `"requires_not_flag": "name"` is filtered out of the rendered choice list unless the condition holds (see `dialogues/elder.json` for a working example — the sword question changes wording after you've asked it once).
- `scenes/DialogueBox.tscn` / `scripts/dialogue_box.gd` — bottom-of-screen UI. Reveals `text` with a typewriter effect (`RichTextLabel.visible_ratio` animated via `Tween`, speed = `SECONDS_PER_CHARACTER`); pressing Enter/Space/E while typing calls `Tween.custom_step()` to skip straight to full text instead of advancing. Once fully revealed, renders one `Button` per (flag-filtered) choice, or a "press Enter" continue prompt if there are none.

### How to add a new NPC (the workflow the user asked for)

1. Write a dialogue graph: `dialogues/<name>.json`. Shape:
   ```json
   {
     "start": "greet",
     "nodes": {
       "greet": { "speaker": "Name", "text": "...", "choices": [
         { "text": "option A", "next": "node_a" },
         { "text": "option B", "next": "node_b" }
       ]},
       "node_a": { "speaker": "Name", "text": "...", "next": "end" },
       "end": { "speaker": "", "text": "", "end": true }
     }
   }
   ```
   Nodes with `choices` branch; nodes with `next` (and no choices) auto-advance on Enter/Space/E; a node with `"end": true` (or a dangling `next`) closes the dialogue box.
2. Write an NPC definition: `data/npcs/<name>.json`:
   ```json
   { "id": "name", "name": "Display Name", "glyph": "X", "position": [x, y],
     "color": [r, g, b, a], "dialogue": "res://dialogues/<name>.json" }
   ```
   `glyph` is the single character shown on the map (ASCII style — see Project spec). `position` should land on a tile center: `[(col + 0.5) * 24, (row + 0.5) * 24]` for column/row in `data/maps/village.txt`.
3. Run the headless smoke test above. That's it — no `.tscn` editing.

## Done

- [x] Project skeleton, headless Godot 4.7.2 installed at `~/.local/bin/godot4`.
- [x] Player movement (top-down, 4-directional, WASD + arrows).
- [x] Data-driven NPC spawning from `data/npcs/*.json`.
- [x] Branching dialogue system (JSON graph, choices via UI buttons).
- [x] Two example NPCs (Elder, Merchant) each with a branching conversation.
- [x] Headless smoke test passes (import + 2-frame run, exit 0, no errors).
- [x] ASCII-only visual style: map (`data/maps/village.txt`) and entities (player `@`, NPC glyphs) render as one-Label-per-cell text, no sprites/tileset/font asset needed.
- [x] Windowed-mode project config (`[display]` in project.godot, 720x480, mode=0).
- [x] Wall collision (`WALL_GLYPHS`-driven `StaticBody2D` per solid tile).
- [x] Typewriter text reveal in DialogueBox, skippable via `Tween.custom_step()`.
- [x] Dialogue flags (`GameState` autoload, `set_flag`/`requires_flag`/`requires_not_flag`) — verified end-to-end with a temporary headless test harness (start dialogue → typewriter completes → advance → flag set → filtered choice changes on revisit), not just the import-time smoke test. See commit for the throwaway test approach if you need to re-verify a similar timing-dependent feature.
- [x] Flags-only save/load (`user://save.json`, autosaved on every flag change), extended with `player_hp`/`player_max_hp`/`player_attack` when the battle system needed them. **Still not the full "Save/load game state" item below** — player position/current map aren't persisted.
- [x] Windows `.exe` export working end-to-end: Godot 4.7.2 Windows export templates installed at `~/.local/share/godot/export_templates/4.7.2.stable/` (Windows-only subset extracted from the official `.tpz` — android/ios/macos/web templates were skipped to save space, re-extract those from the same `.tpz` release asset if ever needed), `export_presets.cfg` (committed) defines a "Windows Desktop" x86_64 preset. Build with `~/.local/bin/godot4 --headless --path . --export-release "Windows Desktop" build/windows/WanderersVillage.exe`; `build/` is gitignored (regenerate, don't commit the binary). Verified the output is a real `PE32+ ... for MS Windows` executable via `file`, though it can't actually be *run* in this Linux/WSL2 environment — that still needs the user to test on real Windows.
- [x] First battle system slice: `scenes/Battle.tscn` / `scripts/battle.gd`, turn-based Attack/Run against one enemy loaded from `data/enemies/*.json`, text-only UI (status line + scrolling log + two buttons), no animation. Triggered by a dialogue node's `"start_battle": "<enemy_id>"` field (see `dialogue_manager.gd`'s handling and `dialogues/guard.json`/`data/npcs/guard.json` for the working example — talk to the Guard NPC and choose "Let's spar!"). Win heals nothing extra, loss fully heals the player — both just return to `Main.tscn` after a short delay. Verified end-to-end headlessly in both directions (Main→Battle via dialogue trigger, and Battle→Main via a scripted auto-attack loop), not just at parse time — same throwaway-test-hook approach as the dialogue flag verification.

## Next up (in rough priority order)

- [ ] Ask the user to actually test `build/windows/WanderersVillage.exe` on real Windows once there's a way to get it to them (this dev environment has no Windows/Wine to self-verify runtime behavior, only that it's a valid PE executable) — confirm it opens windowed as expected, not fullscreen, and at a reasonable size/position.
- [ ] Battle system depth: multiple enemy types with variety (already data-driven via `data/enemies/*.json`, just need more files + maybe an enemy-pool-per-encounter concept), a real "you lost" consequence instead of a free full heal (e.g. lose gold/return to a fixed point), reward on win (XP/gold — needs those concepts to exist first), more than one player action (e.g. a weak/strong attack, an item).
- [ ] Random/roaming encounters instead of only NPC-triggered battles (e.g. a chance per step while on certain tiles) — build on the same `GameState.pending_battle_enemy` + scene-change mechanism.
- [ ] More map variety: additional glyphs/colors in `TILE_COLORS` (e.g. `~` water, `T` tree, `+` door) and a second map file, once there's a reason (e.g. an outdoor area vs. the current single room).
- [ ] NPC schedules / idle wandering (optional, later).
- [ ] Full save/load game state: extend `game_state.gd` beyond flags+battle-stats to also persist player position/current map once there's more than one map. Keep it additive to the existing save.json format, don't redesign it.
- [ ] Title screen / pause menu.

## Notes / decisions

- Chose JSON over Godot `.tres` Resources for dialogue/NPC data because it's easy for an automated agent (or a human) to hand-edit without touching the Godot editor, and trivial to validate headlessly.
- Renderer is `gl_compatibility` specifically so `--headless` runs (used for automated verification) don't need a GPU.
- Input handling avoids `project.godot`'s `[input]` action-map section entirely (uses `Input.is_key_pressed` / raw `InputEventKey` checks) to avoid hand-authoring the verbose `InputEventKey` resource syntax in that file.
- 2026-09-03: user explicitly requested ASCII-only visuals and a Windows windowed target (see "Project spec" above) — this is a deliberate, permanent art direction, not a temporary placeholder to replace with sprites later. Chose per-cell fixed-size `Label` nodes (one per glyph) over a single multi-line text block specifically so alignment doesn't depend on a monospace font — Godot's default font works fine since each character sits in its own centered `TILE_SIZE` box.
