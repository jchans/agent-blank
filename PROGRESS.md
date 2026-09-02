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

## Architecture

- `project.godot` — autoloads `DialogueManager` (scripts/dialogue_manager.gd), renderer set to gl_compatibility for headless-friendliness.
- `scenes/Main.tscn` (script `scripts/main.gd`) — the playable scene. On `_ready()` it scans `data/npcs/*.json` and spawns one `scenes/NPC.tscn` instance per file. **No scene editing needed to add an NPC.**
- `scenes/Player.tscn` / `scripts/player.gd` — top-down WASD/arrow movement (`CharacterBody2D`), frozen while `DialogueManager.is_active`.
- `scenes/NPC.tscn` / `scripts/npc.gd` — reusable NPC: `Area2D` proximity detection, "!" prompt, `E` to talk. Exported fields (`npc_name`, `dialogue_path`, `portrait_color`) are set programmatically by `main.gd` from the NPC's JSON file, not hand-edited in the scene.
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
   { "id": "name", "name": "Display Name", "position": [x, y],
     "color": [r, g, b, a], "dialogue": "res://dialogues/<name>.json" }
   ```
3. Run the headless smoke test above. That's it — no `.tscn` editing.

## Done

- [x] Project skeleton, headless Godot 4.7.2 installed at `~/.local/bin/godot4`.
- [x] Player movement (top-down, 4-directional, WASD + arrows).
- [x] Data-driven NPC spawning from `data/npcs/*.json`.
- [x] Branching dialogue system (JSON graph, choices via UI buttons).
- [x] Two example NPCs (Elder, Merchant) each with a branching conversation.
- [x] Headless smoke test passes (import + 2-frame run, exit 0, no errors).

## Next up (in rough priority order)

- [ ] Tilemap-based map instead of a flat green Polygon2D placeholder (needs a tileset — either draw simple placeholder tiles or source a CC0 tileset).
- [ ] Player sprite animation (currently a plain ColorRect placeholder) — walk cycles, directional facing.
- [ ] Typewriter text reveal effect in DialogueBox for polish.
- [ ] Dialogue conditions/flags: let a choice set a flag (e.g. `"set_flag": "met_elder"`) and a node's availability depend on flags (e.g. quest-gated dialogue). Needs a small global `GameState` autoload holding a flags dictionary, persisted to `user://save.json`.
- [ ] NPC schedules / idle wandering (optional, later).
- [ ] JRPG battle system (turn-based) — separate scene, triggered from an encounter zone or dialogue action. This is the biggest remaining chunk of work; break it into its own sub-checklist here once started.
- [ ] Save/load game state.
- [ ] Title screen / pause menu.
- [ ] Basic export preset (Linux + Web) once there's enough content to be worth packaging.

## Notes / decisions

- Chose JSON over Godot `.tres` Resources for dialogue/NPC data because it's easy for an automated agent (or a human) to hand-edit without touching the Godot editor, and trivial to validate headlessly.
- Renderer is `gl_compatibility` specifically so `--headless` runs (used for automated verification) don't need a GPU.
- Input handling avoids `project.godot`'s `[input]` action-map section entirely (uses `Input.is_key_pressed` / raw `InputEventKey` checks) to avoid hand-authoring the verbose `InputEventKey` resource syntax in that file.
