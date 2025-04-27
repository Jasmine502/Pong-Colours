# res://scripts/audio_manager.gd
extends Node

# --- Node References ---
@onready var music_player: AudioStreamPlayer = $MusicPlayer

# --- Exported Audio Streams (Link music files in the Godot Editor Inspector!) ---
@export_category("Music Playlist")
@export var music_streams: Array[AudioStream] = []
# --- End Exported Audio ---


# Settings - These will be *updated* by DataManager or UI actions
var music_volume_db: float = 0.0 # Default used *until* settings are applied
var sfx_volume_db: float = 0.0
var current_resolution: Vector2i = DisplayServer.window_get_size() # Store current/default
var current_fullscreen_mode: bool = false # Default to windowed


# --- Music Playback State ---
var current_music_index: int = -1
var shuffled_indices: Array[int] = [] # Store shuffled order of indices


# --- Bus Indices ---
var music_bus_idx: int = -1
var sfx_bus_idx: int = -1


func _ready():
	print("AudioManager: Initializing...")
	# Seed the random number generator
	randomize()

	# Get Audio Bus Indices
	music_bus_idx = AudioServer.get_bus_index("Music")
	sfx_bus_idx = AudioServer.get_bus_index("SFX")

	if music_bus_idx == -1: printerr("AudioManager: Music audio bus not found!")
	if sfx_bus_idx == -1: printerr("AudioManager: SFX audio bus not found!")

	# --- NEW: Prepare shuffled playlist from exported streams ---
	_prepare_shuffled_playlist()

	# Defer applying settings (which also starts music playback)
	# Wait until DataManager is definitely ready
	call_deferred("_apply_initial_settings")

	# Connect signal AFTER player is ready and streams are potentially loaded
	if is_instance_valid(music_player):
		# Connect the finished signal to automatically play the next track
		if not music_player.is_connected("finished", _on_music_finished):
			music_player.finished.connect(_on_music_finished)
	else:
		printerr("AudioManager: MusicPlayer node is not valid!")

	print("AudioManager: Initial setup done, deferring settings application.")


# --- NEW: Prepare shuffled indices based on exported streams ---
func _prepare_shuffled_playlist():
	shuffled_indices.clear()
	if music_streams.is_empty():
		printerr("AudioManager Warning: No music streams linked in the Inspector!")
		return

	# Create an array of indices [0, 1, 2, ..., n-1]
	for i in music_streams.size():
		# Basic check if the slot is filled in the editor
		if music_streams[i] is AudioStream:
			shuffled_indices.append(i)
		else:
			printerr("AudioManager Warning: music_streams array index %d is empty or not an AudioStream." % i)

	if shuffled_indices.is_empty():
		printerr("AudioManager Error: No valid music streams found in the exported array!")
		return

	# Shuffle the valid indices
	shuffled_indices.shuffle()
	print("AudioManager: Prepared shuffled playlist with %d tracks." % shuffled_indices.size())
	# print("AudioManager: Shuffled index order:", shuffled_indices) # Optional debug


# Called deferred from _ready
func _apply_initial_settings():
	print("AudioManager: Applying initial settings (deferred)...")
	if not DataManager:
		printerr("AudioManager: DataManager not found when applying initial settings! Using defaults.")
		# Apply hardcoded defaults if DataManager is missing
		_apply_settings(0.0, 0.0, DisplayServer.window_get_size(), false)
	else:
		print("AudioManager: Fetching settings from DataManager.")
		# Use DataManager's helper to get values safely
		var loaded_music_db = DataManager.get_value_or_default("audio", "music_volume_db", 0.0)
		var loaded_sfx_db = DataManager.get_value_or_default("audio", "sfx_volume_db", 0.0)
		var loaded_res_w = DataManager.get_value_or_default("display", "resolution_width", DisplayServer.window_get_size().x)
		var loaded_res_h = DataManager.get_value_or_default("display", "resolution_height", DisplayServer.window_get_size().y)
		var loaded_fs = DataManager.get_value_or_default("display", "fullscreen", false)
		_apply_settings(loaded_music_db, loaded_sfx_db, Vector2i(loaded_res_w, loaded_res_h), loaded_fs)

	# Now that initial volume is likely set, start music using the shuffled list
	# The index will be -1, so play_next_music will increment to 0 and play the first shuffled track
	if not shuffled_indices.is_empty() and is_instance_valid(music_player):
		if music_player.stream == null or not music_player.is_playing():
			print("AudioManager: Starting initial music playback...")
			current_music_index = -1 # Ensure it starts from the beginning of the shuffled list
			play_next_music() # This will play the track at shuffled_indices[0]
	# Error messages for empty/invalid streams are handled in _prepare_shuffled_playlist

	print("AudioManager: Deferred settings applied. AudioManager Ready.")


