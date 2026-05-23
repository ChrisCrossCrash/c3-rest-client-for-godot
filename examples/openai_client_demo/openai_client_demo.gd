extends Control

@onready var client: C3OpenAIClient = $C3OpenAIClient


func _ready() -> void:
	var ids := await client.get_models()
	print(ids)

	var messages = [
		C3OpenAIClient.make_system_msg(
			"You are a funny assistant that only responds in rhymes."
		),
		C3OpenAIClient.make_user_msg("What is the meaning of life?")
	]
	var opts := C3OpenAIClient.ChatOptions.new()
	opts.model = ids[0]
	var completion := await client.chat_completion(messages, opts)
	print(completion.content)

	await get_tree().process_frame  # let output flush
	get_tree().quit()
