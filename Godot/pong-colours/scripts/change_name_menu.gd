# scenes/change_name_menu.gd
extends Control

@onready var name_line_edit = $NameLayout/NameLineEdit

func _on_save_button_pressed():
	var new_name = name_line_edit.text.strip_edges() # Remove leading/trailing whitespace
	if new_name.is_empty():
		# Optional: Show an error message if name is empty
		print("Name cannot be empty!")
		name_line_edit.grab_focus() # Put cursor back in the box
		return

	print("Saving new name: ", new_name)
	# Optionally, provide feedback (e.g., change label text to "Saved!")
	# Go back to main menu after saving
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
