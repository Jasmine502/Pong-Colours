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


# --- Exported Texture Arrays for Achievement Definitions ---
# Link the textures for these specific achievements in the Godot Editor Inspector for the DataManager node!
@export_category("Achievement Paddle Requirements")
@export var required_pride_paddle_textures: Array[Texture2D] = []
@export var required_colour_paddle_textures: Array[Texture2D] = []
# --- End Exported Textures ---


# --- Lists for Achievement Requirements (Populated from exported textures) ---
var required_trifecta_paddles: Array[String] = ["red.png", "blue.png", "green.png"] # Keep this simple list hardcoded
var required_pride_paddles: Array[String] = [] # Populated in _ready
var required_colour_paddles: Array[String] = [] # Populated in _ready

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
		# Ensure these defaults match your project settings
		display_settings["resolution_width"] = 1152
		display_settings["resolution_height"] = 648
		print("DataManager: Default resolution set from fallback.")

	_populate_required_paddle_lists_from_exports() # Use new function
	load_data() # Load saved data, potentially overwriting defaults
	print("DataManager: Initialization complete.")


# --- Save data when the game is requested to close (Fallback) ---
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("DataManager: WM_CLOSE_REQUEST notification received. Triggering save.")
		save_data()
	# Optional: Save on pause?
	# if what == NOTIFICATION_APPLICATION_PAUSED:
	#	  print("DataManager: Application paused. Saving data.")
	#	  save_data()


# --- NEW: Populate required paddle filename lists from exported Textures ---
func _populate_required_paddle_lists_from_exports():
	required_pride_paddles.clear()
	for texture in required_pride_paddle_textures:
		if texture and not texture.resource_path.is_empty():
			var basename = texture.resource_path.get_file().to_lower()
			if not required_pride_paddles.has(basename):
				required_pride_paddles.append(basename)
		else:
			printerr("DataManager Warning: Found null or pathless texture in required_pride_paddle_textures export.")

	required_colour_paddles.clear()
	for texture in required_colour_paddle_textures:
		if texture and not texture.resource_path.is_empty():
			var basename = texture.resource_path.get_file().to_lower()
			if not required_colour_paddles.has(basename):
				required_colour_paddles.append(basename)
		else:
			printerr("DataManager Warning: Found null or pathless texture in required_colour_paddle_textures export.")

	print("DataManager: Required Pride Paddles (from exports):", required_pride_paddles)
	print("DataManager: Required Colour Paddles (from exports):", required_colour_paddles)


# REMOVED: _scan_folder_for_png_basenames is no longer needed

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

	# Save achievement status
	for ach_name in achievements_unlocked:
		config.set_value("achievements", ach_name, achievements_unlocked[ach_name])

	# Save achievement stats
	config.set_value("stats", "total_points_conceded", achievement_stats.get("total_points_conceded", 0))
	# Convert paddle dict keys back to array for saving
	var paddles_dict: Dictionary = achievement_stats.get("player_paddles_used", {})
	config.set_value("stats", "player_paddles_used", paddles_dict.keys()) # Save only the keys (filenames)

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
		var loaded_achievements = config.get_value("achievements", "", {}) # Default to empty dict
		if typeof(loaded_achievements) == TYPE_DICTIONARY:
			for ach_name in achievements_unlocked: # Iterate defined achievements
				if loaded_achievements.has(ach_name):
					# Only overwrite if the key exists in the loaded data and type matches
					if typeof(loaded_achievements[ach_name]) == TYPE_BOOL:
						achievements_unlocked[ach_name] = loaded_achievements[ach_name]
					else:
						print("DataManager WARNING: Invalid type for achievement '", ach_name, "' in save file. Using default.")
				# else: Keep default value if key is missing in save file
		else: printerr("DataManager WARNING: Achievements data type in save file is invalid.")

		# Load achievement stats
		achievement_stats["total_points_conceded"] = config.get_value("stats", "total_points_conceded", achievement_stats["total_points_conceded"])

		# Load used paddles
		var used_paddles_array = config.get_value("stats", "player_paddles_used", []) # Default to empty array
		achievement_stats["player_paddles_used"] = {} # Clear before loading
		if typeof(used_paddles_array) == TYPE_ARRAY:
			for paddle_basename in used_paddles_array:
				if typeof(paddle_basename) == TYPE_STRING:
					# Basic validation: does it look like a png?
					if paddle_basename.ends_with(".png"):
						achievement_stats["player_paddles_used"][paddle_basename] = true
					else:
						printerr("DataManager WARNING: Suspicious entry '", paddle_basename, "' in saved paddles array.")
				else: printerr("DataManager WARNING: Non-string in saved paddles array.")
		else: printerr("DataManager WARNING: Saved paddles data ('player_paddles_used') is not an array.")

		print("DataManager: Data loaded successfully.")
		print("  Loaded Player:", get_player_name(), "Point Limit:", get_point_limit())
		# Don't push to AudioManager here, AudioManager will pull later via call_deferred

	elif err == ERR_FILE_NOT_FOUND:
		print("DataManager: Save file not found (", SAVE_FILE, "). Creating new default data.")
		# Internal values are already at defaults from _ready() or class definition
		reset_data_values() # Ensure defaults are set
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
	if AudioManager and is_instance_valid(AudioManager) and AudioManager.is_node_ready():
		# AudioManager will fetch the new defaults from DataManager
		AudioManager._apply_initial_settings() # Reuse the function that loads from DM
	else:
		printerr("DataManager: Cannot notify AudioManager after reset - not found or not ready.")
	print("DataManager: Data reset complete and saved.")


