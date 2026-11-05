class_name ContactBeacon
extends RadioSignal
## The facility's emergency beacon (Chapter 1's opening): a station calling on one
## frequency, asking anyone out there to respond on it. With one in a level, each radio is
## switched on somewhere random on the band (Radio.start_random), so the two have to find
## each other. The radar prints the beacon's frequency, an obvious place to meet, but any
## frequency they both tune to works. It never stops: like any station, it's still there
## under whoever talks on it.


func _ready() -> void:
	super()
	if transcript.is_empty():
		transcript = "EMERGENCY BEACON // AUTOMATED\nCONTACT CHANNEL %.1f\nANY STATION, ANY STATION. RESPOND ON %.1f." % [frequency, frequency]
	Radio.start_random(frequency)
