extends Node2D

## Spawns one NPC per JSON file under data/npcs/ that matches the current
## room, and renders the current room's ASCII map. Adding a new NPC/room
## requires no scene editing — see "How to add a new NPC"/"How to add a
## new room" in PROGRESS.md.
##
## Rooms are data/maps/<id>.txt (ASCII grid, one Label per character, same
## as before) plus a sibling data/maps/<id>.doors.json listing door tiles:
## walking onto one swaps the whole room in place (no change_scene_to_file
## per room — that path is reserved for Title/Battle transitions).

const NPC_SCENE := preload("res://scenes/NPC.tscn")
const NPC_DATA_DIR := "res://data/npcs/"
const MAP_DATA_DIR := "res://data/maps/"
const WORLD_ITEM_SCENE := preload("res://scenes/WorldItem.tscn")
const WORLD_ITEM_DATA_DIR := "res://data/map_items/"

const TILE_SIZE := 24.0
const TILE_FONT_SIZE := 18
const TILE_COLORS := {
	"#": Color(0.55, 0.5, 0.45),
	".": Color(0.28, 0.42, 0.24),
	"~": Color(0.3, 0.5, 0.65),
	"T": Color(0.25, 0.45, 0.2),
	"+": Color(0.65, 0.5, 0.3),
	"o": Color(0.8, 0.7, 0.3),
	"R": Color(0.9, 0.8, 0.2),
}
const TILE_COLOR_DEFAULT := Color(0.6, 0.6, 0.6)
## Solid/blocking glyphs. "+" (door) and "o"/"R" (shrine/relic decoration)
## are deliberately not here — doors must be walkable to trigger, and the
## decoration is just flavor.
const WALL_GLYPHS := ["#", "T"]

@onready var player: CharacterBody2D = $Player

## Everything _load_map spawned (tile labels, wall colliders, NPCs) so the
## next call can clear it. queue_free() is deferred, which is fine here —
## the replacement nodes get different instances, so a stray frame of
## overlap during a door transition is harmless.
var _spawned_nodes: Array[Node] = []
## "<col>,<row>" -> {"target_map": String, "target_spawn": [col, row], "requires_flag": String (optional)}
var _doors: Dictionary = {}


func _ready() -> void:
	_load_map(GameState.current_map)
	if GameState.has_saved_position:
		player.position = GameState.player_position


func _process(_delta: float) -> void:
	GameState.player_position = player.position
	_check_door_crossing()


## World-space center of tile (col, row), for positioning player/NPCs.
static func tile_center(col: int, row: int) -> Vector2:
	return Vector2((col + 0.5) * TILE_SIZE, (row + 0.5) * TILE_SIZE)


func _load_map(map_id: String) -> void:
	# WorldItem is the one spawned-node type that can free itself mid-visit
	# (see world_item.gd's _collect()), so _spawned_nodes can already hold
	# a stale reference by the time a room reload gets here — guard against
	# re-freeing it.
	for node in _spawned_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_spawned_nodes.clear()
	_doors.clear()
	GameState.current_map = map_id
	_load_doors(MAP_DATA_DIR + map_id + ".doors.json")
	_render_map(MAP_DATA_DIR + map_id + ".txt")
	_spawn_npcs(map_id)
	_spawn_world_items(map_id)


func _check_door_crossing() -> void:
	if DialogueManager.is_active or Controls.is_help_open:
		return
	var col := int(floor(player.position.x / TILE_SIZE))
	var row := int(floor(player.position.y / TILE_SIZE))
	var door: Dictionary = _doors.get("%d,%d" % [col, row], {})
	if door.is_empty():
		return
	var requires_flag: String = door.get("requires_flag", "")
	if requires_flag != "" and not GameState.has_flag(requires_flag):
		return
	var target_map: String = door.get("target_map", "")
	if target_map == "":
		return
	var target_spawn: Array = door.get("target_spawn", [0, 0])
	_load_map(target_map)
	player.position = tile_center(int(target_spawn[0]), int(target_spawn[1]))
	GameState.player_position = player.position
	GameState.save_game()


