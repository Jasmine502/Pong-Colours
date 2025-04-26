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

var background_material: ShaderMaterial

# --- Preloads ---
const PADDLE_HIT_PARTICLES = preload("res://scenes/effects/paddle_hit_particles.tscn")

# --- Game Settings ---
var point_limit = 5
var player_score = 0
var ai_score = 0
const DEFAULT_PLAYER_NAME = "Player"

# --- Fixed Paddle Positions ---
const PLAYER_PADDLE_X: float = 50.0
const AI_PADDLE_X_OFFSET: float = 50.0 # Offset from right edge

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
			printerr("Game: Failed to get valid screen size after waiting. Using fallback.")
			screen_size = Vector2(1152, 648)

	ai_target_y = screen_size.y / 2.0

	# Get shader material
	if is_instance_valid(background_shader_rect):
		if background_shader_rect.material is ShaderMaterial:
			background_material = background_shader_rect.material as ShaderMaterial
			print("Game: Found Background ShaderMaterial.")
		else:
			printerr("Game: BackgroundShaderRect found, but its Material is not a ShaderMaterial!")
			background_material = null
	else:
		printerr("Game: BackgroundShaderRect node NOT found!")
		background_material = null

	# Connect signals
	if is_instance_valid(menu_button):
		menu_button.pressed.connect(_on_menu_button_pressed)
	else: printerr("Game: MenuButton node NOT found.")

	# Letter colors setup... (same as before)
	LETTER_COLORS = { "A": Color.html("#F2A2B1"), "B": Color.html("#0000FF"), "C": Color.html("#00FFFF"), "D": Color.html("#FDDA0D"), "E": Color.html("#A7C9A7"), "F": Color.html("#FF00FF"), "G": Color.html("#008000"), "H": Color.html("#3FFF00"), "I": Color.html("#4B0082"), "J": Color.html("#00A86B"), "K": Color.html("#C3B091"), "L": Color.html("#FFFACD"), "M": Color.html("#FF00FF"), "N": Color.html("#39FF14"), "O": Color.html("#FFA500"), "P": Color.html("#800080"), "Q": Color.html("#D4C4AE"), "R": Color.html("#FF0000"), "S": Color.html("#FF2400"), "T": Color.html("#F94C00"), "U": Color.html("#8878C3"), "V": Color.html("#EE82EE"), "W": Color.html("#F5DEB3"), "X": Color.html("#66BFBF"), "Y": Color.html("#FFFF00"), "Z": Color.html("#3E646C"), "DEFAULT": Color.WHITE }

	# Load/Apply textures... (same as before)
	_set_player_name_color(DEFAULT_PLAYER_NAME)
	print("Game: Using default settings (Point Limit:", point_limit, ")")
	player_paddle_texture_path = _load_random_texture_from_folders(["res://assets/paddles/colours/", "res://assets/paddles/memes/", "res://assets/paddles/pride/"])
	ai_paddle_texture_path = _load_random_texture_from_folders(["res://assets/paddles/colours/", "res://assets/paddles/memes/", "res://assets/paddles/pride/"])
	ball_texture_path = _load_random_texture_from_folders(["res://assets/balls/colours/", "res://assets/balls/pride/"])
	var player_tex = load(player_paddle_texture_path) if not player_paddle_texture_path.is_empty() else null
	if player_tex and player_paddle.has_node("Sprite"): player_paddle.get_node("Sprite").texture = player_tex
	elif not player_tex: printerr("Failed to load player paddle texture: ", player_paddle_texture_path)
	else: printerr("Player paddle does not have a Sprite child node.")
	var ai_tex = load(ai_paddle_texture_path) if not ai_paddle_texture_path.is_empty() else null
	if ai_tex and ai_paddle.has_node("Sprite"): ai_paddle.get_node("Sprite").texture = ai_tex
	elif not ai_tex: printerr("Failed to load AI paddle texture: ", ai_paddle_texture_path)
	else: printerr("AI paddle does not have a Sprite child node.")
	var ball_tex = load(ball_texture_path) if not ball_texture_path.is_empty() else null
	if ball_tex and ball.has_node("Sprite"): ball.get_node("Sprite").texture = ball_tex
	elif not ball_tex: printerr("Failed to load ball texture: ", ball_texture_path)
	else: printerr("Ball does not have a Sprite child node.")

	# --- Set Initial Paddle Positions using Constants ---
	player_paddle.global_position = Vector2(PLAYER_PADDLE_X, screen_size.y / 2.0)
	ai_paddle.global_position = Vector2(screen_size.x - AI_PADDLE_X_OFFSET, screen_size.y / 2.0)

	_reset_ball()
	print("Game: _ready() FINISHED")


