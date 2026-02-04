extends Area2D

@export var rotateTheta = 10 # How fast the player will move (pixels/sec).
var screen_size # Size of the game window


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport_rect().size
	self.rotation = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_pressed("press"):
		if self.global_rotation_degrees <= 90 or self.global_rotation_degrees > -90 :
			self.rotate(-deg_to_rad(self.rotateTheta))
	else:
		if self.global_rotation_degrees != 10 :
			self.rotate(deg_to_rad(self.rotateTheta))
		#print(self.global_rotation_degrees)
