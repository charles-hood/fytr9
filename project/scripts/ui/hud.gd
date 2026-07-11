## In-game HUD (plan §11): score, high score, wave, reserve ships, bombs,
## surviving population, difficulty, timed warning banners, the scanner,
## directional screen-edge warning arrows, and the Pulse Bomb flash. Menus
## and the full game-over report arrive in Milestone 5. Kept inside the 5%
## safe margin.
extends CanvasLayer

const ARROW_COLORS := {
	&"abduction": Color("FF6600"),
	&"falling": Color("FFFFCC"),
}

## Pulse Bomb flash decay (alpha per second). Reduced-flash accessibility
## scaling arrives with the Milestone 5 options screen (§4.3, §8).
const FLASH_DECAY := 2.5

var _banner_timer := 0.0
var _warnings: Array[Dictionary] = []

@onready var _score_label: Label = %ScoreLabel
@onready var _high_score_label: Label = %HighScoreLabel
@onready var _population_label: Label = %PopulationLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _lives_label: Label = %LivesLabel
@onready var _bombs_label: Label = %BombsLabel
@onready var _difficulty_label: Label = %DifficultyLabel
@onready var _banner_label: Label = %BannerLabel
@onready var _scanner: Control = %Scanner
@onready var _edge_layer: Control = %EdgeWarnings
@onready var _flash_rect: ColorRect = %FlashRect


func _ready() -> void:
	_banner_label.visible = false
	_flash_rect.color.a = 0.0
	_edge_layer.draw.connect(_draw_edge_warnings)


func _process(delta: float) -> void:
	if _banner_label.visible:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_banner_label.visible = false
	if _flash_rect.color.a > 0.0:
		_flash_rect.color.a = maxf(0.0, _flash_rect.color.a - FLASH_DECAY * delta)


func set_score(total: int) -> void:
	_score_label.text = "SCORE %06d" % total


func set_high_score(total: int) -> void:
	_high_score_label.text = "HI %06d" % total


func set_population(alive: int, total: int) -> void:
	_population_label.text = "SETTLERS %d/%d" % [alive, total]


func set_wave_label(text: String) -> void:
	_wave_label.text = text


## §11 shows reserve lives; the active ship isn't counted.
func set_lives(total_ships: int) -> void:
	_lives_label.text = "SHIPS %d" % maxi(total_ships - 1, 0)


func set_bombs(count: int) -> void:
	_bombs_label.text = "BOMBS %d" % count


func set_difficulty(name: String) -> void:
	_difficulty_label.text = name


func show_banner(text: String, color: Color, duration := 2.0) -> void:
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", color)
	_banner_label.visible = true
	_banner_timer = duration


func flash_screen() -> void:
	_flash_rect.color.a = 0.5


func update_scanner(registry: ThreatRegistry, cam_sim_x: float, world_width: float) -> void:
	_scanner.update_contacts(registry, cam_sim_x, world_width)


func set_edge_warnings(warnings: Array[Dictionary]) -> void:
	_warnings = warnings
	_edge_layer.queue_redraw()


func _draw_edge_warnings() -> void:
	for warning in _warnings:
		var color: Color = ARROW_COLORS.get(warning["kind"], Color.RED)
		var y := 360.0
		if warning["side"] < 0:
			_edge_layer.draw_colored_polygon(PackedVector2Array([
				Vector2(24.0, y - 18.0), Vector2(24.0, y + 18.0), Vector2(4.0, y),
			]), color)
		else:
			_edge_layer.draw_colored_polygon(PackedVector2Array([
				Vector2(1256.0, y - 18.0), Vector2(1256.0, y + 18.0), Vector2(1276.0, y),
			]), color)
