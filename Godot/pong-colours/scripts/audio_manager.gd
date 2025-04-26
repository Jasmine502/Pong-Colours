# res://scripts/audio_manager.gd
extends Node

@onready var music_player: AudioStreamPlayer = $MusicPlayer

# --- Settings (Values are now primarily loaded/saved by DataManager) ---
var music_volume_db: float = 0.0 # Default volume in dB (0 is full)
var sfx_volume_db: float = 0.0   # Default volume in dB
var current_resolution: Vector2i = DisplayServer.window_get_size() # Store current/default
var current_fullscreen_mode: bool = false # Default to windowed

# --- Music Playlist ---
const MUSIC_FOLDER = "res://assets/music/" # Ensure this path is correct
var music_files: Array[String] = []
var current_music_index: int = -1
var rng = RandomNumberGenerator.new()

# Bus Indices
var music_bus_idx: int = -1 # Initialize to invalid
var sfx_bus_idx: int = -1   # Initialize to invalid

func _ready():
	print("AudioManager: Initializing...")
	music_bus_idx = AudioServer.get_bus_index("Music")
	sfx_bus_idx = AudioServer.get_bus_index("SFX")

	if music_bus_idx == -1: printerr("AudioManager: Music audio bus not found!")
	if sfx_bus_idx == -1: printerr("AudioManager: SFX audio bus not found!")

	# Settings are now loaded via DataManager calling load_settings_from_data()
	# Apply initial defaults here in case DataManager loads first time or has no save
	if music_bus_idx != -1: AudioServer.set_bus_volume_db(music_bus_idx, music_volume_db)
	if sfx_bus_idx != -1: AudioServer.set_bus_volume_db(sfx_bus_idx, sfx_volume_db)
	get_window().size = current_resolution
	set_fullscreen(current_fullscreen_mode) # Use func to set mode correctly

	_scan_music_folder()
	if not music_files.is_empty():
		print("AudioManager: Found music files:", music_files.size())
		music_files.shuffle()
		play_next_music()
	else:
		printerr("AudioManager: No music files found in ", MUSIC_FOLDER)

	music_player.finished.connect(_on_music_finished)
	print("AudioManager: Ready.")


# --- Function called by DataManager ---
func load_settings_from_data(music_db: float, sfx_db: float, resolution: Vector2i, fullscreen: bool):
	print("AudioManager: Applying settings loaded by DataManager.")
	music_volume_db = music_db
	sfx_volume_db = sfx_db
	current_resolution = resolution
	current_fullscreen_mode = fullscreen

	# Apply loaded settings immediately
	if music_bus_idx != -1: AudioServer.set_bus_volume_db(music_bus_idx, music_volume_db)
	if sfx_bus_idx != -1: AudioServer.set_bus_volume_db(sfx_bus_idx, sfx_volume_db)

	# Apply display settings carefully
	set_fullscreen(current_fullscreen_mode) # Set mode first
	# Apply resolution after mode is set (might be ignored in true fullscreen)
	if not current_fullscreen_mode:
		get_window().size = current_resolution

	print("AudioManager: Applied Music dB:", music_db, "SFX dB:", sfx_db, "Res:", resolution, "FS:", fullscreen)


func _scan_music_folder():
	music_files.clear()
	var dir = DirAccess.open(MUSIC_FOLDER)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				# Add supported audio file types
				if file_name.ends_with(".wav") or file_name.ends_with(".ogg") or file_name.ends_with(".mp3"):
					music_files.append(MUSIC_FOLDER.path_join(file_name)) # Use path_join
			file_name = dir.get_next()
	else:
		printerr("AudioManager: Could not open music directory: ", MUSIC_FOLDER)


func play_next_music():
	if music_files.is_empty():
		printerr("AudioManager: No music to play.")
		return

	current_music_index += 1
	if current_music_index >= music_files.size():
		current_music_index = 0 # Loop back to the beginning
		music_files.shuffle() # Re-shuffle when looping
		print("AudioManager: Playlist looped, shuffling.")

	var next_track_path = music_files[current_music_index]
	var stream = load(next_track_path) as AudioStream
	if stream:
		music_player.stream = stream
		music_player.play()
		print("AudioManager: Playing:", next_track_path.get_file())
	else:
		printerr("AudioManager: Failed to load music stream:", next_track_path)
		# Try next song immediately if loading failed
		push_warning("Skipping track: " + next_track_path)
		# Add a small delay or check to prevent infinite loop if all tracks fail
		if music_files.size() > 1: # Avoid infinite loop if only one bad track exists
			call_deferred("play_next_music") # Try again next frame


func _on_music_finished():
	print("AudioManager: Music finished, playing next.")
	play_next_music()


# --- Volume Control ---
func set_music_volume(volume_linear: float):
	music_volume_db = linear_to_db(clampf(volume_linear, 0.0, 1.0)) # Ensure 0-1 range
	if music_bus_idx != -1: AudioServer.set_bus_volume_db(music_bus_idx, music_volume_db)
	print("AudioManager: Set Music Volume (dB):", music_volume_db)
	if DataManager: DataManager.save_data() # Tell DataManager to save everything

func set_sfx_volume(volume_linear: float):
	sfx_volume_db = linear_to_db(clampf(volume_linear, 0.0, 1.0)) # Ensure 0-1 range
	if sfx_bus_idx != -1: AudioServer.set_bus_volume_db(sfx_bus_idx, sfx_volume_db)
	print("AudioManager: Set SFX Volume (dB):", sfx_volume_db)
	if DataManager: DataManager.save_data() # Tell DataManager to save everything


# --- Resolution Control ---
func set_resolution(size: Vector2i):
	if current_resolution == size: return # Avoid redundant sets
	current_resolution = size
	# Only apply if not fullscreen
	if get_window().mode != Window.MODE_FULLSCREEN:
		get_window().size = current_resolution
	print("AudioManager: Set Resolution:", current_resolution)
	if DataManager: DataManager.save_data() # Tell DataManager to save everything

func set_fullscreen(fullscreen: bool):
	var current_mode = get_window().mode
	var target_mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED

	if current_mode == target_mode and current_fullscreen_mode == fullscreen:
		# Also check our internal flag matches window state
		return # Avoid redundant sets

	current_fullscreen_mode = fullscreen # Update internal flag first

	get_window().mode = target_mode
	# Re-apply desired resolution when exiting fullscreen AFTER mode change
	if not fullscreen and current_mode == Window.MODE_FULLSCREEN:
		# Short delay might be needed for window manager to catch up after mode change
		await get_tree().process_frame
		get_window().size = current_resolution

	print("AudioManager: Set Fullscreen:", current_fullscreen_mode, " Mode:", target_mode)
	if DataManager: DataManager.save_data() # Tell DataManager to save everything
