# res://scripts/data_manager.gd
extends Node

const SAVE_FILE = "user://game_data.cfg"

# --- Data storage dictionaries ---
# Define default values here
var settings: Dictionary = {"point_limit": 5}
var player_data: Dictionary = {"name": "Player"}
var audio_settings: Dictionary = {"music_volume_db": 0.0, "sfx_volume_db": 0.0}
var display_settings: Dictionary = {
	"resolution_width": 1152, "resolution_height": 648, "fullscreen": false
}
var achievements_unlocked: Dictionary = {
	"PONG GOD": false, "PONGING OUT": false, "TWO OF A KIND": false,
	"GAMING TRIFECTA": false, "PONG SLAY": false, "PONG CHAMELEON": false,
	"GAY CHAMELEON": false, "PONG COLOURS": false,
}
var achievement_stats: Dictionary = {
	"total_points_conceded": 0,
	"player_paddles_used": {} # Stores basenames { "paddle.png": true }
}


# --- Lists for Achievement Requirements ---
var required_trifecta_paddles: Array[String] = ["red.png", "blue.png", "green.png"]
var required_pride_paddles: Array[String] = []
var required_colour_paddles: Array[String] = []

signal achievement_unlocked(achievement_name)

func _ready():
	print("DataManager: Initializing...")
	# Set default resolution immediately using DisplayServer if possible
	var initial_res = DisplayServer.window_get_size()
	if initial_res != Vector2i.ZERO:
		display_settings["resolution_width"] = initial_res.x
		display_settings["resolution_height"] = initial_res.y
		print("DataManager: Default resolution set from DisplayServer:", initial_res)
	else: # Use fallback if display server is slow
		display_settings["resolution_width"] = 1152
		display_settings["resolution_height"] = 648
		print("DataManager: Default resolution set from fallback.")

	_populate_required_paddle_lists()
	load_data() # Load saved data, potentially overwriting defaults
	print("DataManager: Initialization complete.")


# --- Save data when the game is requested to close (Fallback) ---
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("DataManager: WM_CLOSE_REQUEST notification received. Triggering save.")
		save_data()

func _populate_required_paddle_lists():
	required_pride_paddles = _scan_folder_for_png_basenames("res://assets/paddles/pride/")
	required_colour_paddles = _scan_folder_for_png_basenames("res://assets/paddles/colours/")
	# print("DataManager: Required Pride Paddles:", required_pride_paddles) # Optional debug
	# print("DataManager: Required Colour Paddles:", required_colour_paddles) # Optional debug

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
	else:
		printerr("DataManager: Could not scan folder:", folder_path)
	return basenames

#-------------------------------------------------
# Data Persistence
#-------------------------------------------------
func save_data():
	# Add a check to prevent saving if node is being deleted (e.g., during shutdown)
	if not is_instance_valid(self):
		print("DataManager: Instance not valid, skipping save_data().")
		return

	print("--- DataManager: save_data() CALLED ---")
	var config = ConfigFile.new()

	# Save data from dictionaries, using .get() with defaults as a fallback
	config.set_value("settings", "point_limit", settings.get("point_limit", 5))
	config.set_value("player", "name", player_data.get("name", "Player"))
	config.set_value("audio", "music_volume_db", audio_settings.get("music_volume_db", 0.0))
	config.set_value("audio", "sfx_volume_db", audio_settings.get("sfx_volume_db", 0.0))
	config.set_value("display", "resolution_width", display_settings.get("resolution_width", 1152))
	config.set_value("display", "resolution_height", display_settings.get("resolution_height", 648))
	config.set_value("display", "fullscreen", display_settings.get("fullscreen", false))

	for ach_name in achievements_unlocked:
		config.set_value("achievements", ach_name, achievements_unlocked[ach_name])

	config.set_value("stats", "total_points_conceded", achievement_stats.get("total_points_conceded", 0))
	# Convert paddle dict keys back to array for saving
	var paddles_dict = achievement_stats.get("player_paddles_used", {})
	config.set_value("stats", "player_paddles_used", paddles_dict.keys())

	var err = config.save(SAVE_FILE)
	if err != OK:
		printerr("DataManager: !!! Error saving data to ", SAVE_FILE, " Code: ", err, " !!!")
	else:
		print("DataManager: Game data saved successfully to ", SAVE_FILE)