# --- Helper function to apply settings internally ---
# Applies volume, resolution, and fullscreen mode based on provided values
func _apply_settings(music_db: float, sfx_db: float, resolution: Vector2i, fullscreen: bool):
	print("AudioManager: Applying settings: MusicDB=%.2f, SfxDB=%.2f, Res=%s, FS=%s" % [music_db, sfx_db, resolution, fullscreen])

	# Store current settings internally
	music_volume_db = music_db
	sfx_volume_db = sfx_db
	current_resolution = resolution
	current_fullscreen_mode = fullscreen

	# Apply audio volume to buses
	if music_bus_idx != -1: AudioServer.set_bus_volume_db(music_bus_idx, music_volume_db)
	else: printerr("AudioManager: Cannot set music volume, bus index invalid.")
	if sfx_bus_idx != -1: AudioServer.set_bus_volume_db(sfx_bus_idx, sfx_volume_db)
	else: printerr("AudioManager: Cannot set SFX volume, bus index invalid.")

	# Apply display settings (resolution and fullscreen)
	_apply_display_mode(current_fullscreen_mode) # Apply fullscreen first
	_apply_resolution(current_resolution) # Apply resolution


# REMOVED: _scan_music_folder() is no longer needed


# --- Play Next Music ---
# Plays the next track based on the shuffled_indices array
func play_next_music():
	if not is_instance_valid(music_player):
		printerr("AudioManager: Cannot play music, MusicPlayer node is invalid.")
		return
	if shuffled_indices.is_empty():
		print("AudioManager: No music tracks available to play.")
		return

	# Increment index for the shuffled list
	current_music_index += 1

	# Check if we reached the end of the shuffled list
	if current_music_index >= shuffled_indices.size():
		current_music_index = 0 # Wrap around to the beginning
		# Optionally re-shuffle when the playlist loops
		print("AudioManager: Playlist looped, re-shuffling indices.")
		shuffled_indices.shuffle()
		# print("AudioManager: New shuffled order:", shuffled_indices) # Optional debug

	# Get the actual stream index from the shuffled list
	var stream_index_to_play = shuffled_indices[current_music_index]

	# --- Safely access the stream from the main music_streams array ---
	if stream_index_to_play >= 0 and stream_index_to_play < music_streams.size():
		var stream = music_streams[stream_index_to_play]
		if stream is AudioStream:
			music_player.stream = stream
			music_player.play()
			# Try to get a meaningful name (resource path if available)
			var track_name = stream.resource_path.get_file() if stream.resource_path else "Track %d" % stream_index_to_play
			print("AudioManager: Playing:", track_name, "(Shuffled Index:", current_music_index, ", Original Index:", stream_index_to_play, ")")
		else:
			printerr("AudioManager: Invalid stream found at index %d (shuffled index %d)." % [stream_index_to_play, current_music_index])
			# Attempt to play the next one immediately
			call_deferred("play_next_music")
	else:
		printerr("AudioManager: Invalid stream index %d obtained from shuffled list (shuffled index %d)." % [stream_index_to_play, current_music_index])
		# Attempt to play the next one
		call_deferred("play_next_music")


# --- On Music Finished ---
# Called automatically when the music_player finishes playing a track
func _on_music_finished():
	print("AudioManager: Music track finished.")
	play_next_music() # Play the next one in the shuffled list


# --- Volume Control ---
# Converts linear slider value (0-1) to dB and applies it to the bus
func set_music_volume(volume_linear: float):
	# Clamp input just in case, use 0.0001 to avoid log(0) -> -inf dB
	var new_db = linear_to_db(clampf(volume_linear, 0.0001, 1.0))

	# Optional: Avoid tiny adjustments if value hasn't changed much
	# if abs(music_volume_db - new_db) < 0.01: return

	music_volume_db = new_db
	if music_bus_idx != -1:
		AudioServer.set_bus_volume_db(music_bus_idx, music_volume_db)
		print("AudioManager: Set Music Volume (Linear: %.2f, dB: %.2f)" % [volume_linear, music_volume_db])
	else:
		printerr("AudioManager: Cannot set music volume, bus index invalid.")

	# Update DataManager and save immediately
	if DataManager: DataManager.update_and_save_setting("audio", "music_volume_db", music_volume_db)

