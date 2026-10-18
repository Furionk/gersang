class_name UiFeedbackProfile
extends Resource
@export_group("Ground acknowledgement")
@export var ring_duration:float=0.35
@export var ring_start_radius:float=5.0
@export var ring_end_radius:float=23.0
@export var ring_color:Color=Color(0.95,0.81,0.5,0.9)
@export_group("Interface audio")
@export_range(-40,0) var volume_db:float=-16.0
@export var prepare_sound:AudioStream
@export var confirm_sound:AudioStream
@export var cancel_sound:AudioStream
@export var error_sound:AudioStream
@export var prepare_frequency:float=740.0
@export var confirm_frequency:float=980.0
@export var cancel_frequency:float=420.0
@export var error_frequency:float=180.0
@export var sound_duration:float=0.09
@export_group("Support sprite")
@export var support_duration:float=0.55
@export var support_width:float=92.0
