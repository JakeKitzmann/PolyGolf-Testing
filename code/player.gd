extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var sensitivity = 500

@onready var player = $AnimationPlayer

@onready var camera_pivot = $CameraPivot

var pan_mode = 0


func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("player_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("player_left", "player_right", "player_forward", "player_back")

	if input_dir != Vector2.ZERO:
		player.play('Walk')
	else:
		player.play('Idle')


		
		
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
func _input(event):
	
	# assign pan_mode
	if event is InputEventKey and event.is_action_pressed('pan_mode_toggle'):
		print('i work')
		if pan_mode:
			pan_mode = 0
		else:
			pan_mode = 1
	
	if event is InputEventMouseMotion:
		
		# check if you want to move character and cam with mouse
		if pan_mode:
			rotation.y -= event.relative.x / sensitivity
		else:
			camera_pivot.rotation.y -= event.relative.x / sensitivity
			
		camera_pivot.rotation.x -= event.relative.y / sensitivity
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-45), deg_to_rad(90))
		
