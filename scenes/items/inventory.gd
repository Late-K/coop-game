class_name Inventory
extends RefCounted
## Fixed-size slot inventory, survival-horror style: few slots, and everything (even keys)
## takes one. Each slot is {"id": String, "count": int}; an empty slot is {}.
## Lives on the owning peer only; the server hands out items via RPC. The same class backs
## the item-box stash, with more slots.

signal changed

## The carried inventory's size.
const SLOT_COUNT := 6

var slots: Array[Dictionary] = []


func _init(slot_count := SLOT_COUNT) -> void:
	for i in slot_count:
		slots.append({})


func count_of(id: String) -> int:
	var total := 0
	for slot in slots:
		if not slot.is_empty() and slot["id"] == id:
			total += slot["count"]
	return total


func has(id: String) -> bool:
	return count_of(id) > 0


## How many of `id` would still fit.
func space_for(id: String) -> int:
	var space := 0
	for slot in slots:
		if slot.is_empty():
			space += Items.max_stack(id)
		elif slot["id"] == id:
			space += Items.max_stack(id) - slot["count"]
	return space


## Adds as many as fit (topping up existing stacks first). Returns how many did not fit.
func add(id: String, count: int) -> int:
	var remaining := count
	for slot in slots:
		if remaining > 0 and not slot.is_empty() and slot["id"] == id:
			var moved := mini(remaining, Items.max_stack(id) - slot["count"])
			slot["count"] += moved
			remaining -= moved
	for i in slots.size():
		if remaining > 0 and slots[i].is_empty():
			var moved := mini(remaining, Items.max_stack(id))
			slots[i] = {"id": id, "count": moved}
			remaining -= moved
	changed.emit()
	return remaining


## Removes up to `count` of `id` (from the last stacks first). Returns how many were removed.
func remove(id: String, count: int) -> int:
	var removed := 0
	for i in range(slots.size() - 1, -1, -1):
		var slot := slots[i]
		if removed < count and not slot.is_empty() and slot["id"] == id:
			var moved := mini(count - removed, slot["count"])
			slot["count"] -= moved
			removed += moved
			if slot["count"] == 0:
				slots[i] = {}
	if removed > 0:
		changed.emit()
	return removed


## Removes up to `count` from one slot. Returns how many were removed.
func remove_from(index: int, count: int) -> int:
	var slot := slots[index]
	if slot.is_empty():
		return 0
	var moved := mini(count, slot["count"])
	slot["count"] -= moved
	if slot["count"] == 0:
		slots[index] = {}
	changed.emit()
	return moved


## Empties a slot and returns what was in it.
func take_slot(index: int) -> Dictionary:
	var slot := slots[index]
	slots[index] = {}
	if not slot.is_empty():
		changed.emit()
	return slot