func _physics_process(delta):
	if game_over_flag: return

	if player_score >= point_limit or ai_score >= point_limit:
		if not game_over_flag: _game_over()
		return

	# --- Handle Movement ---
	_handle_player_input(delta)
	_handle_ai_movement(delta)

	# --- Force Paddle X Positions ---
	# Do this *after* move_and_slide has potentially slightly shifted them
	if is_instance_valid(player_paddle):
		player_paddle.global_position.x = PLAYER_PADDLE_X
	if is_instance_valid(ai_paddle) and screen_size.x > 0: # Check screen_size too
		ai_paddle.global_position.x = screen_size.x - AI_PADDLE_X_OFFSET

	# --- Handle Ball ---
	_handle_ball_movement(delta) # Ball moves *after* paddles are locked in X

	# --- Update Shader ---
	if is_instance_valid(background_material) and screen_size != Vector2.ZERO:
		var normalized_ball_pos = ball.global_position / screen_size
		background_material.set_shader_parameter("ball_position_normalized", normalized_ball_pos)

# --- Menu Button Handler (same) ---
func _on_menu_button_pressed():
	print("Game: Menu button pressed, returning to main menu.")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# --- Player Name Coloring (same) ---
func _set_player_name_color(player_name_text: String):
	# ... (code is unchanged) ...
	var bbcode_text = "[center]"
	for letter in player_name_text:
		var color = get_color_for_letter(letter)
		bbcode_text += "[color=" + color.to_html(false) + "]" + letter + "[/color]"
	bbcode_text += "[/center]"
	if player_name_label: player_name_label.text = bbcode_text

func get_color_for_letter(letter: String) -> Color:
	# ... (code is unchanged) ...
	var upper_letter = letter.to_upper()
	if LETTER_COLORS.has(upper_letter): return LETTER_COLORS[upper_letter]
	elif LETTER_COLORS.has("DEFAULT"): return LETTER_COLORS["DEFAULT"]
	else: return Color.WHITE

