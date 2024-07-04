extends CharacterBody3D

# node dependencies
@onready var player = $AnimationPlayer
@onready var iron = $Armature/Skeleton3D/BoneAttachment3D/Iron
@onready var ball = $Ball
@onready var ball_pointer = $BallPointer
@onready var win_ui = $HUD/Win

@export var camera_target: Node3D
@export var camera_parent: Node3D
@export var walking_camera: Camera3D
@export var shooting_pivot: Node3D
@export var shooting_camera: Camera3D

# physics constants
const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var rotation_speed = 5.0
@export var sensitivity = 500

# hud variables
var mouse_visible = 0

# camera stats
var camera_T = float()
var cam_speed = float()
var pan_mode = 0

# shooting variables
var move_to_ball = 0
var shooting_offset = .5
var swing_once = 0
var in_shooting_mode = 0

# club list {active (bool for shot), animation, power, phi}
var clubs = {'driver': [0, 'IronSwing', 42, 20], 'iron' : [0, 'IronSwing', 20, 45], 'wedge' : [0, 'IronSwing', 15, 90], 'putter' : [0, 'IronSwing', 6, 5]}

# strokes on hole
signal strokes

# signals
signal draw_arc
signal hud_toggle

func _ready():
	walking_camera.current = true # set walking camera as active
	
	
func switch_cam():
	$ShootingParent/ShootingPivot/ShotCamera.current = true
	in_shooting_mode = 1
	shooting_pivot.global_transform.origin = ball.global_transform.origin
	

# gameplay loop
func _physics_process(delta):
	
	# gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		player.play('Jump')

	
	# ball pointer
	ball_pointer.look_at(ball.global_transform.origin)
	
	# camera
	camera_smooth_follow(delta)
	
	# if / elif to determine game state (shooting vs not shooting)
	if in_shooting_mode:
		
		if player.current_animation != 'IronSwing':
			player.play("IdleSwing") # change to idle swing
			iron.visible = true
			
			if (ball.position - position).length() < 3: # stop ball if its slightly moving
						if not swing_once:
							ball.linear_velocity = Vector3.ZERO
							
		
		# keeps player facing ball
		rotation.y = shooting_pivot.rotation.y + deg_to_rad(90)
		
		# movement around ball to aim
		var camera_vector = shooting_camera.global_transform.origin - shooting_pivot.global_transform.origin
		var angle_to_ball = atan2(camera_vector.z, camera_vector.x)
		position.x = shooting_pivot.global_transform.origin.x  + .9 * cos(angle_to_ball + deg_to_rad(90))
		position.z = shooting_pivot.global_transform.origin.z + .9 * sin(angle_to_ball + deg_to_rad(90))
		
		# for all the clubs check if the player is swinging that club
		# can be used later to adjust power and arc based on vals in 
		# club dictionary
		for club_type in clubs:
			var club = clubs[club_type]
			
			if club[0] == 1: # if the club is active
				if player.current_animation != club[1]: # not swinging the club
					pass
				elif player.current_animation == club[1] and swing_once:  # swinging the club
					swing_once = 0
					emit_signal('draw_arc') # tell ball to draw arc following shot
					
					var shot_angle = angle_to_ball + deg_to_rad(180) # calculate shot angle opposite of camera
					
					print(club)
					# shot delayed by timers to match animation
					await get_tree().create_timer(.75).timeout
					shoot_ball(delta, shot_angle, deg_to_rad(club[3]), club[2])
					await get_tree().create_timer(1.5).timeout
					
					# switch to the normal camera and out of shooting mode
					walking_camera.current = true
 
					club[0] = 0
					in_shooting_mode = 0

			
	elif not in_shooting_mode: # elif to keep from running immediately after shot
		
		# jump
		if Input.is_action_just_pressed("player_jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
			
		# movement vector (Vector2D)
		var input_vector = Input.get_vector("player_left", 'player_right', "player_forward", "player_back")

		# get direction from vector
		var direction = (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
		
		# if moving
		if direction:
			iron.visible = false
			
			# if not swinging
			if not swing_once and not player.current_animation == 'IronSwing':
				if is_on_floor() and not Input.is_action_pressed('player_run'):
					player.play("Walk")
				else:
					player.play('Run')
					direction = direction * 3 # increase magnitude of direction for faster movement
					
			# move character
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
			
		# if not moving
		else:
			# stay still
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
			
			
			if is_on_floor() and not player.current_animation == 'IronSwing':
				iron.visible = false
				player.play("Idle")
			
		# camera target rotation
		camera_T = camera_target.global_transform.basis.get_euler().y
		
		# rotate character w keys
		if direction != Vector3.ZERO:
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), SPEED * delta)
		
	move_and_slide() # apply movement
	
# move ball when shot - eventually convert to spherical
func shoot_ball(delta, theta, phi, power):

	# send an impulse of magnitude power in direction angle 
	var force = Vector3.ZERO
	force.x = power * cos(theta)
	force.z = power * sin(theta)
	force.y = power * sin(phi)
	
	ball.apply_central_impulse(force)
	
	emit_signal('strokes')
	
# user input
func _input(event):
	
	# pause game
	if event.is_action_pressed('ui_cancel'):
		$PauseMenu.pause()

	# club swings
	if event.is_action_pressed('swing_driver') and not event.is_echo():
		swing_once = 1
		clubs['driver'][0] = 1
		iron.visible = true
		player.play("IronSwing")
	elif event.is_action_pressed('swing_iron') and not event.is_echo():
		swing_once = 1
		clubs['iron'][0] = 1
		iron.visible = true
		player.play("IronSwing")
	elif event.is_action_pressed('swing_wedge') and not event.is_echo():
		swing_once = 1
		clubs['wedge'][0] = 1
		iron.visible = true
		player.play("IronSwing")
	elif event.is_action_pressed('swing_putter') and not event.is_echo():
		swing_once = 1
		clubs['putter'][0] = 1
		iron.visible = true
		player.play("IronSwing")

	# leave shooting mode
	if in_shooting_mode:
		if event is InputEventKey and event.is_action_pressed('leave_shooting_mode'):
			walking_camera.current = true
			in_shooting_mode = 0
	
# wacky zany goofy silly camera movement
func camera_smooth_follow(delta):
	var cam_offset = Vector3(0, 3, 3).rotated(Vector3.UP, camera_T)
	cam_speed = 20
	var cam_timer = clamp(delta * cam_speed / 20, 0, 1)
	camera_parent.global_transform.origin = camera_parent.global_transform.origin.lerp(self.global_transform.origin + cam_offset, cam_timer)

# recieve that ball went in signal from pin object
func _on_pin_in_pin():
	win_ui.visible = true