func load_data():
	print("--- DataManager: load_data() CALLED ---")
	var config = ConfigFile.new()
	var err = config.load(SAVE_FILE)

	if err == OK:
		print("DataManager: Loading data from existing file: ", SAVE_FILE)
		# Load into dictionaries, using current values as defaults ONLY if key is missing
		settings["point_limit"] = config.get_value("settings", "point_limit", settings["point_limit"])
		player_data["name"] = config.get_value("player", "name", player_data["name"])
		audio_settings["music_volume_db"] = config.get_value("audio", "music_volume_db", audio_settings["music_volume_db"])
		audio_settings["sfx_volume_db"] = config.get_value("audio", "sfx_volume_db", audio_settings["sfx_volume_db"])
		display_settings["resolution_width"] = config.get_value("display", "resolution_width", display_settings["resolution_width"])
		display_settings["resolution_height"] = config.get_value("display", "resolution_height", display_settings["resolution_height"])
		display_settings["fullscreen"] = config.get_value("display", "fullscreen", display_settings["fullscreen"])

		# Load achievements carefully
		var loaded_achievements = config.get_value("achievements", "", {})
		if typeof(loaded_achievements) == TYPE_DICTIONARY:
			for ach_name in achievements_unlocked: # Iterate defined achievements
				if loaded_achievements.has(ach_name):
					# Only overwrite if the key exists in the loaded data
					achievements_unlocked[ach_name] = loaded_achievements[ach_name]
		else: printerr("DataManager WARNING: Achievements data type invalid.")

		achievement_stats["total_points_conceded"] = config.get_value("stats", "total_points_conceded", achievement_stats["total_points_conceded"])

		# Load used paddles
		var used_paddles_array = config.get_value("stats", "player_paddles_used", [])
		achievement_stats["player_paddles_used"] = {} # Clear before loading
		if typeof(used_paddles_array) == TYPE_ARRAY:
			for paddle_basename in used_paddles_array:
				if typeof(paddle_basename) == TYPE_STRING:
					achievement_stats["player_paddles_used"][paddle_basename] = true
				else: printerr("DataManager WARNING: Non-string in saved paddles array.")
		else: printerr("DataManager WARNING: Saved paddles data not an array.")

		print("DataManager: Data loaded successfully.")
		print("  Loaded Player:", player_data["name"], "Point Limit:", settings["point_limit"])
		# Don't push to AudioManager here, AudioManager will pull later via call_deferred

	elif err == ERR_FILE_NOT_FOUND:
		print("DataManager: Save file not found (", SAVE_FILE, "). Creating new default data.")
		# Internal values are already at defaults from _ready() or class definition
		# reset_data_values() # Not strictly needed here if defaults are set above
		save_data() # Save the new default file immediately

	else:
		# Other load error (corruption?)
		printerr("DataManager: !!! FAILED TO LOAD existing save file '", SAVE_FILE, "' (Error code: ", err, ") !!!")
		printerr("DataManager: Using default values for this session to avoid data loss.")
		# Ensure internal values are defaults
		reset_data_values()
		# DO NOT save data here to preserve the potentially recoverable file

	print("--- DataManager: load_data() FINISHED ---")


func reset_data():
	print("--- DataManager: reset_data() CALLED ---")
	reset_data_values()
	save_data() # Save the reset state
	# Tell AudioManager to re-apply defaults now that DataManager has them
	if is_instance_valid(AudioManager) and AudioManager.is_node_ready():
		# AudioManager will fetch the new defaults from DataManager
		AudioManager._apply_initial_settings()
	print("DataManager: Data reset complete and saved.")


func reset_data_values():
	print("DataManager: Resetting internal data variables to defaults.")
	settings = {"point_limit": 5}
	player_data = {"name": "Player"}
	# Get current display size for defaults
	var current_res = DisplayServer.window_get_size()
	if current_res == Vector2i.ZERO: current_res = Vector2i(1152, 648) # Fallback
	audio_settings = {"music_volume_db": 0.0, "sfx_volume_db": 0.0}
	display_settings = {
		"resolution_width": current_res.x,
		"resolution_height": current_res.y,
		"fullscreen": false
	}
	for ach_name in achievements_unlocked:
		achievements_unlocked[ach_name] = false
	achievement_stats = {
		"total_points_conceded": 0,
		"player_paddles_used": {}
	}


#-------------------------------------------------
# Settings Access & Update Helpers
#-------------------------------------------------

# Generic getter used by AudioManager or UI to pull current state
# Ensure this is called *after* DataManager has loaded
func get_value_or_default(section_key: String, value_key: String, default_value):
	match section_key:
		"settings": return settings.get(value_key, default_value)
		"player": return player_data.get(value_key, default_value)
		"audio": return audio_settings.get(value_key, default_value)
		"display": return display_settings.get(value_key, default_value)
		"achievements": return achievements_unlocked.get(value_key, default_value)
		"stats":
			var stats_dict = achievement_stats.get(value_key)
			if stats_dict != null: return stats_dict
			else: return default_value # Handle cases like getting 'player_paddles_used'
		_:
			printerr("DataManager: Unknown section key '", section_key, "' in get_value_or_default.")
			return default_value

# Generic setter used by AudioManager or UI to update DataManager's state AND save
func update_and_save_setting(section_key: String, value_key: String, new_value, save_immediately: bool = true):
	var changed = false
	# Use .get() to safely handle potentially missing keys initially
	match section_key:
		"settings":
			if settings.get(value_key, null) != new_value:
				settings[value_key] = new_value; changed = true
		"player":
			if player_data.get(value_key, null) != new_value:
				player_data[value_key] = new_value; changed = true
		"audio":
			if audio_settings.get(value_key, null) != new_value:
				audio_settings[value_key] = new_value; changed = true
		"display":
			if display_settings.get(value_key, null) != new_value:
				display_settings[value_key] = new_value; changed = true
		_:
			printerr("DataManager: Unknown section key '", section_key, "' in update_and_save_setting.")
			return

	if changed and save_immediately:
		print("DataManager: Value changed for ", section_key, ".", value_key, " - Calling save_data()")
		save_data()
	elif changed:
		# Useful if multiple related values change before saving (like resolution width/height)
		print("DataManager: Value queued for change for ", section_key, ".", value_key)