func _render_map(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Main: could not open map file: %s" % path)
		return
	var row := 0
	while not file.eof_reached():
		var line := file.get_line()
		if line == "":
			row += 1
			continue
		for col in range(line.length()):
			_spawn_tile(line[col], col, row)
		row += 1
	file.close()


func _spawn_tile(glyph: String, col: int, row: int) -> void:
	glyph = _visible_glyph(glyph, col, row)
	var label := Label.new()
	label.text = glyph
	label.add_theme_color_override("font_color", TILE_COLORS.get(glyph, TILE_COLOR_DEFAULT))
	label.add_theme_font_size_override("font_size", TILE_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(col * TILE_SIZE, row * TILE_SIZE)
	label.size = Vector2(TILE_SIZE, TILE_SIZE)
	add_child(label)
	_spawned_nodes.append(label)

	if glyph in WALL_GLYPHS:
		_spawn_wall_collider(col, row)


## A map tile that's really a flag-gated door (e.g. a portal that should
## only appear once a quest condition is met) shouldn't be visible before
## its flag is set, even though the door itself already correctly refuses
## to trigger until then (_check_door_crossing). Requires _doors to already
## be populated, so _load_map calls _load_doors before _render_map.
func _visible_glyph(glyph: String, col: int, row: int) -> String:
	var door: Dictionary = _doors.get("%d,%d" % [col, row], {})
	var requires_flag: String = door.get("requires_flag", "")
	if requires_flag != "" and not GameState.has_flag(requires_flag):
		return "."
	return glyph


func _spawn_wall_collider(col: int, row: int) -> void:
	var body := StaticBody2D.new()
	body.position = tile_center(col, row)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	_spawned_nodes.append(body)


func _load_doors(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Main: could not open doors file: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Main: invalid doors file: %s" % path)
		return
	for entry in parsed:
		var pos: Array = entry.get("position", [])
		if pos.size() != 2:
			continue
		_doors["%d,%d" % [int(pos[0]), int(pos[1])]] = entry


func _spawn_npcs(map_id: String) -> void:
	var dir := DirAccess.open(NPC_DATA_DIR)
	if dir == null:
		push_warning("Main: could not open NPC data dir: %s" % NPC_DATA_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_spawn_npc_from_file(NPC_DATA_DIR + file_name, map_id)
		file_name = dir.get_next()
	dir.list_dir_end()


func _spawn_npc_from_file(path: String, map_id: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Main: could not open NPC data file: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Main: invalid NPC data file: %s" % path)
		return
	if parsed.get("map", "village") != map_id:
		return

	var npc := NPC_SCENE.instantiate()
	var pos: Array = parsed.get("position", [0, 0])
	npc.position = Vector2(pos[0], pos[1])
	var col: Array = parsed.get("color", [1, 1, 1, 1])
	npc.portrait_color = Color(col[0], col[1], col[2], col[3] if col.size() > 3 else 1.0)
	npc.npc_name = parsed.get("name", "NPC")
	npc.dialogue_path = parsed.get("dialogue", "")
	npc.glyph = parsed.get("glyph", "N")
	npc.name = String(parsed.get("id", "NPC"))
	add_child(npc)
	_spawned_nodes.append(npc)


## Same one-file-per-object, "map" field scoping convention as NPCs (see
## "How to add a world item" in PROGRESS.md). Each file additionally
## carries "collected_flag" (defaulted from "id" if omitted) — an item
## already collected is a permanently set GameState flag, so it's simply
## never spawned again rather than needing per-room "already taken" state.
func _spawn_world_items(map_id: String) -> void:
	var dir := DirAccess.open(WORLD_ITEM_DATA_DIR)
	if dir == null:
		push_warning("Main: could not open world item data dir: %s" % WORLD_ITEM_DATA_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_spawn_world_item_from_file(WORLD_ITEM_DATA_DIR + file_name, map_id)
		file_name = dir.get_next()
	dir.list_dir_end()


func _spawn_world_item_from_file(path: String, map_id: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Main: could not open world item data file: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Main: invalid world item data file: %s" % path)
		return
	if parsed.get("map", "") != map_id:
		return
	var item_id: String = String(parsed.get("id", "item"))
	var collected_flag: String = parsed.get("collected_flag", "world_item_%s_taken" % item_id)
	if GameState.has_flag(collected_flag):
		return

	var world_item := WORLD_ITEM_SCENE.instantiate()
	var pos: Array = parsed.get("position", [0, 0])
	world_item.position = Vector2(pos[0], pos[1])
	var col: Array = parsed.get("color", [1, 1, 1, 1])
	world_item.portrait_color = Color(col[0], col[1], col[2], col[3] if col.size() > 3 else 1.0)
	world_item.glyph = parsed.get("glyph", "=")
	world_item.item_id = parsed.get("item_id", "")
	world_item.quantity = parsed.get("quantity", 1)
	world_item.collected_flag = collected_flag
	world_item.name = item_id
	add_child(world_item)
	_spawned_nodes.append(world_item)
