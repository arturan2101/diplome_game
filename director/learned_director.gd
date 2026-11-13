class_name LearnedDirector
extends Director
## The learned director: a contextual bandit (LinUCB) trained offline on bot logs by
## training/train_bandit.py. For every action a (BanditActions) it holds a linear model
## of the expected reward, theta_a . x, where x is the player's context (BanditContext).
## It picks the action with the highest score
##     theta_a . x + alpha * sqrt(x^T A_a^-1 x)
## The second term is LinUCB's bonus for actions it knows little about; after offline
## training alpha is 0, so the game does not experiment on players. The parameters are
## read from a JSON file: plain numbers, no ML library runs in the game. Without a valid
## file the director plans like the rules director, so the mode always works.
## Calm start: in the first sections of a run only the actions without a peak and
## without the high budget may win (a mask over the trained model, no retraining).

const PARAMETERS_PATH: String = "res://director/learned_params.json"

## Parsed contents of the parameter file; empty while the director is not trained.
var parameters: Dictionary = {}

var _theta: Array[PackedFloat32Array] = []
## Per action: rows of A_a^-1 (only needed when alpha > 0).
var _a_inverse: Array = []
var _alpha: float = 0.0
var _fallback: RuleDirector = null


func _init(enemy_catalog: EnemyCatalog = null, director_settings: DirectorSettings = null,
		parameters_path: String = PARAMETERS_PATH) -> void:
	super(enemy_catalog, director_settings)
	_fallback = RuleDirector.new(catalog, settings)
	if FileAccess.file_exists(parameters_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(parameters_path))
		if parsed is Dictionary:
			load_parameters(parsed)


## Takes parameters in the format train_bandit.py writes. Returns false (and stays
## untrained) if they do not fit this game's features and actions.
func load_parameters(data: Dictionary) -> bool:
	parameters = {}
	_theta.clear()
	_a_inverse.clear()
	var names: Array = data.get("features", [])
	var theta: Array = data.get("theta", [])
	if names != Array(BanditContext.FEATURE_NAMES) or theta.size() != BanditActions.count(settings):
		push_warning("Learned director parameters do not match the features or actions; using the rules")
		return false
	for row: Array in theta:
		if row.size() != names.size():
			push_warning("Learned director parameters have a row of the wrong size; using the rules")
			_theta.clear()
			return false
		_theta.append(PackedFloat32Array(row))
	_alpha = float(data.get("alpha", 0.0))
	for matrix: Array in data.get("a_inverse", []):
		var rows: Array[PackedFloat32Array] = []
		for row: Array in matrix:
			rows.append(PackedFloat32Array(row))
		_a_inverse.append(rows)
	if _alpha > 0.0 and _a_inverse.size() != _theta.size():
		_alpha = 0.0
	parameters = data
	return true


func is_trained() -> bool:
	return not _theta.is_empty()


func choose_next(state: PlayerState) -> SectionPlan:
	if not is_trained():
		# The experiment config may have replaced the settings after construction.
		_fallback.settings = settings
		return _fallback.choose_next(state)
	var plan: SectionPlan = new_plan(state)
	BanditActions.apply(self, plan, state, best_action(plan.context, allowed_actions(state)))
	return plan


## The actions this state allows: at the calm start of a run only the calm ones
## (BanditActions.is_calm), later all of them (an empty list).
func allowed_actions(state: PlayerState) -> PackedInt32Array:
	return BanditActions.calm_actions(settings) if is_calm_start(state) else PackedInt32Array()


## The action with the highest score for this context (the first one on a tie),
## among the allowed actions; an empty list allows every action.
func best_action(x: PackedFloat32Array, allowed: PackedInt32Array = PackedInt32Array()) -> int:
	var candidates: PackedInt32Array = allowed
	if candidates.is_empty():
		candidates = PackedInt32Array(range(_theta.size()))
	var best: int = candidates[0]
	var best_score: float = -INF
	for action: int in candidates:
		var value: float = score(action, x)
		if value > best_score:
			best_score = value
			best = action
	return best


## Expected reward of an action for this context, plus the exploration bonus.
func score(action: int, x: PackedFloat32Array) -> float:
	var value: float = _dot(_theta[action], x)
	if _alpha > 0.0:
		var rows: Array = _a_inverse[action]
		var spread: float = 0.0
		for i in x.size():
			spread += x[i] * _dot(rows[i], x)
		value += _alpha * sqrt(maxf(spread, 0.0))
	return value


static func _dot(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var total: float = 0.0
	for i in mini(a.size(), b.size()):
		total += a[i] * b[i]
	return total
