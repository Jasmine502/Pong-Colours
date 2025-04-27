# res://scenes/game.gd
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

# --- Exported Texture Arrays (Link these in the Godot Editor Inspector!) ---
@export_category("Paddle Textures")
@export var colour_paddles: Array[Texture2D] = []
@export var meme_paddles: Array[Texture2D] = []
@export var pride_paddles: Array[Texture2D] = []

@export_category("Ball Textures")
@export var colour_balls: Array[Texture2D] = []
@export var meme_balls: Array[Texture2D] = []
@export var pride_balls: Array[Texture2D] = []
# --- End Exported Textures ---

# --- Game Settings ---
var current_game_point_limit: int = 5
var player_score = 0
var ai_score = 0
const DEFAULT_PLAYER_NAME = "Player"

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

# --- Asset Paths (Stored temporarily after selection) ---
var player_paddle_resource_path: String = ""
var ai_paddle_resource_path: String = ""
# var ball_resource_path: String = "" # Ball path not needed elsewhere currently

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
	# Seed random number generator
	randomize()

	screen_size = get_viewport_rect().size
	if screen_size == Vector2.ZERO:
		await get_tree().process_frame
		screen_size = get_viewport_rect().size
		if screen_size == Vector2.ZERO:
			printerr("Game: Failed to get valid screen size. Using fallback.")
			screen_size = Vector2(1152, 648) # Ensure this matches your project default

	ai_target_y = screen_size.y / 2.0

	# Connect Achievement Signal
	if DataManager:
		if DataManager.has_signal("achievement_unlocked"):
			DataManager.achievement_unlocked.connect(_on_data_manager_achievement_unlocked)
			print("Game: Connected to DataManager achievement signal.")
		else:
			printerr("Game: DataManager does not have the 'achievement_unlocked' signal!")
	else:
		printerr("Game: DataManager not found, cannot connect achievement signal.")

	# Check UI Nodes
	if not is_instance_valid(achievement_banner): printerr("Game: AchievementBanner node NOT found!")
	if not is_instance_valid(achievement_animator): printerr("Game: AchievementAnimator node NOT found!")
	if not is_instance_valid(menu_button): printerr("Game: MenuButton node NOT found.")
	else: menu_button.pressed.connect(_on_menu_button_pressed)

	# Background Shader
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

	# Player Name Colors
	LETTER_COLORS = { "A": Color.html("#F2A2B1"),"B": Color.html("#0000FF"),"C": Color.html("#00FFFF"),"D": Color.html("#FDDA0D"),"E": Color.html("#A7C9A7"),"F": Color.html("#FF00FF"),"G": Color.html("#008000"),"H": Color.html("#3FFF00"),"I": Color.html("#4B0082"),"J": Color.html("#00A86B"),"K": Color.html("#C3B091"),"L": Color.html("#FFFACD"),"M": Color.html("#FF00FF"),"N": Color.html("#39FF14"),"O": Color.html("#FFA500"),"P": Color.html("#800080"),"Q": Color.html("#D4C4AE"),"R": Color.html("#FF0000"),"S": Color.html("#FF2400"),"T": Color.html("#F94C00"),"U": Color.html("#8878C3"),"V": Color.html("#EE82EE"),"W": Color.html("#F5DEB3"),"X": Color.html("#66BFBF"),"Y": Color.html("#FFFF00"),"Z": Color.html("#3E646C"),"DEFAULT": Color.WHITE }

	# Load Game Settings & Player Name
	if DataManager:
		_set_player_name_color(DataManager.get_player_name())
		current_game_point_limit = DataManager.get_point_limit()
	else:
		printerr("Game: DataManager not found! Using defaults.")
		_set_player_name_color(DEFAULT_PLAYER_NAME)
		current_game_point_limit = 5
	print("Game: Point Limit for this match:", current_game_point_limit)

	# --- NEW: Assign random textures using exported arrays ---
	var all_paddles: Array[Texture2D] = []
	all_paddles.append_array(colour_paddles)
	all_paddles.append_array(meme_paddles)
	all_paddles.append_array(pride_paddles)

	var all_balls: Array[Texture2D] = []
	all_balls.append_array(colour_balls)
	all_balls.append_array(meme_balls)
	all_balls.append_array(pride_balls)

	var player_texture: Texture2D = null
	var ai_texture: Texture2D = null
	var ball_texture: Texture2D = null

	if not all_paddles.is_empty():
		player_texture = all_paddles.pick_random()
		ai_texture = all_paddles.pick_random()
	else:
		printerr("Game Warning: No paddle textures linked in the Inspector!")

	if not all_balls.is_empty():
		ball_texture = all_balls.pick_random()
	else:
		printerr("Game Warning: No ball textures linked in the Inspector!")

	# Assign Player Paddle Texture
	if player_texture and is_instance_valid(player_paddle) and player_paddle.has_node("Sprite"):
		player_paddle.get_node("Sprite").texture = player_texture
		player_paddle_resource_path = player_texture.resource_path # Store path for achievements
		print("Game: Player Paddle Texture:", player_paddle_resource_path.get_file())
	else:
		printerr("Game: Failed to assign Player paddle texture or Sprite node missing.")
		player_paddle_resource_path = ""

	# Assign AI Paddle Texture
	if ai_texture and is_instance_valid(ai_paddle) and ai_paddle.has_node("Sprite"):
		ai_paddle.get_node("Sprite").texture = ai_texture
		ai_paddle_resource_path = ai_texture.resource_path # Store path for achievements
		print("Game: AI Paddle Texture:", ai_paddle_resource_path.get_file())
	else:
		printerr("Game: Failed to assign AI paddle texture or Sprite node missing.")
		ai_paddle_resource_path = ""

	# Assign Ball Texture
	if ball_texture and is_instance_valid(ball) and ball.has_node("Sprite"):
		ball.get_node("Sprite").texture = ball_texture
		# ball_resource_path = ball_texture.resource_path # Currently not needed elsewhere
		print("Game: Ball Texture:", ball_texture.resource_path.get_file())
	else:
		printerr("Game: Failed to assign Ball texture or Sprite node missing.")
		# ball_resource_path = ""

	# --- Check Achievements based on selected textures ---
	if DataManager:
		# Check "Two of a Kind" (requires valid paths)
		if not player_paddle_resource_path.is_empty() and player_paddle_resource_path == ai_paddle_resource_path:
			DataManager.unlock_achievement("TWO OF A KIND")

		# Track player paddle usage (requires valid path)
		if not player_paddle_resource_path.is_empty():
			DataManager.add_player_paddle_used(player_paddle_resource_path)
			# Note: The checks for other paddle achievements (Slay, Chameleon, etc.)
			# will trigger inside DataManager.add_player_paddle_used

	# Set initial positions
	if is_instance_valid(player_paddle):
		player_paddle.global_position = Vector2(PLAYER_PADDLE_X, screen_size.y / 2.0)
	if is_instance_valid(ai_paddle):
		ai_paddle.global_position = Vector2(screen_size.x - AI_PADDLE_X_OFFSET, screen_size.y / 2.0)

	# Start game
	_update_score_labels() # Show 0 - 0
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

	# Force paddles to stay on their X-axis
	if is_instance_valid(player_paddle):
		player_paddle.global_position.x = PLAYER_PADDLE_X
	if is_instance_valid(ai_paddle) and screen_size.x > 0:
		ai_paddle.global_position.x = screen_size.x - AI_PADDLE_X_OFFSET

	_handle_ball_movement(delta)

	# Update background shader based on ball position
	if is_instance_valid(background_material) and screen_size != Vector2.ZERO:
		if is_instance_valid(ball):
			var normalized_pos = ball.global_position / screen_size
			background_material.set_shader_parameter("ball_position_normalized", normalized_pos)


