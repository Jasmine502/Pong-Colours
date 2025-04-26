# scenes/game.gd
extends Node2D

# --- Node References ---
@onready var player_paddle = $PlayerPaddle
@onready var ai_paddle = $AIPaddle
@onready var ball = $Ball
@onready var player_score_label = $PlayerScoreLabel
@onready var ai_score_label = $AIScoreLabel
@onready var player_name_label = $PlayerNameLabel

# --- Game Settings ---
var point_limit = 5 # Default point limit
var player_score = 0
var ai_score = 0
const DEFAULT_PLAYER_NAME = "Player" # Default name

# --- Movement Speeds ---
const PADDLE_SPEED = 400.0
const BALL_INITIAL_SPEED = 600.0 # Slightly adjusted
const BALL_SPEED_INCREASE = 150.0 # Slightly reduced increase
var ball_speed = BALL_INITIAL_SPEED
var ball_velocity = Vector2.ZERO

# --- Screen Info ---
var screen_size: Vector2

# --- Asset Paths ---
var player_paddle_texture_path: String = ""
var ai_paddle_texture_path: String = ""
var ball_texture_path: String = ""

# --- State ---
var game_over_flag = false # Flag to prevent multiple game over calls

# --- Letter Colors Dictionary ---
var LETTER_COLORS: Dictionary = {}


# Called when the node enters the scene tree for the first time.
func _ready():
	print("Game: _ready() START")

	# Initialize LETTER_COLORS dictionary
	LETTER_COLORS = {
		"A": Color.html("#F2A2B1"), "B": Color.html("#0000FF"),
		"C": Color.html("#00FFFF"), "D": Color.html("#FDDA0D"),
		"E": Color.html("#A7C9A7"), "F": Color.html("#FF00FF"),
		"G": Color.html("#008000"), "H": Color.html("#3FFF00"),
		"I": Color.html("#4B0082"), "J": Color.html("#00A86B"),
		"K": Color.html("#C3B091"), "L": Color.html("#FFFACD"),
		"M": Color.html("#FF00FF"), "N": Color.html("#39FF14"),
		"O": Color.html("#FFA500"), "P": Color.html("#800080"),
		"Q": Color.html("#D4C4AE"), "R": Color.html("#FF0000"),
		"S": Color.html("#FF2400"), "T": Color.html("#F94C00"),
		"U": Color.html("#8878C3"), "V": Color.html("#EE82EE"),
		"W": Color.html("#F5DEB3"), "X": Color.html("#66BFBF"),
		"Y": Color.html("#FFFF00"), "Z": Color.html("#3E646C"),
		"DEFAULT": Color.WHITE
	}
	print("Game: Letter colors initialized")

	screen_size = get_viewport_rect().size
	print("Game: Screen size obtained: ", screen_size)

	# Use default settings directly
	_set_player_name_color(DEFAULT_PLAYER_NAME) # Use default name
	print("Game: Using default settings (Point Limit:", point_limit, ")")

	# Randomize visuals
	player_paddle_texture_path = _load_random_texture_from_folders(["res://assets/paddles/colours/", "res://assets/paddles/memes/", "res://assets/paddles/pride/"])
	ai_paddle_texture_path = _load_random_texture_from_folders(["res://assets/paddles/colours/", "res://assets/paddles/memes/", "res://assets/paddles/pride/"])
	ball_texture_path = _load_random_texture_from_folders(["res://assets/balls/colours/", "res://assets/balls/pride/"])
	print("Game: Random textures selected")

	# Load textures
	var player_tex = load(player_paddle_texture_path) if not player_paddle_texture_path.is_empty() else null
	if player_tex: player_paddle.get_node("Sprite").texture = player_tex
	else: printerr("Failed to load player paddle texture: ", player_paddle_texture_path)

	var ai_tex = load(ai_paddle_texture_path) if not ai_paddle_texture_path.is_empty() else null
	if ai_tex: ai_paddle.get_node("Sprite").texture = ai_tex
	else: printerr("Failed to load AI paddle texture: ", ai_paddle_texture_path)

	var ball_tex = load(ball_texture_path) if not ball_texture_path.is_empty() else null
	if ball_tex: ball.get_node("Sprite").texture = ball_tex
	else: printerr("Failed to load ball texture: ", ball_texture_path)
	print("Game: Textures applied")

	# Position paddles
	player_paddle.global_position = Vector2(50, screen_size.y / 2)
	ai_paddle.global_position = Vector2(screen_size.x - 50, screen_size.y / 2)
	print("Game: Paddles positioned")

	# Reset ball
	_reset_ball()
	print("Game: Ball reset")

	print("Game: _ready() FINISHED")


func _physics_process(delta):
	# If game is over, stop processing movement
	if game_over_flag:
		return

	# Check if game should end *before* moving anything else this frame
	if player_score >= point_limit or ai_score >= point_limit:
		_game_over()
		return # Stop further processing this frame

	_handle_player_input(delta)
	_handle_ai_movement(delta)
	_handle_ball_movement(delta)


