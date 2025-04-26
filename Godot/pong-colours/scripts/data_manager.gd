# res://scripts/data_manager.gd
extends Node

const SAVE_FILE = "user://game_data.cfg"

# --- Game Settings ---
var point_limit: int = 5

# --- Player Data ---
var player_name: String = "Player"

# --- Achievement Tracking ---
var achievements_unlocked: Dictionary = {
	"PONG GOD": false, "PONGING OUT": false, "TWO OF A KIND": false,
	"GAMING TRIFECTA": false, "PONG SLAY": false, "PONG CHAMELEON": false,
	"GAY CHAMELEON": false, "PONG COLOURS": false,
}
var total_points_conceded: int = 0
var player_paddles_used: Dictionary = {} # Stores basenames { "paddle.png": true }

# --- Lists for Achievement Requirements ---
var required_trifecta_paddles: Array[String] = ["red.png", "blue.png", "green.png"]
var required_pride_paddles: Array[String] = []
var required_colour_paddles: Array[String] = []

signal achievement_unlocked(achievement_name)

func _ready():
	print("DataManager: Initializing...")
	_populate_required_paddle_lists()
	load_data()


func _populate_required_paddle_lists():
	required_pride_paddles = _scan_folder_for_png_basenames("res://assets/paddles/pride/")
	required_colour_paddles = _scan_folder_for_png_basenames("res://assets/paddles/colours/")
	print("DataManager: Required Pride Paddles:", required_pride_paddles)
	print("DataManager: Required Colour Paddles:", required_colour_paddles)

func _scan_folder_for_png_basenames(folder_path: String) -> Array[String]:
	var basenames: Array[String] = []
	var dir = DirAccess.open(folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".png") or file_name.ends_with(".PNG")):
				basenames.append(file_name.to_lower())
			file_name = dir.get_next()
		# list_dir_end() is deprecated in Godot 4
	else:
		printerr("DataManager: Could not scan folder:", folder_path)
	return basenames

#-------------------------------------------------
# Data Persistence
#-------------------------------------------------
func save_data():
	var config = ConfigFile.new()
	config.set_value("settings", "point_limit", point_limit)
	config.set_value("player", "name", player_name)
	for ach_name in achievements_unlocked:
		config.set_value("achievements", ach_name, achievements_unlocked[ach_name])
	config.set_value("stats", "total_points_conceded", total_points_conceded)
	var used_paddles_array = player_paddles_used.keys()
	config.set_value("stats", "player_paddles_used", used_paddles_array)
	if AudioManager:
		config.set_value("audio", "music_volume_db", AudioManager.music_volume_db)
		config.set_value("audio", "sfx_volume_db", AudioManager.sfx_volume_db)
		config.set_value("display", "resolution_width", AudioManager.current_resolution.x)
		config.set_value("display", "resolution_height", AudioManager.current_resolution.y)
		config.set_value("display", "fullscreen", AudioManager.current_fullscreen_mode)
	else:
		printerr("DataManager: Cannot find AudioManager to save its settings!")

	var err = config.save(SAVE_FILE)
	if err != OK:
		printerr("DataManager: Error saving data to ", SAVE_FILE, " Code: ", err)
	else:
		print("DataManager: Game data saved.")


func load_data():
	var config = ConfigFile.new()
	var err = config.load(SAVE_FILE)
	if err != OK:
		printerr("DataManager: No save file found or error loading. Using defaults. Code: ", err)
		reset_data_values()
		if AudioManager:
			AudioManager.load_settings_from_data(0.0, 0.0, DisplayServer.window_get_size(), false)
		save_data()
		return

	print("DataManager: Loading data from ", SAVE_FILE)
	point_limit = config.get_value("settings", "point_limit", 5)
	player_name = config.get_value("player", "name", "Player")
	for ach_name in achievements_unlocked:
		achievements_unlocked[ach_name] = config.get_value("achievements", ach_name, false)
	total_points_conceded = config.get_value("stats", "total_points_conceded", 0)
	var used_paddles_array = config.get_value("stats", "player_paddles_used", [])
	player_paddles_used.clear()
	for paddle_basename in used_paddles_array:
		player_paddles_used[paddle_basename] = true # Correctly use loop variable

	if AudioManager:
		var music_db = config.get_value("audio", "music_volume_db", 0.0)
		var sfx_db = config.get_value("audio", "sfx_volume_db", 0.0)
		var width = config.get_value("display", "resolution_width", DisplayServer.window_get_size().x)
		var height = config.get_value("display", "resolution_height", DisplayServer.window_get_size().y)
		var res = Vector2i(width, height)
		var fs = config.get_value("display", "fullscreen", false)
		AudioManager.load_settings_from_data(music_db, sfx_db, res, fs)
	else:
		printerr("DataManager: Cannot find AudioManager to load settings into!")

	print("DataManager: Data loaded. Player:", player_name, "Point Limit:", point_limit)
	print("DataManager: Achievements Status:", achievements_unlocked)


