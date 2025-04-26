# res://scripts/audio_manager.gd
extends Node

@onready var music_player: AudioStreamPlayer = $MusicPlayer

# --- Settings ---
const SETTINGS_FILE = "user://game_settings.cfg"
var music_volume_db: float = 0.0 # Default volume in dB (0 is full)
var sfx_volume_db: float = 0.0   # Default volume in dB
var current_resolution: Vector2i = DisplayServer.window_get_size() # Store current/default
var current_fullscreen_mode: bool = false # Default to windowed

# --- Music Playlist ---
const MUSIC_FOLDER = "res://assets/music/" # CHANGE THIS if your music is elsewhere
var music_files: Array[String] = []
var current_music_index: int = -1
var rng = RandomNumberGenerator.new()

# Bus Indices (fetched once)
var music_bus_idx: int
var sfx_bus_idx: int

func _ready():
	print("AudioManager: Initializing...")
	# Get Bus indices
	music_bus_idx = AudioServer.get_bus_index("Music")
	sfx_bus_idx = AudioServer.get_bus_index("SFX")

	load_settings() # Load saved volumes and resolution

	# Scan music folder
	_scan_music_folder()
	if not music_files.is_empty():
		print("AudioManager: Found music files:", music_files)
		music_files.shuffle() # Randomize initial playlist order
		play_next_music()
	else:
		printerr("AudioManager: No music files found in ", MUSIC_FOLDER)

	# Connect signal AFTER scanning and potentially starting music
	music_player.finished.connect(_on_music_finished)
	print("AudioManager: Ready.")


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
					music_files.append(MUSIC_FOLDER + file_name)
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
		music_files.shuffle() # Re-shuffle when looping (optional, for variety)
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
		play_next_music()


func _on_music_finished():
	print("AudioManager: Music finished, playing next.")
	play_next_music()


# --- Volume Control ---
func set_music_volume(volume_linear: float):
	music_volume_db = linear_to_db(volume_linear) # Convert slider 0-1 to dB
	AudioServer.set_bus_volume_db(music_bus_idx, music_volume_db)
	print("AudioManager: Set Music Volume (dB):", music_volume_db)
	save_settings()

func set_sfx_volume(volume_linear: float):
	sfx_volume_db = linear_to_db(volume_linear) # Convert slider 0-1 to dB
	AudioServer.set_bus_volume_db(sfx_bus_idx, sfx_volume_db)
	print("AudioManager: Set SFX Volume (dB):", sfx_volume_db)
	# Example SFX playback to test:
	# var test_sfx = load("res://path/to/some/sfx.wav") as AudioStream
	# if test_sfx:
	#	 var player = AudioStreamPlayer.new()
	#	 player.stream = test_sfx
	#	 player.bus = "SFX" # Make sure it uses the SFX bus
	#	 add_child(player)
	#	 player.play()
	#	 await player.finished
	#	 player.queue_free()
	save_settings()


# --- Resolution Control ---
func set_resolution(size: Vector2i):
	current_resolution = size
	get_window().size = current_resolution
	print("AudioManager: Set Resolution:", current_resolution)
	save_settings()

func set_fullscreen(fullscreen: bool):
	current_fullscreen_mode = fullscreen
	if fullscreen:
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED
	print("AudioManager: Set Fullscreen:", current_fullscreen_mode)
	save_settings()

# --- Settings Persistence ---
func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "music_volume_db", music_volume_db)
	config.set_value("audio", "sfx_volume_db", sfx_volume_db)
	config.set_value("display", "resolution_width", current_resolution.x)
	config.set_value("display", "resolution_height", current_resolution.y)
	config.set_value("display", "fullscreen", current_fullscreen_mode)

	var err = config.save(SETTINGS_FILE)
	if err != OK:
		printerr("AudioManager: Error saving settings to ", SETTINGS_FILE, " Code: ", err)
	else:
		print("AudioManager: Settings saved.")


func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	if err == OK:
		print("AudioManager: Loading settings from ", SETTINGS_FILE)
		music_volume_db = config.get_value("audio", "music_volume_db", 0.0)
		sfx_volume_db = config.get_value("audio", "sfx_volume_db", 0.0)
		var width = config.get_value("display", "resolution_width", DisplayServer.window_get_size().x)
		var height = config.get_value("display", "resolution_height", DisplayServer.window_get_size().y)
		current_resolution = Vector2i(width, height)
		current_fullscreen_mode = config.get_value("display", "fullscreen", false)

		# Apply loaded settings immediately
		AudioServer.set_bus_volume_db(music_bus_idx, music_volume_db)
		AudioServer.set_bus_volume_db(sfx_bus_idx, sfx_volume_db)
		get_window().size = current_resolution
		set_fullscreen(current_fullscreen_mode) # Use the function to set mode correctly

	else:
		printerr("AudioManager: No settings file found or error loading. Using defaults. Code: ", err)
		# Apply default settings if file doesn't exist
		AudioServer.set_bus_volume_db(music_bus_idx, music_volume_db)
		AudioServer.set_bus_volume_db(sfx_bus_idx, sfx_volume_db)
		# Resolution defaults to current screen size already
