# res://scripts/audio_manager.gd
extends Node

# --- Node References ---
@onready var music_player: AudioStreamPlayer = $MusicPlayer
# --- REMOVED: No longer need a persistent SFX player node reference ---
# @onready var sfx_player: AudioStreamPlayer = $SFXPlayer

# --- Exported Audio Streams ---
@export_category("Music Playlist")
@export var music_streams: Array[AudioStream] = []

# --- Exported Individual Sound Effects ---
@export_category("Sound Effects")
@export var sfx_paddle_hit: AudioStream = null
@export var sfx_reset_data: AudioStream = null
@export var sfx_button_click: AudioStream = null
@export var sfx_achievement_unlocked: AudioStream = null
@export var sfx_wall_bounce: AudioStream = null
@export var sfx_score_point: AudioStream = null
# --- End Exported Audio ---


# Settings
var music_volume_db: float = 0.0
var sfx_volume_db: float = 0.0
var current_resolution: Vector2i = DisplayServer.window_get_size()
var current_fullscreen_mode: bool = false


# Music Playback State
var current_music_index: int = -1
var shuffled_indices: Array[int] = []


# Bus Indices
var music_bus_idx: int = -1
var sfx_bus_idx: int = -1


func _ready():
	print("AudioManager: Initializing...")
	randomize()

	music_bus_idx = AudioServer.get_bus_index("Music")
	sfx_bus_idx = AudioServer.get_bus_index("SFX")

	if music_bus_idx == -1: printerr("AudioManager: Music audio bus not found!")
	if sfx_bus_idx == -1: printerr("AudioManager: SFX audio bus not found! SFX volume might not work correctly.")

	# --- REMOVED: Check for SFXPlayer node is no longer needed ---
	# if not is_instance_valid(sfx_player): ...

	_prepare_shuffled_playlist()
	call_deferred("_apply_initial_settings")

	if is_instance_valid(music_player):
		if not music_player.is_connected("finished", _on_music_finished):
			music_player.finished.connect(_on_music_finished)
	else:
		printerr("AudioManager: MusicPlayer node is not valid!")

	print("AudioManager: Initial setup done, deferring settings application.")


# --- (Functions _prepare_shuffled_playlist, _apply_initial_settings, _apply_settings, play_next_music, _on_music_finished remain unchanged) ---

func _prepare_shuffled_playlist():
	shuffled_indices.clear()
	if music_streams.is_empty():
		printerr("AudioManager Warning: No music streams linked in the Inspector!")
		return
	for i in music_streams.size():
		if music_streams[i] is AudioStream: shuffled_indices.append(i)
		else: printerr("AudioManager Warning: music_streams array index %d is empty or not an AudioStream." % i)
	if shuffled_indices.is_empty():
		printerr("AudioManager Error: No valid music streams found in the exported array!"); return
	shuffled_indices.shuffle()
	print("AudioManager: Prepared shuffled playlist with %d tracks." % shuffled_indices.size())

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

	if not shuffled_indices.is_empty() and is_instance_valid(music_player):
		if music_player.stream == null or not music_player.is_playing():
			print("AudioManager: Starting initial music playback...")
			current_music_index = -1; play_next_music()

	print("AudioManager: Deferred settings applied. AudioManager Ready.")

func _apply_settings(music_db: float, sfx_db: float, resolution: Vector2i, fullscreen: bool):
	print("AudioManager: Applying settings: MusicDB=%.2f, SfxDB=%.2f, Res=%s, FS=%s" % [music_db, sfx_db, resolution, fullscreen])
	music_volume_db = music_db; sfx_volume_db = sfx_db
	current_resolution = resolution; current_fullscreen_mode = fullscreen
	if music_bus_idx != -1: AudioServer.set_bus_volume_db(music_bus_idx, music_volume_db)
	else: printerr("AudioManager: Cannot set music volume, bus index invalid.")
	if sfx_bus_idx != -1: AudioServer.set_bus_volume_db(sfx_bus_idx, sfx_volume_db)
	else: printerr("AudioManager: Cannot set SFX volume, bus index invalid.")
	_apply_display_mode(current_fullscreen_mode)
	_apply_resolution(current_resolution)

func play_next_music():
	if not is_instance_valid(music_player): printerr("AudioManager: Cannot play music, MusicPlayer node is invalid."); return
	if shuffled_indices.is_empty(): print("AudioManager: No music tracks available to play."); return
	current_music_index += 1
	if current_music_index >= shuffled_indices.size():
		current_music_index = 0; print("AudioManager: Playlist looped, re-shuffling indices."); shuffled_indices.shuffle()
	var stream_index_to_play = shuffled_indices[current_music_index]
	if stream_index_to_play >= 0 and stream_index_to_play < music_streams.size():
		var stream = music_streams[stream_index_to_play]
		if stream is AudioStream:
			music_player.stream = stream; music_player.play()
			var track_name = stream.resource_path.get_file() if stream.resource_path else "Track %d" % stream_index_to_play
			print("AudioManager: Playing:", track_name, "(Shuffled Index:", current_music_index, ", Original Index:", stream_index_to_play, ")")
		else: printerr("AudioManager: Invalid stream found at index %d (shuffled index %d)." % [stream_index_to_play, current_music_index]); call_deferred("play_next_music")
	else: printerr("AudioManager: Invalid stream index %d obtained from shuffled list (shuffled index %d)." % [stream_index_to_play, current_music_index]); call_deferred("play_next_music")

func _on_music_finished():
	print("AudioManager: Music track finished.")
	play_next_music()

