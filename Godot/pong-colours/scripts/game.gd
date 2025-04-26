# scenes/game.gd
extends Node2D

# --- Node References ---
@onready var background_shader_rect = $BackgroundShaderRect
@onready var player_paddle = $PlayerPaddle
@onready var ai_paddle = $AIPaddle
@onready var ball = $Ball
@onready var player_score_label = $PlayerScoreLabel
@onready var ai_score_label = $AIScoreLabel
@onready var player_name_label = $PlayerNameLabel
@onready var menu_button = $MenuButton
@onready var achievement_banner = $AchievementBanner
@onready var achievement_animator = $AchievementAnimator

var background_material: ShaderMaterial

# --- Preloads ---
const PADDLE_HIT_PARTICLES = preload("res://scenes/effects/paddle_hit_particles.tscn")

# --- Game Settings ---
var current_game_point_limit: int = 5
var player_score = 0
var ai_score = 0
const DEFAULT_PLAYER_NAME = "Player"

# --- Constants for Paddle Paths ---
const COLOUR_PADDLE_PATH = "res://assets/paddles/colours/"
const MEME_PADDLE_PATH = "res://assets/paddles/memes/"
const PRIDE_PADDLE_PATH = "res://assets/paddles/pride/"

# --- Fixed Paddle Positions ---
const PLAYER_PADDLE_X: float = 50.0
const AI_PADDLE_X_OFFSET: float = 50.0

# --- Movement & Physics ---
const PADDLE_SPEED = 500.0
const PADDLE_SMOOTHING = 8.0
const BALL_INITIAL_SPEED = 600.0
const BALL_SPEED_INCREASE = 100.0
var ball_speed = BALL_INITIAL_SPEED
var ball_velocity = Vector2.ZERO

# AI Tuning
const AI_SPEED_MODIFIER = 0.85
const AI_SMOOTHING = 6.0
const AI_REACTION_DISTANCE_THRESHOLD = 200
const AI_PREDICTION_FACTOR = 0.05
var ai_target_y: float = 0.0

# --- Screen Info ---
var screen_size: Vector2 = Vector2.ZERO

# --- Asset Paths ---
var player_paddle_texture_path: String = ""
var ai_paddle_texture_path: String = ""
var ball_texture_path: String = ""

# --- State ---
var game_over_flag = false

# --- Constants for Collision Logic ---
const FACE_HIT_NORMAL_THRESHOLD = 0.9
const EDGE_HIT_NORMAL_THRESHOLD = 0.7
const EDGE_HIT_SET_HORIZONTAL_SPEED = 400.0
const EDGE_HIT_VERTICAL_DAMPEN = 0.3
const COLLISION_SEPARATION_MULTIPLIER = 2.5

# --- Letter Colors Dictionary ---
var LETTER_COLORS: Dictionary = {}


