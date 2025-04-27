# scenes/change_name_menu.gd
extends Control

@onready var name_line_edit = $NameLayout/NameLineEdit
@onready var feedback_label = $NameLayout/FeedbackLabel

func _ready():
	if DataManager: name_line_edit.text = DataManager.get_player_name()
	else: printerr("Change Name Menu: DataManager not found!"); name_line_edit.placeholder_text = "Error loading name"
	if is_instance_valid(feedback_label): feedback_label.text = ""

func _on_save_button_pressed():
	# --- NEW: Play Button Click Sound ---
	if AudioManager: AudioManager.play_sfx("ButtonClick")
	# --- END NEW ---

	if not DataManager:
		printerr("Change Name Menu: DataManager not found! Cannot save.")
		if is_instance_valid(feedback_label): feedback_label.text = "Error: Cannot save."
		return

	var new_name = name_line_edit.text.strip_edges()
	if new_name.is_empty():
		if is_instance_valid(feedback_label): feedback_label.text = "Name cannot be empty!"
		name_line_edit.grab_focus(); return

	if new_name == DataManager.get_player_name():
		if is_instance_valid(feedback_label): feedback_label.text = "Name unchanged."
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"); return

	print("Saving new name: ", new_name)
	DataManager.set_player_name(new_name)
	DataManager.save_data()
	if is_instance_valid(feedback_label): feedback_label.text = "Name Saved!"
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_back_button_pressed():
	# --- NEW: Play Button Click Sound ---
	if AudioManager: AudioManager.play_sfx("ButtonClick")
	# --- END NEW ---
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
