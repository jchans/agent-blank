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
- [x] Title screen (`scenes/TitleScreen.tscn` / `scripts/title_screen.gd`, now `run/main_scene`): press Enter/Space to go to `Main.tscn`.
- [x] Pause menu (`scenes/PauseMenu.tscn` / `scripts/pause_menu.gd`, instanced in `Main.tscn`'s CanvasLayer): Escape toggles `SceneTree.paused` + shows/hides a Resume/Quit panel. The menu's own `process_mode = PROCESS_MODE_ALWAYS` is why it keeps responding while everything else (correctly) freezes. Ignored while a dialogue is active. **Found and fixed a real bug while verifying this headlessly**: don't `await` again on a node's own coroutine after that same node has triggered `change_scene_to_file` on itself — the node gets freed once the deferred scene change lands, so anything after the next `await` point silently never runs (no error, just dead code) if it's on `self`; capture `get_tree()` into a local var first if you need the tree object specifically, but don't expect the node to still exist. `title_screen.gd`'s test hook hit this; the real `_unhandled_input` handler doesn't (no `await` involved there), and `dialogue_manager.gd`/`battle.gd` are safe because in both cases the `await` happens *before* the scene change, or on an autoload that's never freed by scene changes — not after it, on a node that's about to be freed.

- [x] Player position save/load: `GameState.player_position` is kept in sync every frame from `Main._process()`, written to `save.json` on every `save_game()` call (flag change, battle end, and now also opening the pause menu — a natural checkpoint). `GameState.has_saved_position` distinguishes "fresh game, use Main.tscn's default spawn" from "resume, override spawn position" — `Main._ready()` checks it. Title screen prompt now reads "Press Enter to Continue" vs "...to Start" based on the same flag. `current_map` isn't tracked yet since there's still only one map — add it additively when a second exists, don't redesign the format. Verified headlessly (position round-trips through save/load correctly); note for next time: `SceneTree.process_frame` fires *before* that frame's `_process()` calls, not after — a test that sets a value then awaits `process_frame` once and expects `_process` to have already synced it needs two awaits, not one.
- [x] **Fixed a real Windows-export bug the user hit** ("press Enter on the title screen and the game crashes/breaks"): `data/maps/village.txt` was silently missing from the exported `.pck` even though `export_filter="all_resources"`. Cause: Godot 4 tags `.txt` files as its internal "TextFile" resource type (visible in `.godot/editor/filesystem_cache10` as `village.txt::TextFile::...`, vs. `elder.json::JSON::...` for the sibling data files) and the exporter doesn't pack that type under `all_resources` the way it packs plain/JSON files. Fix: added `include_filter="*.txt"` to the `Windows Desktop` preset in `export_presets.cfg`. Verified by re-exporting and grepping the export log — `Storing File: res://data/maps/village.txt` now appears; it didn't before. With the map missing, `Main._render_map()` (`scripts/main.gd`) fails its `FileAccess.open` and just `push_warning`s + returns, so the world would render with no floor/walls/collision rather than a hard engine crash — but this is the only concrete defect found after also checking the title→Main scene transition, dialogue/battle/pause-menu wiring, and a full headless run of `Main.tscn`, all of which came back clean. Rebuilt `build/windows/WanderersVillage.exe` with the fix; **still needs the user to confirm on real Windows that Enter no longer breaks the game** — if it does, get the exact symptom (black screen vs. window closes vs. error dialog text) since this session has no Windows/Wine to reproduce further.

## Next up (in rough priority order)

- [ ] User reported (2026-09-03, after the map-file fix below) that pressing Enter on the title screen *still* crashes the exported .exe. Re-checked everything reachable from this environment: re-ran the headless import + 2-frame smoke test (clean), re-exported and grepped the export log — `village.txt`, all `data/npcs/*.json`, all `dialogues/*.json`, and every `scenes/*.tscn` are all packed. Read through `title_screen.gd`, `main.gd`, `game_state.gd`, `player.gd`, `npc.gd` end-to-end for anything that could hard-crash on the Main.tscn transition (vs. `push_warning`-and-continue) — found nothing. Can't reproduce further: this Linux/WSL2 box has no Wine, so the exported PE32+ binary literally cannot be run here. Turned on the Windows export's console (`export_presets.cfg`: `debug/export_console_wizard` 1→2, "Editor Only"→"Yes") and rebuilt, so the next crash will pop a console window with Godot's actual stdout/stderr instead of failing silently — **need the user to run this new build and report exactly what they see**: does a game window open at all, does a console window also open, what's the last few lines printed in it (or a screenshot), does it close immediately vs. hang, any Windows error dialog text. That's what's needed to actually diagnose this rather than guess again.
- [ ] Battle system depth: multiple enemy types with variety (already data-driven via `data/enemies/*.json`, just need more files + maybe an enemy-pool-per-encounter concept), a real "you lost" consequence instead of a free full heal (e.g. lose gold/return to a fixed point), reward on win (XP/gold — needs those concepts to exist first), more than one player action (e.g. a weak/strong attack, an item). Note: `auto-progress` branch already has gold-on-win + a second enemy (Goblin) done, not yet merged to `main` as of this writing — check `git log main..auto-progress` before redoing this.
- [ ] Random/roaming encounters instead of only NPC-triggered battles (e.g. a chance per step while on certain tiles) — build on the same `GameState.pending_battle_enemy` + scene-change mechanism.
- [ ] More map variety: additional glyphs/colors in `TILE_COLORS` (e.g. `~` water, `T` tree, `+` door) and a second map file, once there's a reason (e.g. an outdoor area vs. the current single room). Once a second map exists, extend the save format with `current_map` (see the Done entry above).
- [ ] NPC schedules / idle wandering (optional, later).
- [ ] Pause menu polish: a Settings/keybinds screen, maybe a quit-to-title option.

## Notes / decisions

- Chose JSON over Godot `.tres` Resources for dialogue/NPC data because it's easy for an automated agent (or a human) to hand-edit without touching the Godot editor, and trivial to validate headlessly.
- Renderer is `gl_compatibility` specifically so `--headless` runs (used for automated verification) don't need a GPU.
- Input handling avoids `project.godot`'s `[input]` action-map section entirely (uses `Input.is_key_pressed` / raw `InputEventKey` checks) to avoid hand-authoring the verbose `InputEventKey` resource syntax in that file.
- 2026-09-03: user explicitly requested ASCII-only visuals and a Windows windowed target (see "Project spec" above) — this is a deliberate, permanent art direction, not a temporary placeholder to replace with sprites later. Chose per-cell fixed-size `Label` nodes (one per glyph) over a single multi-line text block specifically so alignment doesn't depend on a monospace font — Godot's default font works fine since each character sits in its own centered `TILE_SIZE` box.
