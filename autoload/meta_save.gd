extends Node
## What the game remembers between sessions. Lives only in the game's own save
## folder (user://) and never reads anything outside it.
## PROCTOR uses it in its lines: the loop is real, and it is counting.
##
## Each machine keeps its own counts, so the two players see different numbers
## for the "same" thing, which is asymmetric truth for free.

const PATH := "user://proctor.cfg"
const ITERATION_BASE := 4116

var counters := {"launches": 0, "sessions": 0, "sessions_abandoned": 0, "deaths": 0, "chapters_completed": 0, "lines_skipped": 0}
## Reset at the start of every session.
var session := {"radio_presses": 0, "deaths": 0}


func _ready() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		for key in counters:
			counters[key] = file.get_value("counters", key, 0)
	record("launches")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("radio"):
		session["radio_presses"] += 1


func record(key: String, amount := 1) -> void:
	counters[key] = counters.get(key, 0) + amount
	if session.has(key):
		session[key] += amount
	_save()


func begin_session() -> void:
	for key in session:
		session[key] = 0
	record("sessions")


## True when a story condition (a line's "if") holds on this machine.
func check(condition: String) -> bool:
	match condition:
		"radio_unused":
			return session["radio_presses"] == 0
		"died_before":
			return counters["deaths"] > 0
		"returning":
			return counters["sessions"] > 1
		"abandoned_before":
			return counters["sessions_abandoned"] > 0
		"skipper":
			return counters["lines_skipped"] >= 10
	push_warning("Unknown story condition: %s" % condition)
	return false


## Fills {iteration}, {attempt}, {deaths}, {launches}, {abandoned} and {skipped} in story text.
func format(text: String) -> String:
	return text.format({
		"iteration": ITERATION_BASE + counters["sessions"],
		"attempt": counters["sessions"],
		"deaths": counters["deaths"],
		"launches": counters["launches"],
		"abandoned": counters["sessions_abandoned"],
		"skipped": counters["lines_skipped"],
	})


func _save() -> void:
	var file := ConfigFile.new()
	for key in counters:
		file.set_value("counters", key, counters[key])
	file.save(PATH)
