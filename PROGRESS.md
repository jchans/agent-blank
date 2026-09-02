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
- `data/maps/*.txt` — plain-text ASCII maps, one line per row, one character per column, all rows equal length. Currently: `#` wall (visual only, no collision yet — see Next up), `.` floor. `main.gd._render_map()` reads `MAP_PATH` (currently hardcoded to `village.txt`) and spawns one Label per character via `TILE_COLORS`.
- `scenes/Player.tscn` / `scripts/player.gd` — top-down WASD/arrow movement (`CharacterBody2D`), frozen while `DialogueManager.is_active`. Visual is a `Label` showing `@`.
- `scenes/NPC.tscn` / `scripts/npc.gd` — reusable NPC: `Area2D` proximity detection, "!" prompt, `E` to talk. Exported fields (`npc_name`, `dialogue_path`, `portrait_color`, `glyph`) are set programmatically by `main.gd` from the NPC's JSON file, not hand-edited in the scene. Visual is a `Label` showing the one-character `glyph`, tinted `portrait_color`.
- `scripts/dialogue_manager.gd` — autoload singleton. Loads a dialogue JSON graph, walks nodes, tracks `is_active`.
- `scenes/DialogueBox.tscn` / `scripts/dialogue_box.gd` — bottom-of-screen UI. Renders speaker/text; renders one `Button` per choice when a node has `choices`, otherwise shows a "press Enter" continue prompt.

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

## Next up (in rough priority order)

- [ ] Wall collision: `#` tiles in `data/maps/*.txt` are currently visual-only — player can walk through walls. Add a `StaticBody2D` + `CollisionShape2D` per wall tile in `_render_map()` (or a single `TileMap`-based physics layer if that turns out simpler); keep the ASCII rendering as-is either way.
- [ ] Windows `.exe` export: needs Godot 4.7.2's Windows export templates downloaded (`godot4 --headless --export-templates` or manually into `~/.local/share/godot/export_templates/4.7.2.stable/`), then an export preset added via `--headless --export-release "Windows Desktop" build/game.exe`. This is a bigger, mostly-mechanical task — do it as its own increment, verify the produced .exe's file type with `file` even though it can't be run here (no Windows/Wine in this environment).
- [ ] More map variety: additional glyphs/colors in `TILE_COLORS` (e.g. `~` water, `T` tree, `+` door) and a second map file, once there's a reason (e.g. an outdoor area vs. the current single room).
- [ ] Typewriter text reveal effect in DialogueBox for polish.
- [ ] Dialogue conditions/flags: let a choice set a flag (e.g. `"set_flag": "met_elder"`) and a node's availability depend on flags (e.g. quest-gated dialogue). Needs a small global `GameState` autoload holding a flags dictionary, persisted to `user://save.json`.
- [ ] NPC schedules / idle wandering (optional, later).
- [ ] JRPG battle system (turn-based) — separate scene, triggered from an encounter zone or dialogue action. This is the biggest remaining chunk of work; break it into its own sub-checklist here once started.
- [ ] Save/load game state.
- [ ] Title screen / pause menu.

## Notes / decisions

- Chose JSON over Godot `.tres` Resources for dialogue/NPC data because it's easy for an automated agent (or a human) to hand-edit without touching the Godot editor, and trivial to validate headlessly.
- Renderer is `gl_compatibility` specifically so `--headless` runs (used for automated verification) don't need a GPU.
- Input handling avoids `project.godot`'s `[input]` action-map section entirely (uses `Input.is_key_pressed` / raw `InputEventKey` checks) to avoid hand-authoring the verbose `InputEventKey` resource syntax in that file.
- 2026-09-03: user explicitly requested ASCII-only visuals and a Windows windowed target (see "Project spec" above) — this is a deliberate, permanent art direction, not a temporary placeholder to replace with sprites later. Chose per-cell fixed-size `Label` nodes (one per glyph) over a single multi-line text block specifically so alignment doesn't depend on a monospace font — Godot's default font works fine since each character sits in its own centered `TILE_SIZE` box.
