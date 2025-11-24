extends Node2D

# Save file name
const k_world_name: String = "naive_open_world"
const k_save_path: String = "./saves/"
const k_world_file: String = k_save_path + k_world_name
# World generation settings
const k_view_radius_tiles: int = 8
# Variables for performance analysis	
@onready var readings: Array = []
@onready var tick_counter: int = 0
# Variables to access player and TileMapLayer nodes
@onready var placing: TileMapLayer = $TileMapLayer
@onready var player: CharacterBody2D = $CharacterBody2D

func _ready():
	Autoload.k_world_name = k_world_name
	# Analytics: deleting the previous world and statistics, creating new .csv
	if Autoload.k_finish_tick > 0:
		Autoload.prepare_dir_for_bench(k_world_name)
	# Initial player position (naive realisation is only for comparasion)
	player.position = Vector2(0, 0)
	load_from_file()
	print("World loaded. Player position: ", player.position)

func _physics_process(_delta):
	# Analytics: auto-press movement keys
	if Autoload.k_finish_tick > 0:
		for key in Autoload.k_option:
			Autoload.emulate_input(key)
		tick_counter += 1
	var start_time = Time.get_ticks_usec()
	fill_empty_tiles()
	var end_time = Time.get_ticks_usec()
	var tile_proc_time = (end_time - start_time) / 1000.0
	var used_cells = placing.get_used_cells()
	var used_rect = placing.get_used_rect()
	# Analytics: writing data to a buffer that is periodically written to .csv
	# There is a correction here for increased memory usage when saving a
	# record to the statistics buffer, depending on the
	# constant Autoload.k_csv_flush_interval
	if Autoload.k_finish_tick > 0:
		readings.append({
			"tick": tick_counter,
			"read_write_time_ms": tile_proc_time,
			"mem_usage_mb": ((OS.get_static_memory_usage() -
							((tick_counter - 1) %
							Autoload.k_csv_flush_interval + 1) * 1043) /
							(1024.0 * 1024.0)),
			"chunks_loaded": 0,
			"chunks_unloaded": 0,
			"used_cells": used_cells.size(),
			"used_cells_bbox_w": used_rect.size.x,
			"used_cells_bbox_h": used_rect.size.y,
			"player_x": player.position.x,
			"player_y": player.position.y
		})
		if tick_counter % Autoload.k_csv_flush_interval == 0:
			save_to_file()
			Autoload.flush_to_csv(readings, tick_counter)
		if tick_counter >= Autoload.k_finish_tick:
			get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
			get_tree().quit()

func _notification(what):
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			save_to_file()
			# Analytics: record current save file size to .txt
			if Autoload.k_finish_tick > 0:
				Autoload.do_txt(FileAccess.get_size(
					"./saves/" + k_world_name))
				# Analytics: write remaining data to .csv
				Autoload.flush_to_csv(readings, tick_counter)

# Setting tile by left click
func _unhandled_input(event):
	if event is InputEventMouseButton and (
		event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		Autoload.process_user_set_tile(player, placing)

func load_from_file():
	if not FileAccess.file_exists(k_world_file):
		print("No existing world file found.")
		return

	var file := FileAccess.open(k_world_file, FileAccess.READ)
	var err := FileAccess.get_open_error()
	if err != OK:
		push_error("Failed to open file for reading! Error code: %s" % err)
		file.close()
		return

	var count := file.get_32()

	print("Loading", count, "tiles...")

	for i in count:
		var x := file.get_32()
		var y := file.get_32()
		var packed := file.get_8()

		var atlas_x := packed & 0b00000111
		var atlas_y := (packed >> 3) & 0b00000111

		placing.set_cell(Vector2i(x, y), 0, Vector2i(atlas_x, atlas_y))

	file.close()

func fill_empty_tiles():
	var player_tile: Vector2i = placing.local_to_map(player.position)
	for y in range(player_tile.y - k_view_radius_tiles, player_tile.y + k_view_radius_tiles):
		for x in range(player_tile.x - k_view_radius_tiles, player_tile.x + k_view_radius_tiles):
			var pos: Vector2i = Vector2i(x, y)
			if not placing.get_cell_tile_data(pos):
				var atlas: Vector2i = Autoload.gen_tile_by_pos(pos)
				placing.set_cell(pos, 0, atlas)

func save_to_file():
	print("Saving world to:", k_world_file)
	DirAccess.make_dir_recursive_absolute(k_save_path)

	var file := FileAccess.open(k_world_file, FileAccess.WRITE)
	var err := FileAccess.get_open_error()
	if err != OK:
		push_error("Failed to open file for writing! Error code: %s" % err)
		file.close()
		return

	var used_cells := placing.get_used_cells()
	file.store_32(used_cells.size())  # write count

	for cell in used_cells:
		var atlas := placing.get_cell_atlas_coords(cell)
		if atlas:
			# pack atlas coords into one byte
			var packed := atlas.x | (atlas.y << 3)

			file.store_32(cell.x)
			file.store_32(cell.y)
			file.store_8(packed)

	file.close()
	print("World saved to", k_world_file, "(", used_cells.size(), " tiles).")
