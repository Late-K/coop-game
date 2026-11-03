class_name UiStyle
## The look of a player's own interface (the terminal tabs and the HUD), chosen by the local
## player's role: each machine has one local player, so one style.
##
## The Subject's is built in: ZP-SYS, cold cyan phosphor on black, as if the menus were
## inside its head. The Visitor's is a rugged handheld brought in from outside, red, with
## chunky lettering, soft keys and a status bar. Both fill the screen behind CRT glass. The facility's own screens (save
## terminals) and the story text look the same for both.

enum Kind { SUBJECT, VISITOR }

static var kind := Kind.SUBJECT
static var accent := Color(0.45, 0.95, 0.82)
static var dim := Color(0.2, 0.42, 0.37)
static var screen := Color(0.015, 0.03, 0.03)
## Inset panels (scope, dial, map, ECG), and fills (selected slots, map rooms).
static var panel := Color(0.02, 0.05, 0.05)
static var fill := Color(0.04, 0.1, 0.09)
static var title := "ZP-SYS // OCCUPANT TERMINAL"
## Tab id -> what this device calls it.
static var tab_names := {"items": "ITEMS", "radio": "RADIO", "map": "MAP", "files": "FILES", "logs": "LOGS"}
static var _font: Font = null


static func use(role: Session.Role) -> void:
	if role == Session.Role.VISITOR:
		kind = Kind.VISITOR
		accent = Color(1.0, 0.27, 0.2)
		dim = Color(0.46, 0.11, 0.08)
		screen = Color(0.055, 0.016, 0.014)
		panel = Color(0.08, 0.018, 0.016)
		fill = Color(0.14, 0.03, 0.025)
		title = "FIELD UNIT  KT-40"
		tab_names = {"items": "PACK", "radio": "RADIO", "map": "MAP", "files": "NOTES", "logs": "LOG"}
	else:
		kind = Kind.SUBJECT
		accent = Color(0.45, 0.95, 0.82)
		dim = Color(0.2, 0.42, 0.37)
		screen = Color(0.015, 0.03, 0.03)
		panel = Color(0.02, 0.05, 0.05)
		fill = Color(0.04, 0.1, 0.09)
		title = "ZP-SYS // OCCUPANT TERMINAL"
		tab_names = {"items": "ITEMS", "radio": "RADIO", "map": "MAP", "files": "FILES", "logs": "LOGS"}
	_font = null


static func visitor() -> bool:
	return kind == Kind.VISITOR


## The interface font: the project's monospace, or for the handheld a heavy, widely spaced
## cut of it that reads like LCD segments.
static func font() -> Font:
	if _font == null:
		var base: Font = preload("res://ui/theme.tres").default_font
		if visitor():
			var heavy := SystemFont.new()
			heavy.font_names = (base as SystemFont).font_names
			heavy.font_weight = 800
			heavy.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			var spaced := FontVariation.new()
			spaced.base_font = heavy
			spaced.spacing_glyph = 1
			_font = spaced
		else:
			_font = base
	return _font
