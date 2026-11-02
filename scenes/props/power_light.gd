class_name PowerLight
extends Light3D
## A light that puzzles and heaters can switch (set_active). The energy set in the
## editor is its "on" brightness; it flickers on when power comes back.

@export var start_active := false

@onready var _on_energy := light_energy


func _ready() -> void:
	light_energy = _on_energy if start_active else 0.0


func set_active(active: bool) -> void:
	var tween := create_tween()
	if active:
		Sound.play_at("lights_on", global_position, 0.0, 25.0, 0.0)
		tween.tween_property(self, "light_energy", _on_energy, 0.08)
		tween.tween_property(self, "light_energy", 0.0, 0.12)
		tween.tween_property(self, "light_energy", _on_energy, 0.4)
	else:
		tween.tween_property(self, "light_energy", 0.0, 0.3)