func _on_data_manager_achievement_unlocked(achievement_name: String):
	print("Game received achievement unlock signal:", achievement_name)
	if not is_instance_valid(achievement_banner) or not is_instance_valid(achievement_animator):
		printerr("Cannot show achievement banner, nodes missing.")
		return

	var anim_name = "ShowBanner"

	# Prevent re-triggering if already playing
	if achievement_animator.is_playing() and achievement_animator.current_animation == anim_name:
		# Optionally, could queue it or restart it, but skipping is simpler
		print("Banner animation '", anim_name,"' already playing, skipping.")
		return

	# Set banner text (assuming banner node might be a Label)
	# If it's just a TextureRect, this line can be removed or adapted
	if achievement_banner is Label:
		(achievement_banner as Label).text = "[center]Achievement Unlocked!\n[b]" + achievement_name.capitalize() + "[/b][/center]"
	elif achievement_banner is RichTextLabel:
		(achievement_banner as RichTextLabel).bbcode_enabled = true
		(achievement_banner as RichTextLabel).text = "[center]Achievement Unlocked!\n[b]" + achievement_name.capitalize() + "[/b][/center]"
	elif achievement_banner is TextureRect:
		# If it's a TextureRect, you might change its texture based on achievement,
		# or more likely, have text elements overlaid in the scene tree.
		pass # No text setting needed if it's just an image background

	# Play animation
	if achievement_animator.has_animation(anim_name):
		print("Playing achievement animation:", anim_name)
		achievement_animator.play(anim_name)
	else:
		printerr("Achievement animation '", anim_name, "' not found in AchievementAnimator node!")


