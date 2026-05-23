extends Control

@onready var client: C3OpenAIClient = $C3OpenAIClient

func _ready() -> void:
	var ids := await client.get_models()
	print(ids)
	await get_tree().process_frame  # let output flush
	get_tree().quit()