# --- Player Name Coloring ---
func _set_player_name_color(player_name_text: String):
	var bbcode_text = "[center]"
	for letter in player_name_text:
		var color = get_color_for_letter(letter)
		bbcode_text += "[color=" + color.to_html(false) + "]" + letter + "[/color]"
	bbcode_text += "[/center]"
	if player_name_label: player_name_label.text = bbcode_text


func get_color_for_letter(letter: String) -> Color:
	var upper_letter = letter.to_upper()
	if LETTER_COLORS.has(upper_letter): return LETTER_COLORS[upper_letter]
	elif LETTER_COLORS.has("DEFAULT"): return LETTER_COLORS["DEFAULT"]
	else: return Color.WHITE


# --- Texture Loading ---
func _load_random_texture_from_folders(folder_paths: Array[String]) -> String:
	var all_files: Array[String] = []
	for folder_path in folder_paths:
		var dir = DirAccess.open(folder_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".png"):
					all_files.append(folder_path + file_name)
				file_name = dir.get_next()
			# No need for dir.list_dir_end() in Godot 4+
		else:
			printerr("Could not open directory: ", folder_path)

	if all_files.is_empty():
		printerr("No PNG textures found in folders: ", folder_paths)
		return ""
	else:
		return all_files.pick_random()


# --- Movement Handling ---
func _handle_player_input(_delta):
	var direction = Input.get_axis("move_up", "move_down")
	player_paddle.velocity.y = direction * PADDLE_SPEED
	player_paddle.move_and_slide() # Use move_and_slide for kinematic bodies

	# Clamp position AFTER movement
	var player_sprite = player_paddle.get_node("Sprite") as Sprite2D
	if player_sprite:
		var half_height = player_sprite.get_rect().size.y / 2.0 * player_paddle.scale.y # Account for scale
		player_paddle.global_position.y = clamp(player_paddle.global_position.y, half_height, screen_size.y - half_height)


func _handle_ai_movement(_delta):
	var target_y = ball.global_position.y
	var current_y = ai_paddle.global_position.y
	var direction = 0.0

	# Add a small buffer to prevent jittering when ball is aligned
	if abs(target_y - current_y) > 5:
		direction = sign(target_y - current_y) # Simplified direction calculation

	# Apply AI speed modifier (e.g., 80% of player speed)
	ai_paddle.velocity.y = direction * (PADDLE_SPEED * 0.8)
	ai_paddle.move_and_slide() # Use move_and_slide

	# Clamp position AFTER movement
	var ai_sprite = ai_paddle.get_node("Sprite") as Sprite2D
	if ai_sprite:
		var half_height = ai_sprite.get_rect().size.y / 2.0 * ai_paddle.scale.y # Account for scale
		ai_paddle.global_position.y = clamp(ai_paddle.global_position.y, half_height, screen_size.y - half_height)


