class_name CombatRoom
extends RefCounted
## One combat room of a section and where its fight stands: plain data that
## CombatRoomTracker reads and changes.

enum State { WAITING, FIGHTING, CLEARED }

## Index of the room in SectionLayout.room_rects.
var index: int = -1
var rect: Rect2i = Rect2i()
## Door cells walled up while the fight goes on.
var doors: Array[Vector2i] = []
## Enemy entries of the layout (id, cell, room, wave) by wave, first wave first.
var waves: Array[Array] = []
var state: State = State.WAITING
## Index of the next wave to send.
var next_wave: int = 0
## Enemies of this room alive now, and spawn markers still warning.
var alive: int = 0
var warning: int = 0


func is_fighting() -> bool:
	return state == State.FIGHTING