# Internal helper to reset dictionary values
func reset_data_values():
	print("DataManager: Resetting internal data variables to defaults.")
	settings = {"point_limit": 5}
	player_data = {"name": "Player"}
	# Get current display size for defaults, with fallback
	var current_res = DisplayServer.window_get_size()
	if current_res == Vector2i.ZERO: current_res = Vector2i(1152, 648) # Fallback
	audio_settings = {"music_volume_db": 0.0, "sfx_volume_db": 0.0}
	display_settings = {
		"resolution_width": current_res.x,
		"resolution_height": current_res.y,
		"fullscreen": false
	}
	# Reset all achievements to false
	for ach_name in achievements_unlocked:
		achievements_unlocked[ach_name] = false
	# Reset stats
	achievement_stats = {
		"total_points_conceded": 0,
		"player_paddles_used": {} # Reset used paddles list
	}


#-------------------------------------------------
# Settings Access & Update Helpers
#-------------------------------------------------

# Generic getter used by AudioManager or UI to pull current state
# Ensure this is called *after* DataManager has loaded
func get_value_or_default(section_key: String, value_key: String, default_value):
	var source_dict: Dictionary
	match section_key:
		"settings": source_dict = settings
		"player": source_dict = player_data
		"audio": source_dict = audio_settings
		"display": source_dict = display_settings
		"achievements": source_dict = achievements_unlocked
		"stats": source_dict = achievement_stats # Allow direct access to stats dict
		_:
			printerr("DataManager: Unknown section key '", section_key, "' in get_value_or_default.")
			return default_value

	# Use .get() for safe access within the chosen dictionary
	return source_dict.get(value_key, default_value)


# Generic setter used by AudioManager or UI to update DataManager's state AND save
func update_and_save_setting(section_key: String, value_key: String, new_value, save_immediately: bool = true):
	var target_dict: Dictionary
	var changed = false

	# Select the correct dictionary to modify
	match section_key:
		"settings": target_dict = settings
		"player": target_dict = player_data
		"audio": target_dict = audio_settings
		"display": target_dict = display_settings
		# Achievements and Stats are generally not set this way, but handled by specific functions
		_:
			printerr("DataManager: Unknown or unsupported section key '", section_key, "' in update_and_save_setting.")
			return

	# Check if the value actually changed before modifying and potentially saving
	if target_dict.get(value_key, null) != new_value:
		target_dict[value_key] = new_value
		changed = true

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
	else:
		printerr("DataManager: Invalid point limit set:", limit)

func get_point_limit() -> int:
	# Read from internal dictionary
	return settings.get("point_limit", 5) # Use .get() for safety


func set_player_name(new_name: String):
	var cleaned_name = new_name.strip_edges()
	if cleaned_name.is_empty():
		printerr("DataManager: Attempted to set empty player name.")
		return
	# Update internal dictionary but DO NOT save immediately
	# ChangeNameMenu script calls save_data after this
	update_and_save_setting("player", "name", cleaned_name, false)

func get_player_name() -> String:
	# Read from internal dictionary
	return player_data.get("name", "Player") # Use .get() for safety

#-------------------------------------------------
# Achievement Logic
#-------------------------------------------------
func unlock_achievement(ach_name: String):
	if achievements_unlocked.has(ach_name):
		if not achievements_unlocked[ach_name]: # Only unlock if not already unlocked
			achievements_unlocked[ach_name] = true
			print("***** Achievement Unlocked:", ach_name, "***** - Calling save_data()")
			emit_signal("achievement_unlocked", ach_name)
			check_for_pong_colours() # Check if this unlocks the final achievement
			save_data() # Save when an achievement is unlocked
		# else: Already unlocked, do nothing silently
	else:
		printerr("Attempted to unlock unknown achievement:", ach_name)


func is_achievement_unlocked(ach_name: String) -> bool:
	return achievements_unlocked.get(ach_name, false) # Use .get() for safety


