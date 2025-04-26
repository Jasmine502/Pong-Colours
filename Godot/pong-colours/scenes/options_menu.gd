# scenes/options_menu.gd
extends Control

@onready var point_limit_spinbox = $OptionsLayout/HBoxContainer/PointLimitSpinBox
@onready var light_mode_checkbox = $OptionsLayout/LightModeCheckBox

func _on_reset_data_button_pressed():
	# Optional: Add a confirmation dialog here
	print("Resetting data...")
	# Reload UI to reflect defaults
	_ready()

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