func reset_data():
	print("DataManager: Resetting data...")
	reset_data_values()
	if AudioManager:
		AudioManager.load_settings_from_data(0.0, 0.0, DisplayServer.window_get_size(), false)
	save_data()
	print("DataManager: Data reset complete.")


func reset_data_values():
	point_limit = 5
	player_name = "Player"
	for ach_name in achievements_unlocked:
		achievements_unlocked[ach_name] = false
	total_points_conceded = 0
	player_paddles_used.clear()

#-------------------------------------------------
# Settings Access
#-------------------------------------------------
func set_point_limit(limit: int):
	if limit >= 1:
		if point_limit != limit:
			point_limit = limit
			print("DataManager: Point limit set to", point_limit)
			save_data()

func get_point_limit() -> int:
	return point_limit

#-------------------------------------------------
# Player Name Access
#-------------------------------------------------
func set_player_name(new_name: String):
	if player_name != new_name:
		player_name = new_name
		print("DataManager: Player name set to", player_name)

func get_player_name() -> String:
	return player_name

#-------------------------------------------------
# Achievement Logic
#-------------------------------------------------
func unlock_achievement(ach_name: String):
	if achievements_unlocked.has(ach_name) and not achievements_unlocked[ach_name]:
		achievements_unlocked[ach_name] = true
		print("***** Achievement Unlocked:", ach_name, "*****")
		emit_signal("achievement_unlocked", ach_name)
		check_for_pong_colours()
		save_data()
	elif not achievements_unlocked.has(ach_name):
		printerr("Attempted unlock unknown achievement:", ach_name)

func is_achievement_unlocked(ach_name: String) -> bool:
	if achievements_unlocked.has(ach_name):
		return achievements_unlocked[ach_name]
	printerr("Checked for unknown achievement:", ach_name)
	return false

func increment_conceded_points():
	total_points_conceded += 1
	print("Total points conceded:", total_points_conceded)
	if not is_achievement_unlocked("PONGING OUT") and total_points_conceded >= 10:
		unlock_achievement("PONGING OUT")

func add_player_paddle_used(texture_path: String):
	if texture_path.is_empty():
		return
	var basename = texture_path.get_file().to_lower() # basename declared here
	if not player_paddles_used.has(basename):
		player_paddles_used[basename] = true
		print("Added used paddle:", basename)
		check_trifecta_achievement()
		check_pong_slay_achievement()
		check_pong_chameleon_achievement()
		check_gay_chameleon_achievement()
		save_data()

func check_trifecta_achievement():
	if is_achievement_unlocked("GAMING TRIFECTA"):
		return
	var found_all = true # found_all declared here
	for required_basename in required_trifecta_paddles:
		if not player_paddles_used.has(required_basename):
			found_all = false
			break
	if found_all:
		unlock_achievement("GAMING TRIFECTA")

func check_pong_slay_achievement():
	if is_achievement_unlocked("PONG SLAY"):
		return
	if required_pride_paddles.is_empty():
		printerr("No pride paddles found."); return
	var found_all = true # found_all declared here
	for required_basename in required_pride_paddles:
		if not player_paddles_used.has(required_basename):
			found_all = false
			break
	if found_all:
		unlock_achievement("PONG SLAY")

func check_pong_chameleon_achievement():
	if is_achievement_unlocked("PONG CHAMELEON"):
		return
	if required_colour_paddles.is_empty():
		printerr("No colour paddles found."); return
	var found_all = true # found_all declared here
	for required_basename in required_colour_paddles:
		if not player_paddles_used.has(required_basename):
			found_all = false
			break
	if found_all:
		unlock_achievement("PONG CHAMELEON")

func check_gay_chameleon_achievement():
	if is_achievement_unlocked("GAY CHAMELEON"):
		return
	if required_pride_paddles.is_empty() or required_colour_paddles.is_empty():
		return
	var found_all_pride = true # found_all_pride declared here
	for rb in required_pride_paddles:
		if not player_paddles_used.has(rb):
			found_all_pride = false
			break
	if not found_all_pride:
		return
	var found_all_colour = true # found_all_colour declared here
	for rb in required_colour_paddles:
		if not player_paddles_used.has(rb):
			found_all_colour = false
			break
	if found_all_colour: # Both loops must complete successfully
		unlock_achievement("GAY CHAMELEON")

func check_for_pong_colours():
	if is_achievement_unlocked("PONG COLOURS"):
		return
	var all_others_unlocked = true # all_others_unlocked declared here
	for ach_name in achievements_unlocked:
		if ach_name != "PONG COLOURS" and not achievements_unlocked[ach_name]:
			all_others_unlocked = false
			break
	if all_others_unlocked:
		unlock_achievement("PONG COLOURS")