func set_sfx_volume(volume_linear: float):
	var new_db = linear_to_db(clampf(volume_linear, 0.0001, 1.0))
	# if abs(sfx_volume_db - new_db) < 0.01: return
	sfx_volume_db = new_db
	if sfx_bus_idx != -1:
		AudioServer.set_bus_volume_db(sfx_bus_idx, sfx_volume_db)
		print("AudioManager: Set SFX Volume (Linear: %.2f, dB: %.2f)" % [volume_linear, sfx_volume_db])
	else:
		printerr("AudioManager: Cannot set SFX volume, bus index invalid.")

	# Update DataManager and save immediately
	if DataManager: DataManager.update_and_save_setting("audio", "sfx_volume_db", sfx_volume_db)


# --- Resolution Control ---
# Internal function to apply resolution (window size)
func _apply_resolution(size: Vector2i):
	if size == Vector2i.ZERO:
		printerr("AudioManager: Invalid resolution (0,0), skipping apply.")
		return

	var window = get_window()
	if not is_instance_valid(window):
		printerr("AudioManager: Cannot get window instance.")
		return

	# Only change size if windowed or fullscreen (exclusive fullscreen handles size differently)
	var current_mode = window.mode
	if current_mode == Window.MODE_WINDOWED or current_mode == Window.MODE_FULLSCREEN:
		if window.size != size:
			print("AudioManager: Applying window size:", size)
			window.size = size
			# Optional: Center window after resize?
			# window.position = DisplayServer.screen_get_position() + (DisplayServer.screen_get_size() - size) / 2
	elif current_mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		print("AudioManager: In Exclusive Fullscreen, resolution change handled by mode setting.")


# Internal function to apply fullscreen/windowed mode
func _apply_display_mode(fullscreen: bool):
	var window = get_window()
	if not is_instance_valid(window):
		printerr("AudioManager: Cannot get window instance.")
		return

	var target_mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if window.mode != target_mode:
		print("AudioManager: Setting window mode to:", "Fullscreen" if fullscreen else "Windowed")
		window.mode = target_mode
		# If switching *to* windowed, re-apply the stored resolution immediately
		if not fullscreen:
			# Need to wait a frame for mode switch potentially? Use call_deferred
			call_deferred("_apply_resolution", current_resolution)


# Called by Options menu when resolution dropdown changes
func set_resolution(size: Vector2i):
	if current_resolution == size: return # No change

	current_resolution = size
	print("AudioManager: Resolution set to:", current_resolution)
	_apply_resolution(current_resolution) # Apply the change visually

	# Save the new resolution settings to DataManager
	if DataManager:
		# Update both width and height, but save only once at the end
		DataManager.update_and_save_setting("display", "resolution_width", current_resolution.x, false) # Don't save yet
		DataManager.update_and_save_setting("display", "resolution_height", current_resolution.y, true) # Save now


# Called by Options menu when fullscreen checkbox changes
func set_fullscreen(fullscreen: bool):
	var window = get_window()
	if not is_instance_valid(window):
		printerr("AudioManager: Cannot get window instance.")
		return

	# Check current state accurately
	var current_mode_enum = window.mode
	var is_currently_fullscreen = (current_mode_enum == Window.MODE_FULLSCREEN or current_mode_enum == Window.MODE_EXCLUSIVE_FULLSCREEN)

	# Only change if the desired state is different from the actual state
	if is_currently_fullscreen != fullscreen:
		current_fullscreen_mode = fullscreen # Store the desired state
		print("AudioManager: Fullscreen set to:", current_fullscreen_mode)
		_apply_display_mode(current_fullscreen_mode) # Apply the change visually

		# Save the new fullscreen setting
		if DataManager: DataManager.update_and_save_setting("display", "fullscreen", current_fullscreen_mode)
	else:
		# If the desired state already matches the actual state, ensure our internal variable is synced
		current_fullscreen_mode = fullscreen
