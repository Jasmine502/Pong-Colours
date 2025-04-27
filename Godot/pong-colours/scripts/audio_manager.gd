# res://scripts/audio_manager.gd
extends Node

@onready var music_player: AudioStreamPlayer = $MusicPlayer

# Settings - These will be *updated* by DataManager or UI actions
var music_volume_db: float = 0.0 # Default used *until* settings are applied
var sfx_volume_db: float = 0.0
var current_resolution: Vector2i = DisplayServer.window_get_size() # Store current/default
var current_fullscreen_mode: bool = false # Default to windowed

# Music Playlist
const MUSIC_FOLDER = "res://assets/music/"
var music_files: Array[String] = []
var current_music_index: int = -1
# Removed rng variable as shuffle() uses global random state

# Bus Indices
var music_bus_idx: int = -1
var sfx_bus_idx: int = -1

func _ready():
	print("AudioManager: Initializing...")
	# --- FIX: Seed the random number generator ---
	randomize()

	music_bus_idx = AudioServer.get_bus_index("Music")
	sfx_bus_idx = AudioServer.get_bus_index("SFX")

	if music_bus_idx == -1: printerr("AudioManager: Music audio bus not found!")
	if sfx_bus_idx == -1: printerr("AudioManager: SFX audio bus not found!")

	# Scan for music files
	_scan_music_folder()

	# --- FIX: Shuffle the list *after* scanning ---
	if not music_files.is_empty():
		print("AudioManager: Found %d music files. Shuffling..." % music_files.size())
		music_files.shuffle()
		# print("AudioManager: Shuffled order:", music_files) # Optional: print shuffled list
	else:
		printerr("AudioManager: No music files found in %s" % MUSIC_FOLDER)

	# Defer applying settings (which also starts music playback)
	call_deferred("_apply_initial_settings")

	# Connect signal AFTER player is ready
	if is_instance_valid(music_player):
		music_player.finished.connect(_on_music_finished)
	else:
		printerr("AudioManager: MusicPlayer node is not valid!")

	print("AudioManager: Initial setup done, deferring settings application.")


# Called deferred from _ready
func _apply_initial_settings():
	print("AudioManager: Applying initial settings (deferred)...")
	if not DataManager:
		printerr("AudioManager: DataManager not found when applying initial settings! Using defaults.")
		_apply_settings(0.0, 0.0, DisplayServer.window_get_size(), false)
	else:
		print("AudioManager: Fetching settings from DataManager.")
		var loaded_music_db = DataManager.get_value_or_default("audio", "music_volume_db", 0.0)
		var loaded_sfx_db = DataManager.get_value_or_default("audio", "sfx_volume_db", 0.0)
		var loaded_res_w = DataManager.get_value_or_default("display", "resolution_width", DisplayServer.window_get_size().x)
		var loaded_res_h = DataManager.get_value_or_default("display", "resolution_height", DisplayServer.window_get_size().y)
		var loaded_fs = DataManager.get_value_or_default("display", "fullscreen", false)
		_apply_settings(loaded_music_db, loaded_sfx_db, Vector2i(loaded_res_w, loaded_res_h), loaded_fs)

	# Now that initial volume is likely set, start music using the shuffled list
	# The index will be -1, so play_next_music will increment to 0 and play the *first shuffled track*
	if not music_files.is_empty() and is_instance_valid(music_player):
		if music_player.stream == null or not music_player.is_playing():
			print("AudioManager: Starting initial music playback...")
			play_next_music() # This will play the track at index 0 of the shuffled list
	# No need for the 'else' here as we printed the error in _ready if empty

	print("AudioManager: Deferred settings applied. AudioManager Ready.")


# --- Helper function to apply settings internally ---
# (No changes needed in _apply_settings)
func _apply_settings(music_db: float, sfx_db: float, resolution: Vector2i, fullscreen: bool):
	print("AudioManager: Applying settings: MusicDB=%.2f, SfxDB=%.2f, Res=%s, FS=%s" % [music_db, sfx_db, resolution, fullscreen])
	music_volume_db = music_db
	sfx_volume_db = sfx_db
	current_resolution = resolution
	current_fullscreen_mode = fullscreen
	if music_bus_idx != -1: AudioServer.set_bus_volume_db(music_bus_idx, music_volume_db)
	if sfx_bus_idx != -1: AudioServer.set_bus_volume_db(sfx_bus_idx, sfx_volume_db)
	_apply_display_mode(current_fullscreen_mode)
	_apply_resolution(current_resolution)