func _on_menu_button_pressed():
	print("Game: Menu button pressed.")
	# Consider pausing the game here if desired: get_tree().paused = true
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _set_player_name_color(player_name_text: String):
	if not is_instance_valid(player_name_label):
		printerr("Game: PlayerNameLabel node not found, cannot set name.")
		return

	var bbcode = "[center]"
	for letter in player_name_text:
		var color = get_color_for_letter(letter)
		# Ensure alpha is 1.0 for visibility
		bbcode += "[color=" + color.to_html(false) + "]" + letter + "[/color]"
	bbcode += "[/center]"

	# Check if the label supports BBCode
	if player_name_label is RichTextLabel:
		(player_name_label as RichTextLabel).bbcode_enabled = true
		player_name_label.text = bbcode
	elif player_name_label is Label:
		# Basic Labels don't support BBCode directly like this.
		# You might need to use a RichTextLabel instead in your scene,
		# or set the modulate property if you want a single color.
		player_name_label.text = player_name_text # Fallback to plain text
		printerr("Game: PlayerNameLabel is a Label, cannot apply BBCode colors. Use RichTextLabel.")
	else:
		printerr("Game: PlayerNameLabel is unexpected type.")


func get_color_for_letter(letter: String) -> Color:
	var upper = letter.to_upper()
	if LETTER_COLORS.has(upper):
		return LETTER_COLORS[upper]
	elif LETTER_COLORS.has("DEFAULT"):
		return LETTER_COLORS["DEFAULT"]
	else:
		return Color.WHITE # Fallback color


# REMOVED: _load_random_texture_from_folders function is no longer needed


func _handle_player_input(delta):
	if not is_instance_valid(player_paddle):
		return

	var direction = Input.get_axis("move_up", "move_down") # Assumes input map actions "move_up", "move_down"
	var target_velocity_y: float = direction * PADDLE_SPEED

	# Apply smoothing using lerp
	var lerp_weight: float = 1.0 - exp(-delta * PADDLE_SMOOTHING)
	player_paddle.velocity.y = lerp(player_paddle.velocity.y, target_velocity_y, lerp_weight)

	player_paddle.move_and_slide()

	# Clamp position to screen bounds
	var player_sprite = player_paddle.get_node_or_null("Sprite") as Sprite2D
	if player_sprite and player_sprite.texture and screen_size.y > 0:
		var half_height = player_sprite.get_rect().size.y / 2.0 * player_paddle.scale.y
		# Use global_position for clamping based on world space
		player_paddle.global_position.y = clampf(player_paddle.global_position.y, half_height, screen_size.y - half_height)


