# scenes/options_menu.gd
extends Control

# Adjust paths as needed
@onready var music_volume_slider = $OptionsLayout/HBoxContainer2/MusicVolumeSlider
@onready var sfx_volume_slider = $OptionsLayout/HBoxContainer3/SfxVolumeSlider
@onready var resolution_option_button = $OptionsLayout/HBoxContainer4/ResolutionOptionButton
@onready var fullscreen_checkbox = $OptionsLayout/HBoxContainer5/FullscreenCheckBox
@onready var point_limit_spinbox = $OptionsLayout/HBoxContainer/PointLimitSpinBox # Adjust path to your HBox

var available_resolutions: Array[Vector2i] = []

func _ready():
	# Connect signals, check node validity first
	if is_instance_valid(music_volume_slider): music_volume_slider.value_changed.connect(_on_music_volume_slider_changed)
	else: printerr("Options: MusicVolumeSlider not found.")
	if is_instance_valid(sfx_volume_slider): sfx_volume_slider.value_changed.connect(_on_sfx_volume_slider_changed)
	else: printerr("Options: SfxVolumeSlider not found.")
	if is_instance_valid(resolution_option_button): resolution_option_button.item_selected.connect(_on_resolution_selected)
	else: printerr("Options: ResolutionOptionButton not found.")
	if is_instance_valid(fullscreen_checkbox): fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	else: printerr("Options: FullscreenCheckBox not found.")
	if is_instance_valid(point_limit_spinbox): point_limit_spinbox.value_changed.connect(_on_point_limit_spinbox_changed) # Connect SpinBox
	else: printerr("Options: PointLimitSpinBox not found.")

	_populate_resolution_options()
	_load_settings_to_ui()

func _load_settings_to_ui():
	if DataManager and AudioManager: # Check both exist
		# Load Audio/Display from AudioManager
		if is_instance_valid(music_volume_slider): music_volume_slider.value = db_to_linear(AudioManager.music_volume_db)
		if is_instance_valid(sfx_volume_slider): sfx_volume_slider.value = db_to_linear(AudioManager.sfx_volume_db)
		if is_instance_valid(resolution_option_button):
			var current_res = AudioManager.current_resolution; var selected_index = -1
			for i in available_resolutions.size(): if available_resolutions[i] == current_res: selected_index = i; break
			if selected_index != -1: resolution_option_button.select(selected_index)
			else:
				var res_string = "%d x %d" % [current_res.x, current_res.y]; var found = false
				for i in resolution_option_button.item_count: if resolution_option_button.get_item_text(i) == res_string: found = true; selected_index = i; break
				if not found:
					resolution_option_button.add_item(res_string)
					if not available_resolutions.has(current_res): available_resolutions.append(current_res)
					selected_index = resolution_option_button.item_count - 1
				if selected_index != -1: resolution_option_button.select(selected_index)
		if is_instance_valid(fullscreen_checkbox): fullscreen_checkbox.button_pressed = AudioManager.current_fullscreen_mode

		# Load Point Limit from DataManager
		if is_instance_valid(point_limit_spinbox):
			point_limit_spinbox.value = DataManager.get_point_limit()

	else:
		printerr("Options Menu: DataManager or AudioManager not found!")


func _populate_resolution_options():
	if not is_instance_valid(resolution_option_button): return
	resolution_option_button.clear(); available_resolutions.clear()
	var common = [ Vector2i(800,600),Vector2i(1024,768),Vector2i(1280,720),Vector2i(1366,768),Vector2i(1600,900),Vector2i(1920,1080),DisplayServer.screen_get_size() ]
	var unique: Array[Vector2i] = []; for res in common: if res.x > 0 and res.y > 0 and not unique.has(res): unique.append(res)
	unique.sort_custom(func(a,b): if a.x!=b.x: return a.x<b.x; return a.y<b.y); available_resolutions=unique
	for res in available_resolutions: resolution_option_button.add_item("%dx%d" % [res.x,res.y])


# --- Signal Handlers ---
func _on_music_volume_slider_changed(value: float):
	if AudioManager: AudioManager.set_music_volume(value)

func _on_sfx_volume_slider_changed(value: float):
	if AudioManager: AudioManager.set_sfx_volume(value)

func _on_resolution_selected(index: int):
	if AudioManager and index >= 0 and index < available_resolutions.size():
		AudioManager.set_resolution(available_resolutions[index])

func _on_fullscreen_toggled(button_pressed: bool):
	if AudioManager: AudioManager.set_fullscreen(button_pressed)

# --- Added handler for Point Limit ---
func _on_point_limit_spinbox_changed(value: float): # SpinBox often emits float
	if DataManager:
		DataManager.set_point_limit(int(value)) # Convert to int before setting


# --- Reset Data ---
func _on_reset_data_button_pressed():
	print("Reset Data button pressed.")
	if DataManager:
		DataManager.reset_data()
		# Reload UI to show defaults (includes point limit now)
		_load_settings_to_ui()
		print("Options UI reloaded after data reset.")
	else:
		printerr("Options Menu: DataManager not found! Cannot reset data.")


func _on_back_button_pressed():
	# Settings are saved automatically when changed
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