func _handle_ball_movement(delta):
	# Update velocity vector based on current speed
	ball.velocity = ball_velocity.normalized() * ball_speed
	var collision_info = ball.move_and_collide(ball.velocity * delta)

	if collision_info:
		var normal = collision_info.get_normal()
		var collider = collision_info.get_collider()

		# --- Paddle Collision Logic ---
		if collider == player_paddle or collider == ai_paddle:
			# 1. Basic Bounce Calculation
			ball_velocity = ball_velocity.bounce(normal)

			# 2. Angle Adjustment ONLY for Face Hits (Horizontal Normal)
			if abs(normal.x) > 0.9: # More strict check for face hit
				ball_speed += BALL_SPEED_INCREASE # Increase speed only on face hits

				var paddle_shape_node = collider.get_node_or_null("CollisionShape2D") # Adjust if name differs
				if paddle_shape_node and paddle_shape_node.shape is RectangleShape2D:
					var paddle_height = paddle_shape_node.shape.size.y * collider.scale.y # Use scaled height
					# Relative position: -1 (top) to +1 (bottom)
					var hit_pos_relative = clamp((ball.global_position.y - collider.global_position.y) / (paddle_height / 2.0), -1.0, 1.0)

					# Influence factor determines how much the hit position affects the angle
					var influence = 0.6 # Adjust this value (0.0 to 1.0 typically)
					# Calculate adjustment angle based on relative hit position (hitting lower makes it go up more, hence negative)
					var adjustment_angle_rad = PI * influence * -hit_pos_relative / 2.0 # Divide by 2 for less extreme angles

					# Apply the adjustment to the bounced angle
					var new_angle = ball_velocity.angle() + adjustment_angle_rad

					# Clamp the angle to prevent extreme vertical shots (e.g., max 70 degrees from horizontal)
					var max_angle_deviation = deg_to_rad(70.0)
					if ball_velocity.x > 0: # Moving right (away from player)
						new_angle = clamp(new_angle, -max_angle_deviation, max_angle_deviation)
					else: # Moving left (away from AI)
						# Handle wrap-around PI/-PI correctly for clamping
						if new_angle > PI - max_angle_deviation: new_angle = PI - max_angle_deviation
						elif new_angle < -PI + max_angle_deviation: new_angle = -PI + max_angle_deviation
						# Clamp angles between PI and -PI for leftward movement
						# e.g., clamp between (PI - max_dev) and (-PI + max_dev) which translates to 110 and 250 degrees if max_dev is 70
						# Simplified: ensure it's within the allowed range pointing left
						new_angle = clamp(new_angle, PI - max_angle_deviation, PI + max_angle_deviation) if new_angle > 0 else clamp(new_angle, -PI - max_angle_deviation, -PI + max_angle_deviation)
						# Even simpler clamping logic for leftward direction:
						var angle_left_min = PI - max_angle_deviation # e.g., 110 deg
						var angle_left_max = PI + max_angle_deviation # e.g., 250 deg
						# Need to handle the wrap-around, so map to 0-2PI range if easier
						# Or simpler: check if angle is within [-PI + dev, PI - dev], if outside, clamp to nearest edge
						if not (new_angle >= -PI + max_angle_deviation and new_angle <= PI - max_angle_deviation):
							if abs(new_angle) > PI - max_angle_deviation: # Check distance from horizontal
								new_angle = sign(new_angle) * (PI - max_angle_deviation)


					# Set new velocity based on calculated angle and CURRENT speed
					ball_velocity = Vector2.from_angle(new_angle).normalized() * ball_speed # Use the updated speed

			# Else (edge hit or non-paddle collision): Use the basic bounce velocity calculated earlier.

			# 3. Robust Separation: Move ball slightly away along the collision normal
			#    This helps prevent sticking in the next frame. Adjust '1.0' if needed.
			ball.global_position += normal * 1.0

		# --- Wall Collision Logic (Non-Paddle) ---
		else:
			ball_velocity = ball_velocity.bounce(normal)
			# Optional: Add separation for walls too if needed
			# ball.global_position += normal * 1.0

	# --- Screen Boundary Checks (Top/Bottom Walls) ---
	var ball_sprite = ball.get_node_or_null("Sprite") as Sprite2D
	if ball_sprite:
		var ball_half_height = ball_sprite.get_rect().size.y / 2.0 * ball.scale.y # Account for scale
		# Check top boundary
		if ball.global_position.y <= ball_half_height and ball_velocity.y < 0:
			ball_velocity.y *= -1.0 # Reverse vertical velocity
			ball.global_position.y = ball_half_height + 0.1 # Nudge slightly away from boundary
		# Check bottom boundary
		if ball.global_position.y >= screen_size.y - ball_half_height and ball_velocity.y > 0:
			ball_velocity.y *= -1.0 # Reverse vertical velocity
			ball.global_position.y = screen_size.y - ball_half_height - 0.1 # Nudge slightly away

	# --- Scoring Checks (Left/Right Boundaries) ---
	# Check if ball went past AI paddle (Player scores)
	if ball.global_position.x > screen_size.x + ball.get_node("Sprite").get_rect().size.x: # Check past the right edge
		player_score += 1
		_update_score_labels()
		if player_score < point_limit and ai_score < point_limit: # Only reset if game isn't over
			_reset_ball(false) # Start ball towards loser (AI)
		else:
			_game_over() # Trigger game over if score limit reached

	# Check if ball went past Player paddle (AI scores)
	elif ball.global_position.x < -ball.get_node("Sprite").get_rect().size.x: # Check past the left edge
		ai_score += 1
		_update_score_labels()
		if player_score < point_limit and ai_score < point_limit: # Only reset if game isn't over
			_reset_ball(true) # Start ball towards loser (Player)
		else:
			_game_over() # Trigger game over if score limit reached


# --- Game State ---
# Added direction parameter: true = serve towards player, false = serve towards AI
func _reset_ball(serve_to_player: bool = true):
	ball.global_position = screen_size / 2
	ball_speed = BALL_INITIAL_SPEED
	ball_velocity = Vector2.ZERO # Stop ball momentarily before serving

	# Wait a very short time before launching
	await get_tree().create_timer(0.1).timeout
	if game_over_flag: return # Don't launch if game ended during wait

	# Calculate initial angle (more horizontal)
	randomize()
	var initial_angle_deg = randf_range(15.0, 35.0) # Smaller angle range for more horizontal serve
	var angle_rad = deg_to_rad(initial_angle_deg)

	# Randomize vertical direction
	if randi() % 2 == 0:
		angle_rad *= -1

	# Set horizontal direction based on who scored
	var serve_direction = Vector2.RIGHT if serve_to_player else Vector2.LEFT

	ball_velocity = serve_direction.rotated(angle_rad)
	print("Ball reset. Serving to %s. Initial Velocity: %s" % ["Player" if serve_to_player else "AI", ball_velocity])


func _update_score_labels():
	if player_score_label: player_score_label.text = str(player_score)
	if ai_score_label: ai_score_label.text = str(ai_score)


func _game_over():
	if game_over_flag: return # Already processing game over
	game_over_flag = true
	print("Game Over sequence started!")
	ball_velocity = Vector2.ZERO # Stop the ball immediately
	ball.global_position = Vector2(-100, -100) # Move ball off-screen

	# Optionally display winner text or banner here

	# Wait before returning to menu
	await get_tree().create_timer(3.0).timeout

	# Ensure the node is still valid before changing scene (important!)
	if is_instance_valid(self):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
