# scenes/achievements_menu.gd
extends Control

# TextureRect node references - ENSURE THESE PATHS ARE CORRECT
@onready var ach_pong_colours_texture = $AchievementsLayout/WholeContainer/RightColumnContainer/Ach_PongColours_Texture
@onready var ach_pong_god_texture = $AchievementsLayout/WholeContainer/LeftColumnContianer/Ach_PongGod_Texture
@onready var ach_ponging_out_texture = $AchievementsLayout/WholeContainer/LeftColumnContianer/Ach_PongingOut_Texture
@onready var ach_pong_slay_texture = $AchievementsLayout/WholeContainer/RightColumnContainer/Ach_PongSlay_Texture
@onready var ach_two_of_a_kind_texture = $AchievementsLayout/WholeContainer/LeftColumnContianer/Ach_Pong_TwoOfAKind
@onready var ach_gaming_trifecta_texture = $AchievementsLayout/WholeContainer/LeftColumnContianer/Ach_GamingTrifecta_Texture
@onready var ach_pong_chameleon_texture = $AchievementsLayout/WholeContainer/RightColumnContainer/Ach_PongChameleon_Texture
@onready var ach_gay_chameleon_texture = $AchievementsLayout/WholeContainer/RightColumnContainer/Ach_GayChameleon_Texture

# scenes/achievements_menu.gd
var achievement_textures: Dictionary

func _ready():
	print("AchievementsMenu: _ready() called.")
	achievement_textures = {
		"PONG GOD": ach_pong_god_texture,
		"PONGING OUT": ach_ponging_out_texture,
		"TWO OF A KIND": ach_two_of_a_kind_texture,
		"GAMING TRIFECTA": ach_gaming_trifecta_texture,
		"PONG SLAY": ach_pong_slay_texture,
		"PONG CHAMELEON": ach_pong_chameleon_texture,
		"GAY CHAMELEON": ach_gay_chameleon_texture,
		"PONG COLOURS": ach_pong_colours_texture,
	}
	print("AchievementsMenu: achievement_textures populated in _ready(). Size:", achievement_textures.size())

	# --- Set Tooltips with Line Breaks (\n) ---
	ach_pong_god_texture.tooltip_text = "You are the God of Pong\nScore one point"
	ach_ponging_out_texture.tooltip_text = "Oopsies\nLet the AI score 10 points total"
	ach_two_of_a_kind_texture.tooltip_text = "Twinsies\nGet the same paddle as the AI"
	ach_gaming_trifecta_texture.tooltip_text = "1337\nUse the classic R, G, B paddles at least once"
	ach_pong_slay_texture.tooltip_text = "Werk\nUse every single pride flag paddle"
	ach_pong_chameleon_texture.tooltip_text = "Colour me impressed\nPlay as all the solid colour paddles"
	ach_gay_chameleon_texture.tooltip_text = "Taste the rainbow\nUse all the pride AND colour paddles"
	ach_pong_colours_texture.tooltip_text = "The gayest one to rule them all\nUnlock everything else to snatch this crown"
	# --- End of Tooltip Setting ---

	update_achievement_display()
	print("AchievementsMenu: _ready() finished.")

func update_achievement_display():
	# ... (rest of the function is unchanged) ...
	print("--- AchievementsMenu: update_achievement_display() CALLED ---")
	if not DataManager:
		printerr("Achievements Menu: DataManager not found!")
		for node in achievement_textures.values():
			if is_instance_valid(node): node.visible = false
		return
	if not achievement_textures is Dictionary or achievement_textures.is_empty():
		printerr("Achievements Menu: ERROR - achievement_textures dictionary is invalid or empty when update called!")
		return
	if not DataManager.achievements_unlocked is Dictionary:
		printerr("Achievements Menu: DataManager.achievements_unlocked is not a Dictionary!")
		return
	print("  DataManager.achievements_unlocked state BEFORE loop: ", DataManager.achievements_unlocked)
	print("  achievement_textures size BEFORE loop: ", achievement_textures.size())
	for ach_name in achievement_textures:
		if not achievement_textures.has(ach_name):
			printerr("Achievements Menu: Key '", ach_name, "' missing from achievement_textures during loop.")
			continue
		var texture_rect = achievement_textures[ach_name]
		if not is_instance_valid(texture_rect):
			printerr("!!! Achievements Menu: CRITICAL ERROR - Invalid TextureRect node for achievement key '", ach_name, "'. Check @onready path !!!")
			continue
		var is_unlocked: bool = DataManager.is_achievement_unlocked(ach_name)
		print("    Processing '", ach_name, "' -> is_unlocked = ", is_unlocked) # Combined prints
		texture_rect.visible = true
		if is_unlocked:
			# print("        Applying WHITE modulate.")
			texture_rect.modulate = Color.WHITE
		else:
			# print("        Applying GREY modulate.") # Optional
			texture_rect.modulate = Color(0.3, 0.3, 0.3, 0.7)
	print("--- AchievementsMenu: update_achievement_display() FINISHED ---")
# ... (rest of the function is unchanged) ...


func _on_back_button_pressed():
	# --- NEW: Play Button Click Sound ---
	if AudioManager: AudioManager.play_sfx("ButtonClick")
	# --- END NEW ---
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