func _handle_ai_movement(delta):
	if not is_instance_valid(ball) or not is_instance_valid(ai_paddle):
		return

	var distance_to_ball: float = abs(ball.global_position.x - ai_paddle.global_position.x)
	var current_y: float = ai_paddle.global_position.y

	# Basic prediction: Aim for where the ball *will be* vertically, clamped to screen
	var predicted_ball_y: float = ball.global_position.y
	if screen_size.x != 0.0 and ball.velocity.x != 0.0: # Avoid division by zero
		# Simple linear prediction based on time = distance / speed
		# var time_to_reach_paddle = distance_to_ball / abs(ball.velocity.x) # More accurate but complex if speed changes
		# A simpler factor based on distance ratio:
		var prediction_offset = ball.velocity.y * AI_PREDICTION_FACTOR * (distance_to_ball / screen_size.x)
		predicted_ball_y = ball.global_position.y + prediction_offset

	if screen_size.y > 0:
		predicted_ball_y = clampf(predicted_ball_y, 0.0, screen_size.y) # Clamp prediction

	# Decide target based on distance (react fast when close, smoother when far)
	if distance_to_ball < AI_REACTION_DISTANCE_THRESHOLD:
		ai_target_y = predicted_ball_y # React directly to predicted position
	else:
		# Smoother tracking when ball is far away
		ai_target_y = lerp(ai_target_y, float(predicted_ball_y), delta * 2.0) # Adjust lerp factor for desired smoothness


	# Determine movement direction towards the target Y
	var direction: float = 0.0
	if abs(ai_target_y - current_y) > 5.0: # Add a small deadzone to prevent jitter
		direction = sign(ai_target_y - current_y)

	var target_velocity_y: float = direction * (PADDLE_SPEED * AI_SPEED_MODIFIER)

	# Apply smoothing
	var lerp_weight: float = 1.0 - exp(-delta * AI_SMOOTHING)
	ai_paddle.velocity.y = lerp(ai_paddle.velocity.y, target_velocity_y, lerp_weight)

	ai_paddle.move_and_slide()

	# Clamp AI paddle position
	var ai_sprite = ai_paddle.get_node_or_null("Sprite") as Sprite2D
	if ai_sprite and ai_sprite.texture and screen_size.y > 0:
		var half_height: float = ai_sprite.get_rect().size.y / 2.0 * ai_paddle.scale.y
		ai_paddle.global_position.y = clampf(ai_paddle.global_position.y, half_height, screen_size.y - half_height)


