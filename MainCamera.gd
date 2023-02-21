extends Camera


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

var isTracking = false
func _input(event):
	
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			isTracking = event.pressed
	
	if not isTracking:
		return
		
	if event is InputEventMouseMotion:
		if event.relative.x != 0:
			rotate_object_local(Vector3.UP, event.relative.x * PI/180)
		if event.relative.y != 0:
			rotate_object_local(Vector3.RIGHT, event.relative.y * PI/180)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
