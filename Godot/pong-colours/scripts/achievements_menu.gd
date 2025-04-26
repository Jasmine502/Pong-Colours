# scenes/achievements_menu.gd
extends Control

# TextureRect node references - ENSURE THESE PATHS ARE CORRECT
@onready var ach_pong_colours_texture = $AchievementsLayout/HBoxContainer4/Ach_PongColours_Texture
@onready var ach_pong_god_texture = $AchievementsLayout/HBoxContainer/Ach_PongGod_Texture
@onready var ach_ponging_out_texture = $AchievementsLayout/HBoxContainer2/Ach_PongingOut_Texture
@onready var ach_pong_slay_texture = $AchievementsLayout/HBoxContainer/Ach_PongSlay_Texture
@onready var ach_two_of_a_kind_texture = $AchievementsLayout/HBoxContainer3/Ach_Pong_TwoOfAKind
@onready var ach_gaming_trifecta_texture = $AchievementsLayout/HBoxContainer4/Ach_GamingTrifecta_Texture
@onready var ach_pong_chameleon_texture = $AchievementsLayout/HBoxContainer2/Ach_PongChameleon_Texture # Added back
@onready var ach_gay_chameleon_texture = $AchievementsLayout/HBoxContainer3/Ach_GayChameleon_Texture

# Map internal achievement names (keys) to TextureRect nodes (values)
var achievement_textures: Dictionary

func _ready():
	# Populate the dictionary (use the EXACT names from DataManager keys)
	achievement_textures = {
		"PONG GOD": ach_pong_god_texture,
		"PONGING OUT": ach_ponging_out_texture,
		"TWO OF A KIND": ach_two_of_a_kind_texture,
		"GAMING TRIFECTA": ach_gaming_trifecta_texture,
		"PONG SLAY": ach_pong_slay_texture,
		"PONG CHAMELEON": ach_pong_chameleon_texture, # Added mapping
		"GAY CHAMELEON": ach_gay_chameleon_texture,
		"PONG COLOURS": ach_pong_colours_texture,
	}

	update_achievement_display()

func update_achievement_display():
	if not DataManager:
		printerr("Achievements Menu: DataManager not found!")
		for node in achievement_textures.values():
			if is_instance_valid(node): node.visible = false
		return

	for ach_name in achievement_textures:
		if not achievement_textures.has(ach_name):
			printerr("Achievements Menu: Achievement name '", ach_name, "' exists in loop but not dictionary keys?")
			continue

		var texture_rect = achievement_textures[ach_name]

		if not is_instance_valid(texture_rect):
			printerr("Achievements Menu: Invalid TextureRect node found for achievement key '", ach_name, "'. Check @onready paths and dictionary.")
			continue

		var is_unlocked = DataManager.is_achievement_unlocked(ach_name)
		texture_rect.visible = true

		if is_unlocked:
			texture_rect.modulate = Color.WHITE
		else:
			texture_rect.modulate = Color(0.3, 0.3, 0.3, 0.7)


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