func _handle_ball_movement(delta):
	if not is_instance_valid(ball):
		return

	# Apply current velocity
	ball.velocity = ball_velocity.normalized() * ball_speed # Ensure speed is controlled
	var collision_info = ball.move_and_collide(ball.velocity * delta)

	if collision_info:
		var normal: Vector2 = collision_info.get_normal()
		var collider = collision_info.get_collider()
		var collision_pos: Vector2 = collision_info.get_position()

		# Check if collided with a paddle
		if collider == player_paddle or collider == ai_paddle:
			# Emit particles BEFORE changing velocity
			if is_instance_valid(collider):
				_emit_collision_particles(collider, collision_pos, normal)

			# Calculate bounced velocity based on surface normal
			var bounced_velocity: Vector2 = ball_velocity.bounce(normal)

			# Determine hit type (face vs edge) based on normal direction
			# Note: Assumes paddles are aligned vertically (normal.x is dominant for face)
			var is_face_hit: bool = abs(normal.x) > FACE_HIT_NORMAL_THRESHOLD
			var is_edge_hit: bool = abs(normal.y) > EDGE_HIT_NORMAL_THRESHOLD and not is_face_hit # Only edge if not face

			if is_face_hit:
				# Increase speed on paddle face hit
				ball_speed += BALL_SPEED_INCREASE
				ball_speed = min(ball_speed, 2500) # Add a max speed cap?

				# Apply spin based on where ball hits paddle vertically
				var shape_node = collider.get_node_or_null("CollisionShape2D")
				if shape_node and shape_node.shape is RectangleShape2D:
					var paddle_height: float = shape_node.shape.size.y * collider.scale.y
					if paddle_height != 0.0:
						# Calculate relative hit position (-1 bottom, 0 middle, 1 top)
						var relative_y: float = clampf((ball.global_position.y - collider.global_position.y) / (paddle_height / 2.0), -1.0, 1.0)

						# Apply angle adjustment based on relative hit position
						var influence: float = 0.6 # How much influence the hit pos has (0 to 1)
						# Adjust angle based on hit pos (hitting top sends ball down, hitting bottom sends up)
						var adjustment_angle: float = PI * influence * -relative_y / 2.0 # Max +/- PI/2 * influence radians

						var new_angle: float = bounced_velocity.angle() + adjustment_angle

						# Clamp angle to prevent extreme vertical shots
						var max_deviation: float = deg_to_rad(70.0) # Max angle relative to horizontal
						# Clamp based on direction
						if bounced_velocity.x > 0.0: # Moving right (hit player paddle)
							new_angle = clampf(new_angle, -max_deviation, max_deviation)
						else: # Moving left (hit AI paddle)
							# Handle angle wrapping around PI
							if not (new_angle >= -PI + max_deviation and new_angle <= PI - max_deviation):
								new_angle = sign(new_angle) * (PI - max_deviation) # Clamp towards +/- (PI - max_dev)

						# Set new velocity from angle and speed
						ball_velocity = Vector2.from_angle(new_angle).normalized() * ball_speed
					else:
						# Fallback if paddle height is zero? Use simple bounce.
						ball_velocity = bounced_velocity.normalized() * ball_speed
				else:
					# Fallback if shape is not rectangle or not found
					ball_velocity = bounced_velocity.normalized() * ball_speed

			elif is_edge_hit:
				# Handle edge hits: make ball go more horizontal, dampen vertical
				print("Edge Hit Detected! Normal:", normal)
				var push_direction: float = 1.0 if collider == player_paddle else -1.0
				ball_velocity.x = push_direction * EDGE_HIT_SET_HORIZONTAL_SPEED # Set fixed horizontal speed
				ball_velocity.y = bounced_velocity.y * EDGE_HIT_VERTICAL_DAMPEN # Dampen vertical bounce
				ball_speed = ball_velocity.length() # Update speed based on new vector

			else: # Corner hit or unexpected normal - treat as simple bounce
				print("Corner Hit / Other? Normal:", normal)
				ball_velocity = bounced_velocity

			# Separate ball slightly from paddle after collision to prevent sticking
			ball.global_position += normal * COLLISION_SEPARATION_MULTIPLIER

		else: # Wall collision (Top/Bottom walls)
			# Just bounce normally
			ball_velocity = ball_velocity.bounce(normal)
			# Optional: Play wall bounce sound effect here

	# --- Screen boundary checks (Top/Bottom) ---
	var ball_sprite = ball.get_node_or_null("Sprite") as Sprite2D
	if ball_sprite and ball_sprite.texture and screen_size.y > 0:
		var ball_half_height: float = ball_sprite.get_rect().size.y / 2.0 * ball.scale.y

		# Check Top Boundary
		if ball.global_position.y <= ball_half_height and ball_velocity.y < 0.0:
			ball_velocity.y *= -1.0 # Reverse vertical velocity
			ball.global_position.y = ball_half_height + 0.1 # Move slightly away from edge

		# Check Bottom Boundary
		if ball.global_position.y >= screen_size.y - ball_half_height and ball_velocity.y > 0.0:
			ball_velocity.y *= -1.0 # Reverse vertical velocity
			ball.global_position.y = screen_size.y - ball_half_height - 0.1 # Move slightly away

	# --- Scoring Checks (Left/Right) ---
	var ball_half_width: float = 10.0 # Default radius/half-width
	if ball_sprite and ball_sprite.texture:
		ball_half_width = ball_sprite.get_rect().size.x / 2.0 * ball.scale.x

	var scored = false
	# AI Scored (Ball past left edge)
	if not scored and ball.global_position.x < -ball_half_width:
		scored = true
		ai_score += 1
		print("AI Scored! Score: %d - %d" % [player_score, ai_score])
		_update_score_labels()
		if DataManager:
			DataManager.increment_conceded_points() # Track for achievement
		# Check if game continues
		if player_score < current_game_point_limit and ai_score < current_game_point_limit:
			_reset_ball(true) # Serve to Player
		elif not game_over_flag:
			_game_over() # Trigger game over sequence

	# Player Scored (Ball past right edge)
	elif not scored and screen_size.x > 0 and ball.global_position.x > screen_size.x + ball_half_width:
		scored = true
		player_score += 1
		print("Player Scored! Score: %d - %d" % [player_score, ai_score])
		_update_score_labels()
		if DataManager:
			DataManager.unlock_achievement("PONG GOD") # Track for achievement
		# Check if game continues
		if player_score < current_game_point_limit and ai_score < current_game_point_limit:
			_reset_ball(false) # Serve to AI
		elif not game_over_flag:
			_game_over() # Trigger game over sequence