# Specific setters/getters for convenience if needed by game logic

func set_point_limit(limit: int):
	if limit >= 1:
		# Update internal dictionary and trigger save
		update_and_save_setting("settings", "point_limit", limit)

func get_point_limit() -> int:
	# Read from internal dictionary
	return settings.get("point_limit", 5)


func set_player_name(new_name: String):
	# Update internal dictionary but DO NOT save immediately
	# ChangeNameMenu script calls save_data after this
	update_and_save_setting("player", "name", new_name, false)

func get_player_name() -> String:
	# Read from internal dictionary
	return player_data.get("name", "Player")

#-------------------------------------------------
# Achievement Logic
#-------------------------------------------------
func unlock_achievement(ach_name: String):
	if achievements_unlocked.has(ach_name) and not achievements_unlocked[ach_name]:
		achievements_unlocked[ach_name] = true
		print("***** Achievement Unlocked:", ach_name, "***** - Calling save_data()")
		emit_signal("achievement_unlocked", ach_name)
		check_for_pong_colours()
		save_data() # Save when an achievement is unlocked
	elif not achievements_unlocked.has(ach_name):
		printerr("Attempted unlock unknown achievement:", ach_name)

func is_achievement_unlocked(ach_name: String) -> bool:
	return achievements_unlocked.get(ach_name, false)

func increment_conceded_points():
	var current_conceded = achievement_stats.get("total_points_conceded", 0)
	current_conceded += 1
	achievement_stats["total_points_conceded"] = current_conceded
	# Save happens when achievement unlocks, or on quit
	if not is_achievement_unlocked("PONGING OUT") and current_conceded >= 10:
		unlock_achievement("PONGING OUT")

func add_player_paddle_used(texture_path: String):
	if texture_path.is_empty(): return
	var basename = texture_path.get_file().to_lower()
	# Ensure the dictionary exists before trying to access it
	if not achievement_stats.has("player_paddles_used"):
		achievement_stats["player_paddles_used"] = {}

	var paddles_dict = achievement_stats["player_paddles_used"]
	if not paddles_dict.has(basename):
		paddles_dict[basename] = true
		# achievement_stats["player_paddles_used"] = paddles_dict # No need to reassign dict
		print("DataManager: Added used paddle:", basename, " - Calling save_data()")
		check_trifecta_achievement()
		check_pong_slay_achievement()
		check_pong_chameleon_achievement()
		check_gay_chameleon_achievement()
		save_data() # Save when a new paddle is tracked

# --- Achievement check functions need to access the nested dictionary ---
func check_trifecta_achievement():
	if is_achievement_unlocked("GAMING TRIFECTA"): return
	var used_paddles = achievement_stats.get("player_paddles_used", {})
	var found_all = true
	for required_basename in required_trifecta_paddles:
		if not used_paddles.has(required_basename):
			found_all = false; break
	if found_all: unlock_achievement("GAMING TRIFECTA")

func check_pong_slay_achievement():
	if is_achievement_unlocked("PONG SLAY"): return
	if required_pride_paddles.is_empty(): return
	var used_paddles = achievement_stats.get("player_paddles_used", {})
	var found_all = true
	for required_basename in required_pride_paddles:
		if not used_paddles.has(required_basename):
			found_all = false; break
	if found_all: unlock_achievement("PONG SLAY")

func check_pong_chameleon_achievement():
	if is_achievement_unlocked("PONG CHAMELEON"): return
	if required_colour_paddles.is_empty(): return
	var used_paddles = achievement_stats.get("player_paddles_used", {})
	var found_all = true
	for required_basename in required_colour_paddles:
		if not used_paddles.has(required_basename):
			found_all = false; break
	if found_all: unlock_achievement("PONG CHAMELEON")

func check_gay_chameleon_achievement():
	if is_achievement_unlocked("GAY CHAMELEON"): return
	if required_pride_paddles.is_empty() or required_colour_paddles.is_empty(): return
	var used_paddles = achievement_stats.get("player_paddles_used", {})
	var found_all_pride = true
	for rb in required_pride_paddles:
		if not used_paddles.has(rb): found_all_pride = false; break
	if not found_all_pride: return
	var found_all_colour = true
	for rb in required_colour_paddles:
		if not used_paddles.has(rb): found_all_colour = false; break
	if found_all_colour:
		unlock_achievement("GAY CHAMELEON")

func check_for_pong_colours():
	if is_achievement_unlocked("PONG COLOURS"): return
	var all_others_unlocked = true
	for ach_name in achievements_unlocked:
		if ach_name != "PONG COLOURS" and not achievements_unlocked[ach_name]:
			all_others_unlocked = false
			break
	if all_others_unlocked: unlock_achievement("PONG COLOURS")
