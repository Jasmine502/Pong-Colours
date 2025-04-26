# scenes/options_menu.gd
extends Control

# --- Volume Controls ---
@onready var music_volume_slider = $OptionsLayout/HBoxContainer2/MusicVolumeSlider
@onready var sfx_volume_slider = $OptionsLayout/HBoxContainer3/SfxVolumeSlider

# --- Display Controls ---
@onready var resolution_option_button = $OptionsLayout/HBoxContainer4/ResolutionOptionButton
@onready var fullscreen_checkbox = $OptionsLayout/HBoxContainer5/FullscreenCheckBox        # Adjust path

# Store available resolutions to map index back to size
var available_resolutions: Array[Vector2i] = []

func _ready():
	# --- Connect Signals ---
	music_volume_slider.value_changed.connect(_on_music_volume_slider_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_slider_changed)
	resolution_option_button.item_selected.connect(_on_resolution_selected)
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)

	# --- Populate Display Options ---
	_populate_resolution_options()

	# --- Load Current Settings from AudioManager ---
	# Important: Access Autoloads directly by their registered name
	if AudioManager:
		# Set Slider Values (Convert dB back to linear 0-1)
		music_volume_slider.value = db_to_linear(AudioManager.music_volume_db)
		sfx_volume_slider.value = db_to_linear(AudioManager.sfx_volume_db)

		# Set Resolution Dropdown Selection
		var current_res = AudioManager.current_resolution
		var selected_index = -1
		for i in available_resolutions.size():
			if available_resolutions[i] == current_res:
				selected_index = i
				break
		if selected_index != -1:
			resolution_option_button.select(selected_index)
		else:
			# If current resolution isn't in our list, add it and select it
			var res_string = "%d x %d" % [current_res.x, current_res.y]
			resolution_option_button.add_item(res_string)
			available_resolutions.append(current_res)
			resolution_option_button.select(resolution_option_button.item_count - 1)

		# Set Fullscreen Checkbox
		fullscreen_checkbox.button_pressed = AudioManager.current_fullscreen_mode
	else:
		printerr("Options Menu: Cannot find AudioManager Autoload!")


func _populate_resolution_options():
	resolution_option_button.clear()
	available_resolutions.clear()

	# Add common resolutions (customize this list)
	var common_resolutions = [
		Vector2i(800, 600),
		Vector2i(1024, 768),
		Vector2i(1280, 720), # 720p
		Vector2i(1366, 768),
		Vector2i(1600, 900),
		Vector2i(1920, 1080), # 1080p
		# Add monitor's native resolution if not already listed
		DisplayServer.screen_get_size()
	]

	# Remove duplicates and sort (optional)
	var unique_resolutions: Array[Vector2i] = []
	for res in common_resolutions:
		if not unique_resolutions.has(res) and res.x > 0 and res.y > 0:
			unique_resolutions.append(res)

	# Sort by width, then height
	unique_resolutions.sort_custom(func(a, b):
		if a.x != b.x: return a.x < b.x
		return a.y < b.y
		)

	available_resolutions = unique_resolutions

	# Add items to the OptionButton
	for res in available_resolutions:
		var res_string = "%d x %d" % [res.x, res.y]
		resolution_option_button.add_item(res_string)


# --- Signal Handlers ---

func _on_music_volume_slider_changed(value: float):
	if AudioManager:
		AudioManager.set_music_volume(value)

func _on_sfx_volume_slider_changed(value: float):
	if AudioManager:
		AudioManager.set_sfx_volume(value)

func _on_resolution_selected(index: int):
	if AudioManager and index >= 0 and index < available_resolutions.size():
		var selected_res = available_resolutions[index]
		AudioManager.set_resolution(selected_res)

func _on_fullscreen_toggled(button_pressed: bool):
	if AudioManager:
		AudioManager.set_fullscreen(button_pressed)


func _on_reset_data_button_pressed():
	# Optional: Add a confirmation dialog here
	print("Resetting data... (Note: Does not reset audio/display settings currently)")
	# If you had a separate DataManager, you would call its reset function here.
	# For now, this button doesn't affect the AudioManager settings.
	# Reload UI only if needed to reflect other non-AudioManager defaults
	#_ready()


func _on_back_button_pressed():
	# Settings are saved automatically by AudioManager when changed
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
