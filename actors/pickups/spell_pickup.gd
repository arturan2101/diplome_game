class_name SpellPickup
extends Interactable
## A spell scroll on the floor (it falls out of some chests). Taken with the interact
## button: the player learns the spell, or its level goes up. With both spell slots
## full it emits slots_full, and the game asks which spell to forget; the scroll stays
## until that is decided. A spell already at the top level cannot be taken.

signal slots_full(pickup: SpellPickup)

@export var spell_data: SpellData
@export var sprite: Sprite2D
## Gentle bobbing, so a scroll on the floor is easy to notice.
@export var bob_height: float = 2.0
@export var bob_speed: float = 3.0

var _time: float = 0.0


func _ready() -> void:
	super()
	if sprite != null and spell_data != null:
		sprite.texture = spell_data.icon


func _process(delta: float) -> void:
	_time += delta
	if sprite != null:
		sprite.position.y = sin(_time * bob_speed) * bob_height


func get_prompt() -> String:
	if spell_data == null:
		return ""
	return "Learn [color=#%s]%s[/color]" % [spell_data.color.to_html(false), spell_data.display_name]


func can_interact(player: Player) -> bool:
	return spell_data != null and player.spell_book != null \
			and player.spell_book.check_learn(spell_data) != SpellBook.LearnResult.MAX_LEVEL


func interact(player: Player) -> bool:
	if not can_interact(player):
		return false
	if player.spell_book.learn(spell_data) == SpellBook.LearnResult.SLOTS_FULL:
		slots_full.emit(self)
	else:
		queue_free()
	return true
