class_name RadioSignal
extends Node3D
## A station on the radio band: something in the level broadcasting on one frequency,
## found by tuning the terminal's RADIO tab (see Radio). Close tuning brings it in through
## the static; once it comes in clearly, its transcript types out on the tuner.
## For puzzles: frequencies to hunt for, to read out, or to hand to the partner ("tune to
## 121.5"), and things only one of the two can pick up (`role`, `audible_range`).

## Emitted on this machine the first time its player hears this station clearly.
signal heard

@export var frequency := 121.5
## Loop on the Radio bus while tuned in, e.g. "radio_beacon" (see Sound).
@export var sound := ""
## What the tuner shows once the station is clear. MetaSave placeholders work ({iteration}).
@export_multiline var transcript := ""
## 0: heard anywhere. Otherwise only within this many metres of the station.
@export var audible_range := 0.0
## "both", or "subject" / "visitor" for only one of them.
@export_enum("both", "subject", "visitor") var role := "both"
## The trace on the tuner's oscilloscope: "tone", "pulse" (Morse, beeps) or "voice".
@export_enum("tone", "pulse", "voice") var shape := "pulse"


func _ready() -> void:
	add_to_group("radio_signals")


## 0..1: how well this station is heard on `tuned` from `listener` (the local player).
func strength_at(tuned: float, listener: Vector3) -> float:
	if role != "both" and Session.ROLE_NAMES[Session.local_role()].to_lower() != role:
		return 0.0
	var strength := Radio.reception(tuned, frequency)
	if audible_range > 0.0:
		strength *= clampf(1.0 - global_position.distance_to(listener) / audible_range, 0.0, 1.0)
	return strength
