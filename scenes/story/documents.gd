class_name Documents
## The facility's documents (story/documents.json), read through Document pickups and kept
## in the terminal's FILES tab. Like story lines, a document can read differently for each
## role ("subject" / "visitor" instead of "text"), and MetaSave placeholders work. With
## "censored_for": "subject", the Subject gets it redacted (see RoleVisibility): the same
## paper, every word blacked out, so the Visitor has to read it to them.

const PATH := "res://story/documents.json"

static var _all := {}


static func exists(id: String) -> bool:
	return _data().has(id)


static func title(id: String) -> String:
	return _data().get(id, {}).get("title", id.to_upper())


## The text as the local player reads it.
static func text(id: String) -> String:
	var doc: Dictionary = _data().get(id, {})
	var role: String = Session.ROLE_NAMES[Session.local_role()].to_lower()
	var text := MetaSave.format(doc.get(role, doc.get("text", "")))
	if RoleVisibility.censored_locally(doc.get("censored_for", "nobody")):
		return RoleVisibility.censor(text, id.hash(), "█") # blacked out, like a redacted file
	return text


static func _data() -> Dictionary:
	if _all.is_empty():
		_all = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _all
