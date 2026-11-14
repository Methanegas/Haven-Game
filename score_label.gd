extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text = "Score: " + str(ScoreCounter.score)
	ScoreCounter.score_changed.connect(_on_score_changed)

func _on_score_changed(new_score:int):
	text = "Score: " + str(new_score)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