func _emit_collision_particles(paddle_collider: Node, collision_position: Vector2, _normal: Vector2):
	if not PADDLE_HIT_PARTICLES:
		printerr("Paddle hit particle scene not preloaded!")
		return

	var p_inst = PADDLE_HIT_PARTICLES.instantiate()

	# Ensure it's the correct type before proceeding
	if not p_inst is GPUParticles2D:
		if is_instance_valid(p_inst): p_inst.queue_free() # Clean up wrong instance
		printerr("Instantiated particle scene is not GPUParticles2D!")
		return

	var particles = p_inst as GPUParticles2D
	add_child(particles) # Add particles to the main game scene tree
	particles.global_position = collision_position

	# --- Get color from the paddle's sprite ---
	var color = Color.WHITE # Default color
	var sprite = paddle_collider.get_node_or_null("Sprite") as Sprite2D
	if sprite and sprite.texture:
		var img = sprite.texture.get_image()
		if img:
			# Attempt to decompress if needed (common for imported textures)
			if img.is_compressed():
				var can_decompress = img.can_decompress() # Check first
				if can_decompress:
					var decompress_err = img.decompress()
					if decompress_err != OK:
						printerr("Failed to decompress paddle texture image for color sampling. Error:", decompress_err)
						img = null # Mark image as invalid
				else:
					printerr("Cannot decompress paddle texture image format for color sampling.")
					img = null # Mark image as invalid

			if img: # Check again if image is still valid after potential decompression attempt
				var w = img.get_width()
				var h = img.get_height()
				if w > 0 and h > 0:
					# Get color from the center pixel (simple approach)
					color = img.get_pixel(w / 2, h / 2)
					# Important: Ensure alpha is suitable for particles
					color.a = 1.0 # Use full alpha for modulate, particle material handles fade
				else:
					printerr("Paddle texture image has zero width or height.")
		else:
			printerr("Could not get image data from paddle texture.")
	else:
		printerr("Could not find Sprite node or texture on paddle.")

	# Apply the sampled color to the particle system
	particles.modulate = color
	particles.emitting = true # Start emitting particles

	# --- Auto-cleanup: Free the particle node when it finishes ---
	# Connect the 'finished' signal to the node's 'queue_free' method
	if not particles.is_connected("finished", particles.queue_free):
		particles.finished.connect(particles.queue_free)


func _reset_ball(serve_to_player: bool = true):
	if not is_instance_valid(ball):
		printerr("Reset Ball: Ball node is not valid!")
		return

	# Center the ball
	ball.global_position = screen_size / 2.0
	# Reset speed
	ball_speed = BALL_INITIAL_SPEED
	# Stop current movement
	ball_velocity = Vector2.ZERO

	# Short delay before serving
	# Check if the node is still valid before starting timer
	if not is_instance_valid(self): return
	await get_tree().create_timer(0.1).timeout # Adjust delay as needed

	# Check again after timer if game is over or node is gone
	if game_over_flag or not is_instance_valid(self) or not is_instance_valid(ball):
		return

	# Calculate serve direction
	randomize() # Ensure randomness
	var angle_deg: float = randf_range(15.0, 35.0) # Serve angle range
	var angle_rad: float = deg_to_rad(angle_deg)
	# Randomly flip vertical angle
	if randi() % 2 == 0:
		angle_rad *= -1.0

	var direction_vector: Vector2 = Vector2.RIGHT if serve_to_player else Vector2.LEFT
	ball_velocity = direction_vector.rotated(angle_rad).normalized() * ball_speed

	print("Ball reset. Serving %s. Initial Vel: %s" % ["Player" if serve_to_player else "AI", ball_velocity])


func _update_score_labels():
	if is_instance_valid(player_score_label):
		player_score_label.text = str(player_score)
	else:
		printerr("Game: PlayerScoreLabel node not found.")
	if is_instance_valid(ai_score_label):
		ai_score_label.text = str(ai_score)
	else:
		printerr("Game: AIScoreLabel node not found.")


func _game_over():
	if game_over_flag: # Prevent running multiple times
		return
	game_over_flag = true
	print("Game Over! Final Score: Player %d - AI %d" % [player_score, ai_score])

	# Stop ball movement and hide it
	ball_velocity = Vector2.ZERO
	if is_instance_valid(ball):
		ball.hide() # Or move off-screen: ball.global_position = Vector2(-200, -200)

	# Optional: Display "Game Over" message on screen?

	# Short delay before returning to menu
	# Check if the node is still valid before starting timer
	if not is_instance_valid(self): return
	await get_tree().create_timer(3.0).timeout # Adjust delay as needed

	# Check again after timer if node is still valid
	if is_instance_valid(self):
		# Ensure game is unpaused if it was paused
		# get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