func _ready():
	print("Game: _ready() START")
	screen_size = get_viewport_rect().size
	if screen_size == Vector2.ZERO:
		await get_tree().process_frame
		screen_size = get_viewport_rect().size
		if screen_size == Vector2.ZERO:
			printerr("Game: Failed to get valid screen size. Using fallback.")
			screen_size = Vector2(1152, 648)

	ai_target_y = screen_size.y / 2.0

	if DataManager:
		if DataManager.has_signal("achievement_unlocked"):
			DataManager.achievement_unlocked.connect(_on_data_manager_achievement_unlocked)
			print("Game: Connected to DataManager achievement signal.")
		else:
			printerr("Game: DataManager does not have the 'achievement_unlocked' signal!")
	else:
		printerr("Game: DataManager not found, cannot connect achievement signal.")

	if not is_instance_valid(achievement_banner): printerr("Game: AchievementBanner node NOT found!")
	if not is_instance_valid(achievement_animator): printerr("Game: AchievementAnimator node NOT found!")

	if is_instance_valid(background_shader_rect):
		if background_shader_rect.material is ShaderMaterial:
			background_material = background_shader_rect.material as ShaderMaterial
			print("Game: Found Background ShaderMaterial.")
		else:
			printerr("Game: BackgroundShaderRect Material is not ShaderMaterial!")
			background_material = null
	else:
		printerr("Game: BackgroundShaderRect node NOT found!")
		background_material = null

	if is_instance_valid(menu_button):
		menu_button.pressed.connect(_on_menu_button_pressed)
	else:
		printerr("Game: MenuButton node NOT found.")

	LETTER_COLORS = { "A": Color.html("#F2A2B1"),"B": Color.html("#0000FF"),"C": Color.html("#00FFFF"),"D": Color.html("#FDDA0D"),"E": Color.html("#A7C9A7"),"F": Color.html("#FF00FF"),"G": Color.html("#008000"),"H": Color.html("#3FFF00"),"I": Color.html("#4B0082"),"J": Color.html("#00A86B"),"K": Color.html("#C3B091"),"L": Color.html("#FFFACD"),"M": Color.html("#FF00FF"),"N": Color.html("#39FF14"),"O": Color.html("#FFA500"),"P": Color.html("#800080"),"Q": Color.html("#D4C4AE"),"R": Color.html("#FF0000"),"S": Color.html("#FF2400"),"T": Color.html("#F94C00"),"U": Color.html("#8878C3"),"V": Color.html("#EE82EE"),"W": Color.html("#F5DEB3"),"X": Color.html("#66BFBF"),"Y": Color.html("#FFFF00"),"Z": Color.html("#3E646C"),"DEFAULT": Color.WHITE }

	if DataManager:
		_set_player_name_color(DataManager.get_player_name())
		current_game_point_limit = DataManager.get_point_limit()
	else:
		printerr("Game: DataManager not found! Using defaults.")
		_set_player_name_color(DEFAULT_PLAYER_NAME)
		current_game_point_limit = 5

	print("Game: Point Limit for this match:", current_game_point_limit)

	player_paddle_texture_path = _load_random_texture_from_folders([COLOUR_PADDLE_PATH, MEME_PADDLE_PATH, PRIDE_PADDLE_PATH])
	ai_paddle_texture_path = _load_random_texture_from_folders([COLOUR_PADDLE_PATH, MEME_PADDLE_PATH, PRIDE_PADDLE_PATH])
	ball_texture_path = _load_random_texture_from_folders(["res://assets/balls/colours/", "res://assets/balls/pride/"])
	print("Game: Player Paddle:", player_paddle_texture_path.get_file())
	print("Game: AI Paddle:", ai_paddle_texture_path.get_file())
	var player_tex = load(player_paddle_texture_path) if not player_paddle_texture_path.is_empty() else null
	if player_tex and is_instance_valid(player_paddle) and player_paddle.has_node("Sprite"):
		player_paddle.get_node("Sprite").texture = player_tex
	else:
		printerr("Player paddle texture/sprite issue.")
	var ai_tex = load(ai_paddle_texture_path) if not ai_paddle_texture_path.is_empty() else null
	if ai_tex and is_instance_valid(ai_paddle) and ai_paddle.has_node("Sprite"):
		ai_paddle.get_node("Sprite").texture = ai_tex
	else:
		printerr("AI paddle texture/sprite issue.")
	var ball_tex = load(ball_texture_path) if not ball_texture_path.is_empty() else null
	if ball_tex and is_instance_valid(ball) and ball.has_node("Sprite"):
		ball.get_node("Sprite").texture = ball_tex
	else:
		printerr("Ball texture/sprite issue.")

	if DataManager:
		if not player_paddle_texture_path.is_empty() and player_paddle_texture_path == ai_paddle_texture_path:
			DataManager.unlock_achievement("TWO OF A KIND")
		if not player_paddle_texture_path.is_empty():
			DataManager.add_player_paddle_used(player_paddle_texture_path)

	if is_instance_valid(player_paddle):
		player_paddle.global_position = Vector2(PLAYER_PADDLE_X, screen_size.y / 2.0)
	if is_instance_valid(ai_paddle):
		ai_paddle.global_position = Vector2(screen_size.x - AI_PADDLE_X_OFFSET, screen_size.y / 2.0)

	_reset_ball()
	print("Game: _ready() FINISHED")


