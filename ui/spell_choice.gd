class_name SpellChoice
extends CanvasLayer
## Modal screen for spells.
## open_offers(): choose one of the offered spells (a shrine); "Skip" takes nothing.
## open_replace(): both slots are full, choose which spell to forget for a new one
## (also the second step of open_offers when a new spell is chosen with full slots).
## The game is paused while the screen is open; the screen itself keeps working
## (process mode Always). Esc and the phone's back button mean Back / Skip.

## Emitted when the screen closes; learned is null if no spell was learned.
signal closed(learned: SpellData)

@export var panel: Control
@export var title: Label
## A button per offered spell, or per slot, is created here.
@export var choices: Container
@export var back_button: Button
## Size of one choice button.
@export var choice_size: Vector2 = Vector2(150.0, 64.0)

var _book: SpellBook = null
var _offers: Array[SpellData] = []
## The new spell waiting for a slot.
var _pending: SpellData = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	back_button.pressed.connect(_on_back_pressed)


func is_open() -> bool:
	return panel.visible


## Freed while open (the run ended under it): the pause must not outlive the screen.
func _exit_tree() -> void:
	if is_open():
		get_tree().paused = false


## Shows the offered spells; choosing one learns it (or raises its level).
func open_offers(offers: Array[SpellData], book: SpellBook) -> void:
	_book = book
	_offers = offers
	_pending = null
	_open()
	_show_offers()


## Both slots are full: asks which spell to forget for spell_data.
func open_replace(spell_data: SpellData, book: SpellBook) -> void:
	_book = book
	_offers = []
	_pending = spell_data
	_open()
	_show_replace()


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_open():
		_on_back_pressed()


func _show_offers() -> void:
	title.text = "Choose a spell"
	_clear_choices()
	for spell_data: SpellData in _offers:
		var result: SpellBook.LearnResult = _book.check_learn(spell_data)
		var button: Button = _add_choice("%s\n%s" % [spell_data.display_name, _status(spell_data, result)], spell_data.icon)
		button.disabled = result == SpellBook.LearnResult.MAX_LEVEL
		button.pressed.connect(_on_offer_chosen.bind(spell_data))
	back_button.text = "Skip"
	_focus_first()


func _show_replace() -> void:
	title.text = "Spell slots are full. Forget which spell for %s?" % _pending.display_name
	_clear_choices()
	for slot in SpellBook.SLOT_COUNT:
		var spell: Spell = _book.get_spell(slot)
		if spell == null:
			continue
		var button: Button = _add_choice("Forget %s\nlevel %d" % [spell.data.display_name, spell.level], spell.data.icon)
		button.pressed.connect(_on_slot_chosen.bind(slot))
	back_button.text = "Back" if not _offers.is_empty() else "Keep my spells"
	_focus_first()


func _status(spell_data: SpellData, result: SpellBook.LearnResult) -> String:
	match result:
		SpellBook.LearnResult.LEVELED_UP:
			var level: int = _book.level_of(spell_data.id)
			return "level %d -> %d" % [level, level + 1]
		SpellBook.LearnResult.MAX_LEVEL:
			return "max level"
		SpellBook.LearnResult.SLOTS_FULL:
			return "new, replaces a spell"
	return "new: %s" % spell_data.description


func _on_offer_chosen(spell_data: SpellData) -> void:
	if _book.learn(spell_data) == SpellBook.LearnResult.SLOTS_FULL:
		_pending = spell_data
		_show_replace()
	else:
		_close(spell_data)


func _on_slot_chosen(slot: int) -> void:
	_book.replace(slot, _pending)
	_close(_pending)


func _on_back_pressed() -> void:
	if _pending != null and not _offers.is_empty():
		_pending = null
		_show_offers()
	else:
		_close(null)


func _add_choice(text: String, icon: Texture2D) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.icon = icon
	button.expand_icon = false
	button.custom_minimum_size = choice_size
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choices.add_child(button)
	return button


func _clear_choices() -> void:
	for child: Node in choices.get_children():
		choices.remove_child(child)
		child.queue_free()


func _focus_first() -> void:
	for child: Node in choices.get_children():
		var button: Button = child as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return
	back_button.grab_focus()


func _open() -> void:
	get_tree().paused = true
	panel.visible = true


func _close(learned: SpellData) -> void:
	panel.visible = false
	_clear_choices()
	get_tree().paused = false
	closed.emit(learned)
