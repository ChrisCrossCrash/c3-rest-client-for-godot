extends Node

@onready var client: C3RestClient = $C3RestClient

func _ready() -> void:
	var res := await client.request("/todos/1", "GET")
	if not res.ok:
		print("Error: ", str(res.error))
		return

	print(res.raw_body)
