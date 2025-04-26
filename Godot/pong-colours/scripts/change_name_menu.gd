# scenes/change_name_menu.gd
extends Control

# Adjust paths if your scene layout differs
@onready var name_line_edit = $NameLayout/NameLineEdit
@onready var feedback_label = $NameLayout/FeedbackLabel # Optional: Add a label for feedback

func _ready():
	# Load current name into the box when menu opens
	if DataManager:
		name_line_edit.text = DataManager.get_player_name()
	else:
		printerr("Change Name Menu: DataManager not found!")
		name_line_edit.placeholder_text = "Error loading name"

	# Clear feedback label if it exists
	if is_instance_valid(feedback_label):
		feedback_label.text = ""


func _on_save_button_pressed():
	if not DataManager:
		printerr("Change Name Menu: DataManager not found! Cannot save.")
		if is_instance_valid(feedback_label): feedback_label.text = "Error: Cannot save."
		return

	var new_name = name_line_edit.text.strip_edges() # Remove leading/trailing whitespace
	if new_name.is_empty():
		if is_instance_valid(feedback_label): feedback_label.text = "Name cannot be empty!"
		name_line_edit.grab_focus()
		return

	# Check if name actually changed
	if new_name == DataManager.get_player_name():
		if is_instance_valid(feedback_label): feedback_label.text = "Name unchanged."
		# Still go back even if unchanged
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	print("Saving new name: ", new_name)
	DataManager.set_player_name(new_name)
	DataManager.save_data() # Save the updated data

	if is_instance_valid(feedback_label): feedback_label.text = "Name Saved!"

	# Go back to main menu
	# Optional delay: await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
