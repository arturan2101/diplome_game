class_name FloorStyleTable
extends Resource
## Floor styles by depth (stage 42): each theme in turn lasts depths_per_style depths,
## and after the last one the first comes again. The game draws the level with
## theme_at(depth); the director buys a floor's own enemies by style_at(depth).

@export var themes: Array[TileTheme] = []
@export var depths_per_style: int = 2
## Styles added in stage 48 (ExperimentConfig.extra_floor_styles): without the flag the
## table is used without_styles(extra_styles), so the older styles keep their depths.
@export var extra_styles: Array[StringName] = []


## The theme of a depth (depth counted from 0), or null without themes.
func theme_at(depth: int) -> TileTheme:
	if themes.is_empty():
		return null
	return themes[(maxi(depth, 0) / maxi(depths_per_style, 1)) % themes.size()]


## The style id of a depth (&"ruins", &"fungal", &"flooded", &"fire"), &"" without themes.
func style_at(depth: int) -> StringName:
	var theme: TileTheme = theme_at(depth)
	return theme.style_id if theme != null else &""


## A copy of the table without the themes of these styles (the same order otherwise).
func without_styles(styles: Array[StringName]) -> FloorStyleTable:
	var copy: FloorStyleTable = duplicate() as FloorStyleTable
	var kept: Array[TileTheme] = []
	for theme: TileTheme in themes:
		if not theme.style_id in styles:
			kept.append(theme)
	copy.themes = kept
	copy.extra_styles = []
	return copy