func increment_conceded_points():
	var current_conceded: int = achievement_stats.get("total_points_conceded", 0)
	current_conceded += 1
	achievement_stats["total_points_conceded"] = current_conceded
	# Save happens when achievement unlocks, or on quit/pause
	# Check for achievement unlock condition
	if not is_achievement_unlocked("PONGING OUT") and current_conceded >= 10:
		unlock_achievement("PONGING OUT")


func add_player_paddle_used(resource_path: String):
	if resource_path.is_empty() or not resource_path.begins_with("res://"):
		printerr("DataManager: Invalid resource path provided to add_player_paddle_used:", resource_path)
		return

	var basename = resource_path.get_file().to_lower() # Get "paddle.png" in lower case

	# Ensure the dictionary exists before trying to access it
	if not achievement_stats.has("player_paddles_used") or typeof(achievement_stats["player_paddles_used"]) != TYPE_DICTIONARY:
		achievement_stats["player_paddles_used"] = {}

	var paddles_dict: Dictionary = achievement_stats["player_paddles_used"]

	# Only proceed if this specific paddle hasn't been recorded yet
	if not paddles_dict.has(basename):
		paddles_dict[basename] = true
		# No need to reassign dict: achievement_stats["player_paddles_used"] = paddles_dict
		print("DataManager: Added used paddle:", basename, " - Calling save_data()")

		# Check relevant achievements now that a new paddle is used
		check_trifecta_achievement()
		check_pong_slay_achievement()
		check_pong_chameleon_achievement()
		check_gay_chameleon_achievement()
		# Don't check Pong Colours here, only when another achievement unlocks

		save_data() # Save data when a new paddle is tracked


# --- Achievement check functions ---
# These now rely on the 'required_x_paddles' Array[String] populated in _ready
# and compare against the 'player_paddles_used' Dictionary in achievement_stats

func check_trifecta_achievement():
	if is_achievement_unlocked("GAMING TRIFECTA"): return
	var used_paddles: Dictionary = achievement_stats.get("player_paddles_used", {})
	var found_all = true
	for required_basename in required_trifecta_paddles:
		if not used_paddles.has(required_basename):
			found_all = false
			break # No need to check further
	if found_all:
		unlock_achievement("GAMING TRIFECTA")


func check_pong_slay_achievement(): # Uses pride paddles
	if is_achievement_unlocked("PONG SLAY"): return
	if required_pride_paddles.is_empty():
		# print("DataManager: Cannot check Pong Slay, no required pride paddles defined/exported.")
		return # Cannot achieve if requirements list is empty
	var used_paddles: Dictionary = achievement_stats.get("player_paddles_used", {})
	var found_all = true
	for required_basename in required_pride_paddles:
		if not used_paddles.has(required_basename):
			found_all = false
			break
	if found_all:
		unlock_achievement("PONG SLAY")


func check_pong_chameleon_achievement(): # Uses colour paddles
	if is_achievement_unlocked("PONG CHAMELEON"): return
	if required_colour_paddles.is_empty():
		# print("DataManager: Cannot check Pong Chameleon, no required colour paddles defined/exported.")
		return
	var used_paddles: Dictionary = achievement_stats.get("player_paddles_used", {})
	var found_all = true
	for required_basename in required_colour_paddles:
		if not used_paddles.has(required_basename):
			found_all = false
			break
	if found_all:
		unlock_achievement("PONG CHAMELEON")


func check_gay_chameleon_achievement(): # Uses pride AND colour paddles
	if is_achievement_unlocked("GAY CHAMELEON"): return
	if required_pride_paddles.is_empty() or required_colour_paddles.is_empty():
		# print("DataManager: Cannot check Gay Chameleon, missing required pride or colour paddles.")
		return
	var used_paddles: Dictionary = achievement_stats.get("player_paddles_used", {})

	# Check all pride paddles first
	var found_all_pride = true
	for rb in required_pride_paddles:
		if not used_paddles.has(rb):
			found_all_pride = false
			break
	if not found_all_pride: return # Exit early if pride set incomplete

	# Check all colour paddles
	var found_all_colour = true
	for rb in required_colour_paddles:
		if not used_paddles.has(rb):
			found_all_colour = false
			break
	if not found_all_colour: return # Exit early if colour set incomplete

	# If both checks passed
	unlock_achievement("GAY CHAMELEON")


# Check if unlocking another achievement completes the set for "Pong Colours"
func check_for_pong_colours():
	if is_achievement_unlocked("PONG COLOURS"): return # Already unlocked

	var all_others_unlocked = true
	for ach_name in achievements_unlocked:
		if ach_name != "PONG COLOURS" and not achievements_unlocked[ach_name]:
			all_others_unlocked = false
			break # Found one that's not unlocked

	if all_others_unlocked:
		unlock_achievement("PONG COLOURS")
