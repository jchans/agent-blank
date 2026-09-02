extends Node2D

## Spawns one NPC per JSON file under data/npcs/. Creating a new NPC in the
## game requires no scene editing: drop a new JSON file in data/npcs/ (see
## data/npcs/elder.json for the shape) and a matching dialogue graph under
## dialogues/.
##
## The map is plain-text ASCII (data/maps/*.txt) rendered as one Label per
## character — no tileset/sprite asset needed, and no monospace font
## dependency either, since each glyph gets its own fixed-size centered cell.

const NPC_SCENE := preload("res://scenes/NPC.tscn")
const NPC_DATA_DIR := "res://data/npcs/"

const MAP_PATH := "res://data/maps/village.txt"
const TILE_SIZE := 24.0
const TILE_FONT_SIZE := 18
const TILE_COLORS := {
	"#": Color(0.55, 0.5, 0.45),
	".": Color(0.28, 0.42, 0.24),
}
const TILE_COLOR_DEFAULT := Color(0.6, 0.6, 0.6)


func _ready() -> void:
	_render_map()
	_spawn_npcs()


## World-space center of tile (col, row), for positioning player/NPCs.
static func tile_center(col: int, row: int) -> Vector2:
	return Vector2((col + 0.5) * TILE_SIZE, (row + 0.5) * TILE_SIZE)


func _render_map() -> void:
	var file := FileAccess.open(MAP_PATH, FileAccess.READ)
	if file == null:
		push_warning("Main: could not open map file: %s" % MAP_PATH)
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
	var label := Label.new()
	label.text = glyph
	label.add_theme_color_override("font_color", TILE_COLORS.get(glyph, TILE_COLOR_DEFAULT))
	label.add_theme_font_size_override("font_size", TILE_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(col * TILE_SIZE, row * TILE_SIZE)
	label.size = Vector2(TILE_SIZE, TILE_SIZE)
	add_child(label)


func _spawn_npcs() -> void:
	var dir := DirAccess.open(NPC_DATA_DIR)
	if dir == null:
		push_warning("Main: could not open NPC data dir: %s" % NPC_DATA_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_spawn_npc_from_file(NPC_DATA_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _spawn_npc_from_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Main: could not open NPC data file: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Main: invalid NPC data file: %s" % path)
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