# --- HEAVILY MODIFIED: Play Sound Effect Function ---
func play_sfx(sfx_name: String):
	# --- Get the correct AudioStream based on the name ---
	var stream_to_play: AudioStream = null
	match sfx_name:
		"PaddleHit": stream_to_play = sfx_paddle_hit
		"ResetData": stream_to_play = sfx_reset_data
		"ButtonClick": stream_to_play = sfx_button_click
		"AchievementUnlocked": stream_to_play = sfx_achievement_unlocked
		"WallBounce": stream_to_play = sfx_wall_bounce
		"ScorePoint": stream_to_play = sfx_score_point
		_:
			printerr("AudioManager: Unknown SFX name '%s' requested." % sfx_name)
			return

	# --- Check if a stream was assigned in the Inspector ---
	if not stream_to_play is AudioStream:
		printerr("AudioManager: No AudioStream assigned for SFX '%s' in the Inspector." % sfx_name)
		return

	# --- Create a new, temporary player ---
	var temp_player = AudioStreamPlayer.new()

	# --- Assign the stream ---
	temp_player.stream = stream_to_play

	# --- IMPORTANT: Assign it to the correct audio bus ---
	# Use the stored index. If the index is bad (-1), it defaults to Master,
	# but we print an error in _ready() if the bus wasn't found.
	if sfx_bus_idx != -1:
		temp_player.bus = AudioServer.get_bus_name(sfx_bus_idx) # Use bus name string
	# else: it will use Master bus, which is okay as a fallback but SFX volume won't apply

	# --- Add the temporary player to the scene tree ---
	# Adding it as a child of AudioManager makes sense.
	# Check if AudioManager node is still valid before adding child
	if not is_instance_valid(self):
		printerr("AudioManager: Instance not valid, cannot add temporary SFX player.")
		# Clean up the player we just created if we can't add it
		if is_instance_valid(temp_player): temp_player.queue_free()
		return
	add_child(temp_player)

	# --- Play the sound ---
	temp_player.play()

	# --- Connect the 'finished' signal to the player's 'queue_free' method ---
	# This ensures the node cleans itself up automatically after playing.
	temp_player.finished.connect(temp_player.queue_free)

	# Optional: print("AudioManager: Playing SFX:", sfx_name, "on temporary player.")


# --- Volume Control (Unchanged) ---
func set_music_volume(volume_linear: float):
	var new_db = linear_to_db(clampf(volume_linear, 0.0001, 1.0))
	music_volume_db = new_db
	if music_bus_idx != -1: AudioServer.set_bus_volume_db(music_bus_idx, music_volume_db)
	else: printerr("AudioManager: Cannot set music volume, bus index invalid.")
	if DataManager: DataManager.update_and_save_setting("audio", "music_volume_db", music_volume_db)

func set_sfx_volume(volume_linear: float):
	var new_db = linear_to_db(clampf(volume_linear, 0.0001, 1.0))
	sfx_volume_db = new_db
	if sfx_bus_idx != -1: AudioServer.set_bus_volume_db(sfx_bus_idx, sfx_volume_db)
	else: printerr("AudioManager: Cannot set SFX volume, bus index invalid.")
	if DataManager: DataManager.update_and_save_setting("audio", "sfx_volume_db", sfx_volume_db)


# --- Resolution/Display Control (Unchanged) ---
func _apply_resolution(size: Vector2i):
	if size == Vector2i.ZERO: printerr("AudioManager: Invalid resolution (0,0), skipping apply."); return
	var window = get_window(); if not is_instance_valid(window): printerr("AudioManager: Cannot get window instance."); return
	var current_mode = window.mode
	if current_mode == Window.MODE_WINDOWED or current_mode == Window.MODE_FULLSCREEN:
		if window.size != size: print("AudioManager: Applying window size:", size); window.size = size
	elif current_mode == Window.MODE_EXCLUSIVE_FULLSCREEN: print("AudioManager: In Exclusive Fullscreen, resolution change handled by mode setting.")

func _apply_display_mode(fullscreen: bool):
	var window = get_window(); if not is_instance_valid(window): printerr("AudioManager: Cannot get window instance."); return
	var target_mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if window.mode != target_mode:
		print("AudioManager: Setting window mode to:", "Fullscreen" if fullscreen else "Windowed"); window.mode = target_mode
		if not fullscreen: call_deferred("_apply_resolution", current_resolution)

func set_resolution(size: Vector2i):
	if current_resolution == size: return
	current_resolution = size; print("AudioManager: Resolution set to:", current_resolution); _apply_resolution(current_resolution)
	if DataManager: DataManager.update_and_save_setting("display", "resolution_width", current_resolution.x, false); DataManager.update_and_save_setting("display", "resolution_height", current_resolution.y, true)

func set_fullscreen(fullscreen: bool):
	var window = get_window(); if not is_instance_valid(window): printerr("AudioManager: Cannot get window instance."); return
	var current_mode_enum = window.mode; var is_currently_fullscreen = (current_mode_enum == Window.MODE_FULLSCREEN or current_mode_enum == Window.MODE_EXCLUSIVE_FULLSCREEN)
	if is_currently_fullscreen != fullscreen:
		current_fullscreen_mode = fullscreen; print("AudioManager: Fullscreen set to:", current_fullscreen_mode); _apply_display_mode(current_fullscreen_mode)
		if DataManager: DataManager.update_and_save_setting("display", "fullscreen", current_fullscreen_mode)
	else: current_fullscreen_mode = fullscreen
