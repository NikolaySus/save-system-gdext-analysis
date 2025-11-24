extends Node

# Globals
const k_csv_flush_interval: int = 1000
var k_csv_path: String = ""
var k_txt_path: String = ""
var k_finish_tick: int = 0
var k_option: Array = []
var k_option_str: String = ""
var k_option_use_naive: int = 0
var k_smth_saved
var k_world_name: String = ""

# Tile position -> Tile atlas position
func gen_tile_by_pos(pos: Vector2i) -> Vector2i:
	seed(hash(pos))
	var what = Vector2i(randi() % 8, randi() % 8)
	if what.x + what.y == 0 or (what.x > 5 and what.y == 7):
		what = Vector2i(1, 1)
	return what

# Setting tile by left click
func process_user_set_tile(player: CharacterBody2D, placing: TileMapLayer):
	var screen_pos = player.get_viewport().get_mouse_position()
	var local_pos = null
	var tile_coords = null
	if player.camera:
		local_pos = placing.to_local(
			player.camera.get_canvas_transform().affine_inverse() * screen_pos)
		tile_coords = placing.local_to_map(local_pos)
	else:
		local_pos = placing.to_local(screen_pos)
		tile_coords = placing.local_to_map(local_pos)
	placing.set_cell(tile_coords, 0, Vector2i(0, 4))

# Utility functions for analysis
func emulate_input(key):
	var event = InputEventKey.new()
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)

func prepare_dir_for_bench(world_name: String):
	print("End tick set to ", k_finish_tick)
	delete_my_file("saves/" + world_name)
	var csv_files = get_txt_csv_files_in_directory("./")
	for file in csv_files:
		delete_my_file(file)
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z0-9]")
	var stats_path = "./" + regex.sub(
		"{0} monitor data {1} {2} at {3}".format(
			[world_name,
			k_option_str,
			k_finish_tick,
			Time.get_datetime_string_from_system(false, true)]
		), "_", true)
	k_csv_path = stats_path + ".csv"
	k_txt_path = stats_path + ".txt"
	ensure_csv_header()

func delete_my_file(path: String):
	var dir = DirAccess.open("./")
	if dir:
		if dir.file_exists(path):
			var error = dir.remove(path)
			if error == OK:
				print("File deleted successfully: ", path)
			else:
				print("Error deleting file: ", path, ", Error code: ", error)
		else:
			print("File does not exist: ", path)
	else:
		print("Could not open directory access.")

func get_txt_csv_files_in_directory(path: String) -> Array:
	var csv_files: Array = []
	var dir = DirAccess.open(path)

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (
				file_name.ends_with(".csv") or file_name.ends_with(".txt")):
				csv_files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Error: Could not open directory at path: " + path)
	return csv_files

func flush_to_csv(readings: Array, tick_counter: int) -> void:
	if readings.size() == 0:
		return
	var file := FileAccess.open(k_csv_path, FileAccess.ModeFlags.READ_WRITE)
	if file == null:
		push_error("Failed to open CSV file for append: %s" % k_csv_path)
		return
	file.seek_end()
	var tmp_size = FileAccess.get_size("./saves/" + k_world_name)
	if tmp_size == -1:
		k_finish_tick = 1
	for rec in readings:
		var line := "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10}".format([
			rec.tick,
			rec.read_write_time_ms,
			rec.mem_usage_mb,
			rec.chunks_loaded,
			rec.chunks_unloaded,
			rec.used_cells,
			rec.used_cells_bbox_w,
			rec.used_cells_bbox_h,
			rec.player_x,
			rec.player_y,
			tmp_size])
		file.store_line(line)
	file.flush()
	file.close()
	readings.clear()
	print("Flushed stats to %s at frame %d" % [k_csv_path, tick_counter])

func ensure_csv_header() -> void:
	if not FileAccess.file_exists(k_csv_path):
		var file := FileAccess.open(k_csv_path, FileAccess.ModeFlags.WRITE)
		if file == null:
			var error = FileAccess.get_open_error()
			print("Error opening file for saving ", str(error))
			return
		file.store_line(
			"tick,read_write_time_ms,mem_usage_mb," +
			"chunks_loaded,chunks_unloaded," +
			"used_cells,used_cells_bbox_w,used_cells_bbox_h," +
			"player_x,player_y,savefile_size")
		file.close()

func do_txt(bytes: int) -> void:
	if not FileAccess.file_exists(k_txt_path):
		var file := FileAccess.open(k_txt_path, FileAccess.ModeFlags.WRITE)
		if file == null:
			var error = FileAccess.get_open_error()
			print("Error opening file for saving ", str(error))
			return
		file.store_line(str(bytes))
		file.close()
