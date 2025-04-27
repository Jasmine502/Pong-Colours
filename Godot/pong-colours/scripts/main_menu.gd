# scenes/main_menu.gd
extends Control

func _ready():
	pass

func _on_play_button_pressed():
	if AudioManager: AudioManager.play_sfx("ButtonClick") # Play Sound
	print("Play button pressed - changing to game scene")
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_change_name_button_pressed():
	if AudioManager: AudioManager.play_sfx("ButtonClick") # Play Sound
	print("Change Name button pressed - changing to change name scene")
	get_tree().change_scene_to_file("res://scenes/change_name_menu.tscn")

func _on_options_button_pressed():
	if AudioManager: AudioManager.play_sfx("ButtonClick") # Play Sound
	print("Options button pressed - changing to options scene")
	get_tree().change_scene_to_file("res://scenes/options_menu.tscn")

func _on_achievements_button_pressed():
	if AudioManager: AudioManager.play_sfx("ButtonClick") # Play Sound
	print("Achievements button pressed - changing to achievements scene")
	get_tree().change_scene_to_file("res://scenes/achievements_menu.tscn")

func _on_quit_button_pressed():
	if AudioManager: AudioManager.play_sfx("ButtonClick") # Play Sound
	print("Quit button pressed - attempting to save data before exiting.")
	if DataManager: DataManager.save_data()
	else: printerr("MainMenu: DataManager not found on quit, cannot save.")
	print("MainMenu: Exiting game.")
	get_tree().quit()