# --- Scan Music Folder ---
# (No changes needed in _scan_music_folder)
func _scan_music_folder():
	music_files.clear()
	var dir = DirAccess.open(MUSIC_FOLDER)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".wav") or file_name.ends_with(".ogg") or file_name.ends_with(".mp3"):
					music_files.append(MUSIC_FOLDER.path_join(file_name))
			file_name = dir.get_next()
	else:
		printerr("AudioManager: Could not open music directory: ", MUSIC_FOLDER)


# --- Play Next Music ---
# (No changes needed in play_next_music, it uses the already shuffled list)
func play_next_music():
	if not is_instance_valid(music_player):
		printerr("AudioManager: Cannot play music, MusicPlayer node is invalid.")
		return
	if music_files.is_empty():
		return

	current_music_index += 1
	if current_music_index >= music_files.size():
		current_music_index = 0
		# Shuffle again when playlist loops
		print("AudioManager: Playlist looped, shuffling again.")
		music_files.shuffle()

	var next_track_path = music_files[current_music_index] # Plays from shuffled list
	var stream = load(next_track_path) as AudioStream
	if stream:
		music_player.stream = stream
		music_player.play()
		print("AudioManager: Playing:", next_track_path.get_file(), "(Index:", current_music_index, ")")
	else:
		printerr("AudioManager: Failed to load music stream:", next_track_path)
		push_warning("Skipping track: " + next_track_path)
		if music_files.size() > 1:
			call_deferred("play_next_music")


# --- On Music Finished ---
# (No changes needed in _on_music_finished)
func _on_music_finished():
	play_next_music()


# --- Volume Control ---
# (No changes needed in set_music_volume, set_sfx_volume)
func set_music_volume(volume_linear: float):
	var new_db = linear_to_db(clampf(volume_linear, 0.0001, 1.0))
	if abs(music_volume_db - new_db) < 0.01 and music_volume_db != 0.0: return
	music_volume_db = new_db
	if music_bus_idx != -1: AudioServer.set_bus_volume_db(music_bus_idx, music_volume_db)
	print("AudioManager: Set Music Volume (dB):", music_volume_db)
	if DataManager: DataManager.update_and_save_setting("audio", "music_volume_db", music_volume_db)

func set_sfx_volume(volume_linear: float):
	var new_db = linear_to_db(clampf(volume_linear, 0.0001, 1.0))
	if abs(sfx_volume_db - new_db) < 0.01 and sfx_volume_db != 0.0: return
	sfx_volume_db = new_db
	if sfx_bus_idx != -1: AudioServer.set_bus_volume_db(sfx_bus_idx, sfx_volume_db)
	print("AudioManager: Set SFX Volume (dB):", sfx_volume_db)
	if DataManager: DataManager.update_and_save_setting("audio", "sfx_volume_db", sfx_volume_db)


# --- Resolution Control ---
# (No changes needed in _apply_resolution, _apply_display_mode, set_resolution, set_fullscreen)
func _apply_resolution(size: Vector2i):
	if size == Vector2i.ZERO:
		printerr("AudioManager: Invalid resolution (0,0), skipping apply.")
		return
	var current_mode = get_window().mode
	if current_mode == Window.MODE_WINDOWED or current_mode == Window.MODE_FULLSCREEN:
		if get_window().size != size:
			print("AudioManager: Applying window size:", size)
			get_window().size = size

func _apply_display_mode(fullscreen: bool):
	var target_mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if get_window().mode != target_mode:
		print("AudioManager: Setting window mode to:", target_mode)
		get_window().mode = target_mode
		if not fullscreen:
			call_deferred("_apply_resolution", current_resolution)

func set_resolution(size: Vector2i):
	if current_resolution == size: return
	current_resolution = size
	print("AudioManager: Resolution set to:", current_resolution)
	_apply_resolution(current_resolution)
	if DataManager:
		DataManager.update_and_save_setting("display", "resolution_width", current_resolution.x, false)
		DataManager.update_and_save_setting("display", "resolution_height", current_resolution.y, false)
		DataManager.save_data()

func set_fullscreen(fullscreen: bool):
	var current_mode_enum = get_window().mode
	var is_currently_fullscreen = (current_mode_enum == Window.MODE_FULLSCREEN or current_mode_enum == Window.MODE_EXCLUSIVE_FULLSCREEN)
	if current_fullscreen_mode == fullscreen and is_currently_fullscreen == fullscreen: return
	current_fullscreen_mode = fullscreen
	print("AudioManager: Fullscreen set to:", current_fullscreen_mode)
	_apply_display_mode(current_fullscreen_mode)
	if DataManager: DataManager.update_and_save_setting("display", "fullscreen", current_fullscreen_mode)
