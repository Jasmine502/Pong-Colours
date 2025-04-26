# scenes/achievements_menu.gd
extends Control

# Add @onready variables for each achievement TextureRect
@onready var ach_pong_colours_texture = $AchievementsLayout/HBoxContainer4/Ach_PongColours_Texture
@onready var ach_pong_god_texture = $AchievementsLayout/HBoxContainer/Ach_PongGod_Texture
@onready var ach_ponging_out_texture = $AchievementsLayout/HBoxContainer2/Ach_PongingOut_Texture
@onready var ach_pong_slay_texture = $AchievementsLayout/HBoxContainer/Ach_PongSlay_Texture
@onready var ach_two_of_a_kind_texture = $AchievementsLayout/HBoxContainer3/Ach_Pong_TwoOfAKind
@onready var ach_gaming_trifecta_texture = $AchievementsLayout/HBoxContainer4/Ach_GamingTrifecta_Texture
@onready var ach_pong_chameleon_texture = $AchievementsLayout/HBoxContainer2/Ach_PongChameleon_Texture
@onready var ach_gay_chameleon_texture = $AchievementsLayout/HBoxContainer3/Ach_GayChameleon_Texture

# Create a dictionary mapping achievement names (from DataManager) to their TextureRect nodes
var achievement_textures: Dictionary

func _ready():
	# Populate the dictionary
	achievement_textures = {
		"PONG COLOURS": ach_pong_colours_texture,
		"PONG GOD": ach_pong_god_texture,
		"PONGING OUT": ach_ponging_out_texture,
		"PONG SLAY": ach_pong_slay_texture,
		"TWO OF A KIND": ach_two_of_a_kind_texture,
		"GAMING TRIFECTA": ach_gaming_trifecta_texture,
		"PONG CHAMELEON": ach_pong_chameleon_texture,
		"GAY CHAMELEON": ach_gay_chameleon_texture
	}

	update_achievement_display()

func update_achievement_display():

	for ach_name in achievement_textures:
		var texture_rect = achievement_textures[ach_name]
		texture_rect.visible = true # Or false if you prefer to hide them
		# Make it look locked (e.g., greyscale)
		texture_rect.modulate = Color(0.3, 0.3, 0.3, 0.7) # Dim and slightly transparent gray


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
