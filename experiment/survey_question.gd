class_name SurveyQuestion
extends Resource
## One question of the in-game survey, answered on a 1-5 scale.

## Key in the log, e.g. "interest".
@export var id: String = ""
## The question as the player sees it.
@export_multiline var text: String = ""
## What 1 and 5 mean, shown under the ends of the scale.
@export var low_label: String = ""
@export var high_label: String = ""