func _physics_process(delta):
	if game_over_flag:
		return
	if player_score >= current_game_point_limit or ai_score >= current_game_point_limit:
		if not game_over_flag:
			_game_over()
		return # Stop processing after game over is initiated

	_handle_player_input(delta)
	_handle_ai_movement(delta)

	if is_instance_valid(player_paddle):
		player_paddle.global_position.x = PLAYER_PADDLE_X
	if is_instance_valid(ai_paddle) and screen_size.x > 0:
		ai_paddle.global_position.x = screen_size.x - AI_PADDLE_X_OFFSET

	_handle_ball_movement(delta)

	if is_instance_valid(background_material) and screen_size != Vector2.ZERO:
		if is_instance_valid(ball):
			background_material.set_shader_parameter("ball_position_normalized", ball.global_position / screen_size)


func _on_data_manager_achievement_unlocked(achievement_name: String):
	print("Game received achievement unlock signal:", achievement_name)
	if not is_instance_valid(achievement_banner) or not is_instance_valid(achievement_animator):
		printerr("Cannot show achievement banner, nodes missing.")
		return
	var anim_name = "ShowBanner"
	if achievement_animator.is_playing() and achievement_animator.current_animation == anim_name:
		print("Banner animation '", anim_name,"' already playing, skipping.")
		return
	if achievement_banner is Label:
		(achievement_banner as Label).text = "[center]Achievement Unlocked!\n[b]" + achievement_name.capitalize() + "[/b][/center]"
	elif achievement_banner is TextureRect:
		pass # Optional: Load specific texture here

	if achievement_animator.has_animation(anim_name):
		print("Playing achievement animation:", anim_name)
		achievement_animator.play(anim_name)
	else:
		printerr("Achievement animation '", anim_name, "' not found in AchievementAnimator node!")


func _on_menu_button_pressed():
	print("Game: Menu button pressed.")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _set_player_name_color(player_name_text: String):
	var bbcode = "[center]"
	for letter in player_name_text:
		var color = get_color_for_letter(letter)
		bbcode += "[color=" + color.to_html(false) + "]" + letter + "[/color]"
	bbcode += "[/center]"
	if is_instance_valid(player_name_label):
		player_name_label.text = bbcode


func get_color_for_letter(letter: String) -> Color:
	var upper = letter.to_upper()
	if LETTER_COLORS.has(upper):
		return LETTER_COLORS[upper]
	elif LETTER_COLORS.has("DEFAULT"):
		return LETTER_COLORS["DEFAULT"]
	else:
		return Color.WHITE


func _load_random_texture_from_folders(folder_paths: Array[String]) -> String:
	var all_files: Array[String] = []
	for fp in folder_paths:
		var dir = DirAccess.open(fp)
		if dir:
			dir.list_dir_begin()
			var fn = dir.get_next()
			while fn != "":
				if not dir.current_is_dir() and (fn.ends_with(".png") or fn.ends_with(".PNG")):
					all_files.append(fp.path_join(fn))
				fn = dir.get_next()
		else:
			printerr("Could not open directory: ", fp)

	if all_files.is_empty():
		printerr("No PNGs in folders: ", folder_paths)
		return ""
	else:
		return all_files.pick_random()


func _handle_player_input(delta):
	if not is_instance_valid(player_paddle):
		return
	var direction = Input.get_axis("move_up", "move_down")
	var target_velocity_y: float = direction * PADDLE_SPEED
	var lerp_weight: float = 1.0 - exp(-delta * PADDLE_SMOOTHING)
	player_paddle.velocity.y = lerp(player_paddle.velocity.y, target_velocity_y, lerp_weight)
	player_paddle.move_and_slide()
	var player_sprite = player_paddle.get_node_or_null("Sprite") as Sprite2D
	if player_sprite and player_sprite.texture and screen_size.y > 0:
		var half_height = player_sprite.get_rect().size.y / 2.0 * player_paddle.scale.y
		player_paddle.global_position.y = clampf(player_paddle.global_position.y, half_height, screen_size.y - half_height)


