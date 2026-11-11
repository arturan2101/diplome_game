class_name LearnedDirector
extends Director
## Placeholder of the learned director (contextual bandit trained offline on bot logs).
## The trained parameters will be read from a JSON file; no ML library runs on the
## phone. Until such a file exists this mode plans exactly like the rule-based
## director, so the LEARNED mode can already be selected, played and logged.

const PARAMETERS_PATH: String = "res://director/learned_params.json"

## Parsed contents of the parameter file; empty while the director is not trained.
var parameters: Dictionary = {}

var _fallback: RuleDirector = null


func _init(enemy_catalog: EnemyCatalog = null, director_settings: DirectorSettings = null) -> void:
	super(enemy_catalog, director_settings)
	_fallback = RuleDirector.new(catalog, settings)
	if FileAccess.file_exists(PARAMETERS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PARAMETERS_PATH))
		if parsed is Dictionary:
			parameters = parsed


func is_trained() -> bool:
	return not parameters.is_empty()


func choose_next(state: PlayerState) -> SectionPlan:
	# TODO(learned director): pick the action with the bandit once parameters exist.
	return _fallback.choose_next(state)
