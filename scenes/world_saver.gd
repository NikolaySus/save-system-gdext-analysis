extends WorldSaver

# Save file name
const k_world_name: String = "the_only_world"
# Variables for performance analysis
@onready var readings: Array = []
@onready var tick_counter: int = 0
# Variables to access player and TileMapLayer nodes
@onready var placing: TileMapLayer = $TileMapLayer
@onready var player: CharacterBody2D = $CharacterBody2D
# Variables to init WorldSaver
@onready var tile_size_x: int = placing.tile_set.tile_size.x
@onready var tile_size_y: int = placing.tile_set.tile_size.y
# Variables to update TileMapLayer position, more info in _physics_process
@onready var overall_deltaxy = Vector2i(0, 0)
@onready var deltaxy = Vector2i(0, 0)
@onready var used_rect = null

func _ready():
	Autoload.k_world_name = k_world_name
	# Analytics: deleting the previous world and statistics, creating new .csv
	if Autoload.k_finish_tick > 0:
		Autoload.prepare_dir_for_bench(k_world_name)
	# Start of WorldSaver returns saved player position (or default value)
	player.position = self.start(k_world_name, tile_size_x, tile_size_y)
	print("The player.position is ", player.position)
	print("Tile size is ({0}, {1})".format([tile_size_x, tile_size_y]))
	# Load example variable by "key to save variable by" from save file.
	# The variable can be anything, even some Node or Resource.
	var smth_saved = self.load_by("key to save variable by")
	# Example variable value print
	print("Loaded example: ", smth_saved)
	# On first load nothing is stored by key (nil) in save file
	if !smth_saved:
		smth_saved = { "important data": 42 }
	Autoload.k_smth_saved = smth_saved

func _physics_process(_delta):
	# Analytics: auto-press movement keys
	if Autoload.k_finish_tick > 0:
		for key in Autoload.k_option:
			Autoload.emulate_input(key)
		tick_counter += 1
	var start_time = Time.get_ticks_usec()
	self.set_view_center(player.position.x, player.position.y, false)
	var chunks_unloaded: int = unload_all()
	var chunks_loaded: int = load_all()
	var end_time = Time.get_ticks_usec()
	var tile_proc_time = (end_time - start_time) / 1000.0
	var used_cells = placing.get_used_cells()
	# If not moving the TileMapLayer to follow the player,
	# memory consumption increases.
	var prev_used_rect = used_rect
	used_rect = placing.get_used_rect()
	if chunks_loaded and prev_used_rect:
		deltaxy = used_rect.position - prev_used_rect.position
		overall_deltaxy += deltaxy
		var new_tile_data = {}
		for cell_coords in used_cells:
			var idxy: Vector2i = placing.get_cell_atlas_coords(cell_coords)
			new_tile_data[cell_coords - deltaxy] = idxy
		placing.clear()
		for new_coords in new_tile_data:
			placing.set_cell(new_coords, 0, new_tile_data[new_coords])
		# Shifts the center of the TileMapLayer in the world,
		# considers the tiles to be square.
		placing.global_position += Vector2(deltaxy * tile_size_x)
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
			"chunks_loaded": chunks_loaded,
			"chunks_unloaded": chunks_unloaded,
			"used_cells": used_cells.size(),
			"used_cells_bbox_w": used_rect.size.x,
			"used_cells_bbox_h": used_rect.size.y,
			"player_x": player.position.x,
			"player_y": player.position.y
		})
		if tick_counter % Autoload.k_csv_flush_interval == 0:
			Autoload.flush_to_csv(readings, tick_counter)
		if tick_counter >= Autoload.k_finish_tick:
			get_tree().quit()

func _notification(what):
	match what:
		NOTIFICATION_PREDELETE:
			# Example variable value print
			print("Saved example: ", Autoload.k_smth_saved)
			print("Type of mem: ", typeof(
				Autoload.k_smth_saved["important data"]))
			# Save by "key to save variable by" in save file
			self.save_as("key to save variable by", Autoload.k_smth_saved)
			# Player exit from world
			self.exit(player.position)
			# Analytics: record current save file size to .txt
			if Autoload.k_finish_tick > 0:
				Autoload.do_txt(FileAccess.get_size(
					"./saves/" + k_world_name))
			# Last world changes save
			unload_all()
			# Analytics: write remaining data to .csv
			if Autoload.k_finish_tick > 0:
				Autoload.flush_to_csv(readings, tick_counter)

# Setting tile by left click
func _unhandled_input(event):
	if event is InputEventMouseButton and (
		event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		Autoload.process_user_set_tile(player, placing)

# Functions to serialize/deserialize data between WorldSaver and
# game objects like TileMapLayer.
func from_tilemap(x: int, y: int):
	var start_x: int = (x << self.CHUNK_SIZE_X_POW) - 1 - overall_deltaxy.x
	var start_y: int = (y << self.CHUNK_SIZE_Y_POW) - 1 - overall_deltaxy.y
	var ret: PackedByteArray = []
	for add_y in range(self.CHUNK_SIZE_Y):
		for add_x in range(self.CHUNK_SIZE_X):
			var tile = Vector2(start_x + add_x, start_y + add_y)
			var idxy: Vector2i = placing.get_cell_atlas_coords(tile)
			ret.append(idxy.x + idxy.y * 8)
			# Here can be more ret.append-s to store other data in this cell.
			# For example, mobs can be stored, if their
			# collision shape is not less than cell.
			placing.erase_cell(tile)
	return ret

func to_tilemap(x: int, y: int, content: PackedByteArray):
	var start_x: int = (x << self.CHUNK_SIZE_X_POW) - 1 - overall_deltaxy.x
	var start_y: int = (y << self.CHUNK_SIZE_Y_POW) - 1 - overall_deltaxy.y
	for add_y in range(self.CHUNK_SIZE_Y):
		for add_x in range(self.CHUNK_SIZE_X):
			var iter: int = (add_y << self.CHUNK_SIZE_Y_POW) + add_x
			var idx: int = content[iter] % 8
			var idy: int = content[iter] / 8
			# Here can be more data retrieved from cell
			if idx + idy == 0:
				gen_chunk(start_x, start_y)
				return
			else:
				placing.set_cell(
					Vector2(start_x + add_x, start_y + add_y),
					0,
					Vector2i(idx, idy))

func load_all():
	var counter: int = 0
	var payload: PackedByteArray = self.load_another_one()
	while !payload.is_empty():
		var fields = payload.slice(0, 16).to_int64_array()
		to_tilemap(fields[0], fields[1], payload.slice(16))
		payload = self.load_another_one()
		counter += 1
	return counter

func unload_all():
	var counter: int = 0
	var unload_xy: PackedInt64Array = self.which_to_unload()
	while !unload_xy.is_empty():
		var payload_unl_xy = unload_xy.to_byte_array()
		payload_unl_xy.append_array(from_tilemap(unload_xy[0], unload_xy[1]))
		self.unload(payload_unl_xy)
		unload_xy = self.which_to_unload()
		counter += 1
	return counter

# Function to fill empty chunk with tiles by it's starting tile position
func gen_chunk(start_x: int, start_y: int):
	for add_y in range(self.CHUNK_SIZE_Y):
		for add_x in range(self.CHUNK_SIZE_X):
			var where = Vector2i(start_x + add_x, start_y + add_y)
			placing.set_cell(where, 0, Autoload.gen_tile_by_pos(where))