func _handle_ai_movement(delta):
	if not is_instance_valid(ball) or not is_instance_valid(ai_paddle):
		return
	var distance_to_ball: float = abs(ball.global_position.x - ai_paddle.global_position.x)
	var current_y: float = ai_paddle.global_position.y
	var predicted_ball_y: float = ball.global_position.y
	if screen_size.x != 0.0:
		var prediction_offset = ball.velocity.y * AI_PREDICTION_FACTOR * (distance_to_ball / screen_size.x)
		predicted_ball_y = ball.global_position.y + prediction_offset
	if screen_size.y > 0:
		predicted_ball_y = clampf(predicted_ball_y, 0.0, screen_size.y)
	if distance_to_ball < AI_REACTION_DISTANCE_THRESHOLD:
		ai_target_y = predicted_ball_y
	else:
		ai_target_y = lerp(ai_target_y, float(predicted_ball_y), delta * 2.0)

	var direction: float = 0.0
	if abs(ai_target_y - current_y) > 5.0:
		direction = sign(ai_target_y - current_y)

	var target_velocity_y: float = direction * (PADDLE_SPEED * AI_SPEED_MODIFIER)
	var lerp_weight: float = 1.0 - exp(-delta * AI_SMOOTHING)
	ai_paddle.velocity.y = lerp(ai_paddle.velocity.y, target_velocity_y, lerp_weight)
	ai_paddle.move_and_slide()
	var ai_sprite = ai_paddle.get_node_or_null("Sprite") as Sprite2D
	if ai_sprite and ai_sprite.texture and screen_size.y > 0:
		var half_height: float = ai_sprite.get_rect().size.y / 2.0 * ai_paddle.scale.y
		ai_paddle.global_position.y = clampf(ai_paddle.global_position.y, half_height, screen_size.y - half_height)


func _handle_ball_movement(delta):
	if not is_instance_valid(ball):
		return
	ball.velocity = ball_velocity.normalized() * ball_speed
	var collision_info = ball.move_and_collide(ball.velocity * delta)
	if collision_info:
		var normal: Vector2 = collision_info.get_normal()
		var collider = collision_info.get_collider()
		var collision_pos: Vector2 = collision_info.get_position()

		if collider == player_paddle or collider == ai_paddle:
			if is_instance_valid(collider):
				_emit_collision_particles(collider, collision_pos, normal)
			var bounced_velocity: Vector2 = ball_velocity.bounce(normal)
			var is_face_hit: bool = abs(normal.x) > FACE_HIT_NORMAL_THRESHOLD
			var is_edge_hit: bool = abs(normal.y) > EDGE_HIT_NORMAL_THRESHOLD and not is_face_hit

			if is_face_hit:
				ball_speed += BALL_SPEED_INCREASE
				var shape_node = collider.get_node_or_null("CollisionShape2D")
				if shape_node and shape_node.shape is RectangleShape2D:
					var h: float = shape_node.shape.size.y * collider.scale.y
					if h != 0.0:
						var rel_y: float = clampf((ball.global_position.y - collider.global_position.y) / (h / 2.0), -1.0, 1.0)
						var influence: float = 0.6
						var adj_angle: float = PI * influence * -rel_y / 2.0
						var new_angle: float = bounced_velocity.angle() + adj_angle
						var max_dev: float = deg_to_rad(70.0)
						if bounced_velocity.x > 0.0:
							new_angle = clampf(new_angle, -max_dev, max_dev)
						else:
							if not (new_angle >= -PI + max_dev and new_angle <= PI - max_dev):
								new_angle = sign(new_angle) * (PI - max_dev)
						ball_velocity = Vector2.from_angle(new_angle).normalized() * ball_speed
					else:
						ball_velocity = bounced_velocity.normalized() * ball_speed
				else:
					ball_velocity = bounced_velocity.normalized() * ball_speed
			elif is_edge_hit: # Correct 'elif' placement
				var push_dir: float = 1.0 if collider == player_paddle else -1.0
				ball_velocity.x = push_dir * EDGE_HIT_SET_HORIZONTAL_SPEED
				ball_velocity.y = bounced_velocity.y * EDGE_HIT_VERTICAL_DAMPEN
			else: # Corner hit
				ball_velocity = bounced_velocity

			ball.global_position += normal * COLLISION_SEPARATION_MULTIPLIER
		else: # Wall or other object collision
			ball_velocity = ball_velocity.bounce(normal)

	# Screen boundary checks
	var ball_sprite = ball.get_node_or_null("Sprite") as Sprite2D
	if ball_sprite and ball_sprite.texture and screen_size.y > 0:
		var ball_hh: float = ball_sprite.get_rect().size.y / 2.0 * ball.scale.y
		if ball.global_position.y <= ball_hh and ball_velocity.y < 0.0:
			ball_velocity.y *= -1.0
			ball.global_position.y = ball_hh + 0.1
		if ball.global_position.y >= screen_size.y - ball_hh and ball_velocity.y > 0.0:
			ball_velocity.y *= -1.0
			ball.global_position.y = screen_size.y - ball_hh - 0.1

	# Scoring Checks
	var ball_hw: float = 10.0
	if ball_sprite and ball_sprite.texture:
		ball_hw = ball_sprite.get_rect().size.x / 2.0 * ball.scale.x
	var scored = false
	if not scored and screen_size.x > 0 and ball.global_position.x > screen_size.x + ball_hw:
		scored = true
		player_score += 1
		_update_score_labels()
		if DataManager:
			DataManager.unlock_achievement("PONG GOD")
		if player_score < current_game_point_limit and ai_score < current_game_point_limit:
			_reset_ball(false)
		elif not game_over_flag:
			_game_over()
	elif not scored and ball.global_position.x < -ball_hw:
		scored = true
		ai_score += 1
		_update_score_labels()
		if DataManager:
			DataManager.increment_conceded_points()
		if player_score < current_game_point_limit and ai_score < current_game_point_limit:
			_reset_ball(true)
		elif not game_over_flag:
			_game_over()


