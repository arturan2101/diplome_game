class_name SurveyScreen
extends Control
## The survey after a playtest block: one question per page, answered with five big
## buttons (1-5), so it works with a finger. The player sees only the block number,
## never the director mode. After the last answer the survey goes to the log at once;
## then the screen offers the next block, or thanks the player after the last one.

## Emitted with {question id: 1-5} after the last answer.
signal answered(answers: Dictionary)

@export var header: Label
@export var progress_label: Label
@export var question_panel: Control
@export var question_label: Label
@export var answer_row: Container
@export var low_label: Label
@export var high_label: Label
@export var back_button: Button
@export var next_panel: Control
@export var next_label: Label
@export var next_button: Button
## Size of one answer button.
@export var answer_button_size: Vector2 = Vector2(56.0, 44.0)
@export var lowest_answer: int = 1
@export var highest_answer: int = 5

var questions: Array[SurveyQuestion] = []
var answers: Dictionary = {}

var _index: int = 0
var _recorded: bool = false


func _ready() -> void:
	get_tree().paused = false
	questions = Playtest.settings.questions
	if Playtest.is_active:
		header.text = "Блок %d из %d пройден" % [Playtest.block + 1, Playtest.order.size()]
	for value in range(lowest_answer, highest_answer + 1):
		var button: Button = Button.new()
		button.text = str(value)
		button.custom_minimum_size = answer_button_size
		button.pressed.connect(_on_answer.bind(value))
		answer_row.add_child(button)
	back_button.pressed.connect(_on_back)
	next_button.pressed.connect(_on_next)
	_show(0)


func get_answer_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in answer_row.get_children():
		if child is Button:
			buttons.append(child)
	return buttons


func _show(index: int) -> void:
	_index = index
	question_panel.visible = true
	next_panel.visible = false
	var question: SurveyQuestion = questions[index]
	progress_label.text = "Вопрос %d из %d" % [index + 1, questions.size()]
	question_label.text = question.text
	low_label.text = "%d — %s" % [lowest_answer, question.low_label]
	high_label.text = "%d — %s" % [highest_answer, question.high_label]
	back_button.disabled = index == 0
	# No answer gets the focus: a highlighted button would look like a suggested answer.
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


func _on_answer(value: int) -> void:
	answers[questions[_index].id] = value
	if _index + 1 < questions.size():
		_show(_index + 1)
	else:
		_finish()


func _on_back() -> void:
	if _index > 0:
		_show(_index - 1)


func _finish() -> void:
	if not _recorded:
		_recorded = true
		if Playtest.is_active:
			Playtest.record_survey(answers.duplicate())
		answered.emit(answers.duplicate())
	question_panel.visible = false
	next_panel.visible = true
	if Playtest.is_active and not Playtest.is_last_block():
		next_label.text = "Спасибо! Если нужно, отдохните.\nСледующий блок начнётся по кнопке."
		next_button.text = "Начать следующий блок"
	else:
		next_label.text = "Спасибо за участие!\nМожно вернуть телефон."
		next_button.text = "В меню"
	next_button.grab_focus()


func _on_next() -> void:
	var last: bool = not Playtest.is_active or Playtest.is_last_block()
	if Playtest.is_active:
		Playtest.next_block()
	if last:
		Playtest.return_to_menu()
