class_name FilesView
extends HBoxContainer
## The terminal's FILES tab: every document this player has read (see Document), titles
## on the left, the chosen one's text on the right. Up/Down chooses.

var player: Player

var _list := VBoxContainer.new()
var _title: Label
var _text: Label
var _buttons := {} # doc id -> Button
var _shown := ""


func _init() -> void:
	add_theme_constant_override("separation", 18)
	var left := ScrollContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	left.add_child(_list)
	add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	add_child(right)
	_title = InventoryScreen._label("", 18, UiStyle.accent)
	right.add_child(_title)
	right.add_child(InventoryScreen._rule())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_text = InventoryScreen._label("", 15, UiStyle.accent.darkened(0.1))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_text)


## Rebuilds the list from the player's files and shows `doc_id` (or the last one shown).
func open(doc_id := "") -> void:
	for child in _list.get_children():
		child.queue_free()
	_buttons.clear()
	if player.files.is_empty():
		_list.add_child(InventoryScreen._label("NO FILES.", 14, UiStyle.dim.lightened(0.3)))
		_title.text = ""
		_text.text = "Documents you read are kept here."
		return
	for i in player.files.size():
		var id := player.files[i]
		# The handheld numbers its notes.
		var title := "%02d  %s" % [i + 1, Documents.title(id)] if UiStyle.visitor() else Documents.title(id)
		var button := InventoryScreen._button(title, 13)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.focus_entered.connect(_show.bind(id))
		button.pressed.connect(_show.bind(id))
		_list.add_child(button)
		_buttons[id] = button
	var chosen := doc_id if doc_id in player.files else (_shown if _shown in player.files else String(player.files[-1]))
	_show(chosen)
	_buttons[chosen].grab_focus.call_deferred()


func _show(id: String) -> void:
	_shown = id
	_title.text = Documents.title(id)
	_text.text = Documents.text(id)