func _emit_collision_particles(paddle_collider: Node, collision_position: Vector2, _normal: Vector2):
	if PADDLE_HIT_PARTICLES:
		var p_inst = PADDLE_HIT_PARTICLES.instantiate()
		if not p_inst is GPUParticles2D:
			if is_instance_valid(p_inst): p_inst.queue_free()
			printerr("Particle scene wrong type!")
			return
		var particles = p_inst as GPUParticles2D
		add_child(particles)
		particles.global_position = collision_position
		var color = Color.WHITE
		var sprite = paddle_collider.get_node_or_null("Sprite") as Sprite2D
		if sprite and sprite.texture:
			var img = sprite.texture.get_image()
			if img:
				if img.is_compressed():
					if img.can_decompress():
						if img.decompress() != OK:
							img = null
					else:
						img = null # Cannot decompress
				if img: # Check if still valid
					var w = img.get_width()
					var h = img.get_height()
					if w > 0 and h > 0:
						color = img.get_pixel(w / 2, h / 2)
		particles.modulate = color
		particles.emitting = true
		particles.finished.connect(particles.queue_free)


func _reset_ball(serve_to_player: bool = true):
	if not is_instance_valid(ball):
		return
	ball.global_position = screen_size / 2.0
	ball_speed = BALL_INITIAL_SPEED
	ball_velocity = Vector2.ZERO
	if not is_instance_valid(self):
		return
	await get_tree().create_timer(0.1).timeout
	if game_over_flag or not is_instance_valid(self):
		return
	randomize()
	var angle_deg: float = randf_range(15.0, 35.0)
	var angle_rad: float = deg_to_rad(angle_deg)
	if randi() % 2 == 0:
		angle_rad *= -1.0
	var dir: Vector2 = Vector2.RIGHT if serve_to_player else Vector2.LEFT
	ball_velocity = dir.rotated(angle_rad) * ball_speed
	print("Ball reset. Serving %s. Vel: %s" % ["Player" if serve_to_player else "AI", ball_velocity])


func _update_score_labels():
	if is_instance_valid(player_score_label):
		player_score_label.text = str(player_score)
	if is_instance_valid(ai_score_label):
		ai_score_label.text = str(ai_score)


func _game_over():
	if game_over_flag:
		return
	game_over_flag = true
	print("Game Over!")
	ball_velocity = Vector2.ZERO
	if is_instance_valid(ball):
		ball.global_position = Vector2(-200, -200)
	if not is_instance_valid(self):
		return
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
