# C3 OpenAI-Compatible Client for Godot

A drop-in Godot 4 client node for OpenAI-compatible HTTP APIs. Works with [OpenAI](https://openai.com/api/), [LM Studio](https://lmstudio.ai/), [speaches](https://speaches.ai/), and any other server that speaks the OpenAI REST API.

<img src="./media/banner.jpg" width="100%" alt="GDScript code from the C3 OpenAI Client addon" />

## Features

- Chat completions with vision (image input) support
- Text-to-speech (returns a ready-to-play `AudioStream`)
- Speech-to-text / transcription (`AudioStreamMP3` and `AudioStreamWAV`)
- List available models
- Every method returns a typed response object — check `.ok` to detect failure

## Compatibility

Tested on Godot 4.6.x with automated ([GUT](https://github.com/bitwes/Gut)) and manual tests. Manually verified to work back to Godot 4.0.0.

## Installation

Copy the `c3_openai_client/` directory into your project's `addons/` directory.

## Quick start

1. In your scene, choose **Add Child Node** and search for `C3OpenAIClient`.
2. Set **Base URL** in the Inspector (e.g. `https://api.openai.com/v1`).
3. Reference it from your scene script:

    ```gdscript
    @onready var client: C3OpenAIClient = $C3OpenAIClient

    func _ready() -> void:
        # Get the API key from an environment variable and set it on the client.
		# You can skip this step for servers that don't require authentication.
		client.api_key = OS.get_environment("OPENAI_API_KEY")

		var messages := [
			C3OpenAIClient.make_system_msg("You are a helpful assistant."),
			C3OpenAIClient.make_user_msg("What is the capital of France?"),
		]
		var opts := C3OpenAIClient.ChatOptions.new()
		opts.model = "gpt-5.4-mini"

		var res := await client.chat_completion(messages, opts)
		if res.ok:
			print(res.content)
		else:
			push_error("Chat failed: " + str(res.error))
	```

## Full example

See [`examples/openai_client_demo/openai_client_demo.gd`](examples/openai_client_demo/openai_client_demo.gd) for a complete walkthrough covering model listing, chat, vision, TTS, and STT.
