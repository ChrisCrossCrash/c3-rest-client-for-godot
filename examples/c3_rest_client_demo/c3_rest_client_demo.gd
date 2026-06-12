extends Node

@onready var client: C3RestClient = $C3RestClient

func _ready() -> void:
	var res := await client.http_get("/todos/1")
	if not res.ok:
		print("Error: ", str(res.error))
		return

	print(res.body)