# --- Texture Loading (same) ---
func _load_random_texture_from_folders(folder_paths: Array[String]) -> String:
	# ... (code is unchanged) ...
	var all_files: Array[String] = []
	for folder_path in folder_paths:
		var dir = DirAccess.open(folder_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and (file_name.ends_with(".png") or file_name.ends_with(".PNG")):
					all_files.append(folder_path.path_join(file_name))
				file_name = dir.get_next()
		else:
			printerr("Could not open directory: ", folder_path)
	if all_files.is_empty():
		printerr("No PNG textures found in folders: ", folder_paths)
		return ""
	else:
		return all_files.pick_random()


# --- Player Movement (no changes needed here) ---
func _handle_player_input(delta):
	var direction = Input.get_axis("move_up", "move_down")
	var target_velocity_y: float = direction * PADDLE_SPEED
	var lerp_weight: float = 1.0 - exp(-delta * PADDLE_SMOOTHING)
	player_paddle.velocity.y = lerp(player_paddle.velocity.y, target_velocity_y, lerp_weight)
	player_paddle.move_and_slide() # Move based on velocity
	# X position will be forced back in _physics_process
	# Clamp Y position
	var player_sprite = player_paddle.get_node_or_null("Sprite") as Sprite2D
	if player_sprite and player_sprite.texture:
		var half_height = player_sprite.get_rect().size.y / 2.0 * player_paddle.scale.y
		player_paddle.global_position.y = clamp(player_paddle.global_position.y, half_height, screen_size.y - half_height)

# --- AI Movement (no changes needed here) ---
func _handle_ai_movement(delta):
	if not is_instance_valid(ball) or not is_instance_valid(ai_paddle): return

	var distance_to_ball: float = abs(ball.global_position.x - ai_paddle.global_position.x)
	var current_y: float = ai_paddle.global_position.y

	var predicted_ball_y: float = ball.global_position.y
	if screen_size.x != 0.0:
		var prediction_offset = ball.velocity.y * AI_PREDICTION_FACTOR * (distance_to_ball / screen_size.x)
		predicted_ball_y = ball.global_position.y + prediction_offset
	else: pass

	predicted_ball_y = clamp(predicted_ball_y, 0.0, screen_size.y)

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

	ai_paddle.move_and_slide() # Move based on velocity
	# X position will be forced back in _physics_process
	# Clamp Y position
	var ai_sprite = ai_paddle.get_node_or_null("Sprite") as Sprite2D
	if ai_sprite and ai_sprite.texture:
		var half_height: float = ai_sprite.get_rect().size.y / 2.0 * ai_paddle.scale.y
		ai_paddle.global_position.y = clamp(ai_paddle.global_position.y, half_height, screen_size.y - half_height)

# --- Ball Movement & Collision (Edge hit logic remains, but might be less critical now) ---
func _handle_ball_movement(delta):
	if not is_instance_valid(ball): return

	ball.velocity = ball_velocity.normalized() * ball_speed
	var collision_info = ball.move_and_collide(ball.velocity * delta)

	if collision_info:
		var normal: Vector2 = collision_info.get_normal()
		var collider = collision_info.get_collider()
		var collision_pos: Vector2 = collision_info.get_position()

		if collider == player_paddle or collider == ai_paddle:
			# Paddle Collision
			if is_instance_valid(collider): _emit_collision_particles(collider, collision_pos, normal)
			else: printerr("Collider instance invalid...")

			var bounced_velocity: Vector2 = ball_velocity.bounce(normal)
			var is_face_hit: bool = abs(normal.x) > FACE_HIT_NORMAL_THRESHOLD
			var is_edge_hit: bool = abs(normal.y) > EDGE_HIT_NORMAL_THRESHOLD and not is_face_hit

			if is_face_hit:
				ball_speed += BALL_SPEED_INCREASE
				var paddle_shape_node = collider.get_node_or_null("CollisionShape2D")
				if paddle_shape_node and paddle_shape_node.shape is RectangleShape2D:
					var paddle_height: float = paddle_shape_node.shape.size.y * collider.scale.y
					if paddle_height != 0.0:
						var hit_pos_relative: float = clampf((ball.global_position.y - collider.global_position.y) / (paddle_height / 2.0), -1.0, 1.0)
						var influence: float = 0.6
						var adjustment_angle_rad: float = PI * influence * -hit_pos_relative / 2.0
						var new_angle: float = bounced_velocity.angle() + adjustment_angle_rad
						var max_angle_deviation: float = deg_to_rad(70.0)
						if bounced_velocity.x > 0.0: new_angle = clampf(new_angle, -max_angle_deviation, max_angle_deviation)
						else:
							if not (new_angle >= -PI + max_angle_deviation and new_angle <= PI - max_angle_deviation):
								new_angle = sign(new_angle) * (PI - max_angle_deviation)
						ball_velocity = Vector2.from_angle(new_angle).normalized() * ball_speed
					else: ball_velocity = bounced_velocity.normalized() * ball_speed
				else: ball_velocity = bounced_velocity.normalized() * ball_speed
			elif is_edge_hit:
				# Edge Hit Logic (Still useful for bounce feel, less critical for sticking now)
				var push_direction: float = 1.0 if collider == player_paddle else -1.0
				ball_velocity.x = push_direction * EDGE_HIT_SET_HORIZONTAL_SPEED
				ball_velocity.y = bounced_velocity.y * EDGE_HIT_VERTICAL_DAMPEN
				print("Edge hit velocity. New vel:", ball_velocity)
			else:
				ball_velocity = bounced_velocity # Corner hit

			# Separation push remains important
			ball.global_position += normal * COLLISION_SEPARATION_MULTIPLIER

		else: # Wall Collision
			ball_velocity = ball_velocity.bounce(normal)

	# Screen Boundary Checks (same)
	var ball_sprite = ball.get_node_or_null("Sprite") as Sprite2D
	if ball_sprite and ball_sprite.texture:
		var ball_half_height: float = ball_sprite.get_rect().size.y / 2.0 * ball.scale.y
		if ball.global_position.y <= ball_half_height and ball_velocity.y < 0.0:
			ball_velocity.y *= -1.0; ball.global_position.y = ball_half_height + 0.1
		if ball.global_position.y >= screen_size.y - ball_half_height and ball_velocity.y > 0.0:
			ball_velocity.y *= -1.0; ball.global_position.y = screen_size.y - ball_half_height - 0.1

	# Scoring Checks (same)
	var ball_half_width: float = 10.0
	if ball_sprite and ball_sprite.texture: ball_half_width = ball_sprite.get_rect().size.x / 2.0 * ball.scale.x
	if ball.global_position.x > screen_size.x + ball_half_width:
		player_score += 1; _update_score_labels()
		if player_score < point_limit and ai_score < point_limit: _reset_ball(false)
		elif not game_over_flag: _game_over()
	elif ball.global_position.x < -ball_half_width:
		ai_score += 1; _update_score_labels()
		if player_score < point_limit and ai_score < point_limit: _reset_ball(true)
		elif not game_over_flag: _game_over()

# --- Particle Helper Function (same) ---
func _emit_collision_particles(paddle_collider: Node, collision_position: Vector2, _normal: Vector2):
	# ... (code is unchanged) ...
	if PADDLE_HIT_PARTICLES:
		var particles_instance = PADDLE_HIT_PARTICLES.instantiate()
		if not particles_instance is GPUParticles2D:
			printerr("Instantiated particle scene is not GPUParticles2D!")
			if is_instance_valid(particles_instance): particles_instance.queue_free()
			return

		var particles = particles_instance as GPUParticles2D
		add_child(particles)
		particles.global_position = collision_position

		var paddle_color = Color.WHITE
		var sprite = paddle_collider.get_node_or_null("Sprite") as Sprite2D
		if sprite and sprite.texture:
			var img = sprite.texture.get_image()
			if img:
				if img.is_compressed():
					if img.can_decompress():
						var decompress_err = img.decompress()
						if decompress_err != OK: img = null; printerr("Failed to decompress...")
					else: img = null; printerr("Cannot decompress...")

				if img:
					var width = img.get_width(); var height = img.get_height()
					if width > 0 and height > 0:
						paddle_color = img.get_pixel(width / 2, height / 2)
					else: printerr("Paddle texture image has zero dimensions.")
			else: printerr("Game: Could not get image data from paddle texture.")

		particles.modulate = paddle_color
		particles.emitting = true
		particles.finished.connect(particles.queue_free)
	else:
		printerr("Paddle hit particle scene not loaded correctly.")

# --- Reset Ball (same) ---
func _reset_ball(serve_to_player: bool = true):
	# ... (code is unchanged) ...
	if not is_instance_valid(ball): printerr("Reset Ball: Ball invalid!"); return
	ball.global_position = screen_size / 2.0
	ball_speed = BALL_INITIAL_SPEED
	ball_velocity = Vector2.ZERO
	if not is_instance_valid(self): return
	await get_tree().create_timer(0.1).timeout
	if game_over_flag or not is_instance_valid(self): return

	randomize()
	var initial_angle_deg: float = randf_range(15.0, 35.0)
	var angle_rad: float = deg_to_rad(initial_angle_deg)
	if randi() % 2 == 0: angle_rad *= -1.0
	var serve_direction: Vector2 = Vector2.RIGHT if serve_to_player else Vector2.LEFT
	ball_velocity = serve_direction.rotated(angle_rad) * ball_speed
	print("Ball reset. Serving to %s. Initial Velocity: %s" % ["Player" if serve_to_player else "AI", ball_velocity])

# --- Update Score Labels (same) ---
func _update_score_labels():
	# ... (code is unchanged) ...
	if is_instance_valid(player_score_label): player_score_label.text = str(player_score)
	if is_instance_valid(ai_score_label): ai_score_label.text = str(ai_score)

# --- Game Over (same) ---
func _game_over():
	# ... (code is unchanged) ...
	if game_over_flag: return
	game_over_flag = true
	print("Game Over sequence started!")
	ball_velocity = Vector2.ZERO
	if is_instance_valid(ball):
		ball.global_position = Vector2(-200, -200)

	if not is_instance_valid(self): return
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
