# C3 REST Client for Godot

A lightweight, async `Node` for talking to JSON REST APIs from Godot 4 projects. Await a request, check `response.ok`, and use the parsed body — no signal wiring or manual status-code handling.

```gdscript
var res := await client.request("/todos/1", C3RestClient.Method.GET)
if res.ok:
	print(res.json["title"])
else:
	push_error("Request failed: " + str(res.error))
```

## Features

- One `await`-able `request()` method covering `GET`, `HEAD`, `POST`, `PUT`, `DELETE`, `OPTIONS`, and `PATCH`
- Every call returns a typed response object — a single `if not response.ok` check covers transport failures and non-2xx statuses alike
- The body is always available raw on `response.body` and best-effort parsed on `response.json` — on errors too, since REST APIs conventionally return JSON-encoded error details
- Structured `ApiError` values with a `kind` category (`transport`, `http`, `api`, `client`, `cancelled`), the HTTP status, and the server's own error message when one is present
- Node-level `base_headers` for authentication and other standing headers (merged before per-request headers on every call)
- JSON request bodies and URL query strings built from plain `Dictionary` arguments
- A `request_failed` signal for cross-cutting concerns like global error logging

## Compatibility

Tested on Godot 4.6.x with automated ([GUT](https://github.com/bitwes/Gut)) tests.

## Installation

Download the latest release from GitHub and copy the `addons/c3_rest_client-<version>` folder into your project's `addons/` directory. The `C3RestClient` node will then be available in the "Create New Node" dialog.

## Quick start

1. In your scene, choose **Add Child Node** and search for `C3RestClient`.
2. Set **Base URL** in the Inspector (e.g. `https://api.example.com/v1`).
3. Reference it from your scene script:

	```gdscript
	@onready var client: C3RestClient = $C3RestClient

	func _ready() -> void:
		# Set node-level headers for authentication and other standing concerns.
		# These are merged into every request before any per-request headers.
		client.base_headers = PackedStringArray([
			"Authorization: Bearer " + OS.get_environment("EXAMPLE_API_KEY"),
		])

		# GET with a query string: GET /search?q=godot&limit=5
		var res := await client.request("/search", C3RestClient.Method.GET, {}, {"q": "godot", "limit": 5})
		if not res.ok:
			push_error("Search failed: " + str(res.error))
			return
		print(res.json["results"])

		# POST with a JSON body.
		var created := await client.request("/todos", C3RestClient.Method.POST, {"title": "Buy milk"})
		if created.ok:
			print("Created todo %s" % created.json["id"])
	```

## Response body

Every response carries the body in two forms:

- `body: String` — the raw UTF-8 body exactly as the server sent it, on success and failure both
- `json: Variant` — a best-effort JSON decoding of `body`: whatever the JSON parsed to (on any status, including errors), or `null` when the body was empty or not valid JSON

`ok` reflects only the HTTP exchange — a response was received and its status was 2xx. Body content never affects it: a `200` with an HTML body succeeds with `json` left `null`, and a `204 No Content` succeeds with `body` set to `""`. Whether the body is what you hoped for is the caller's call:

```gdscript
var res := await client.http_get("/users/1")
if res.ok and res.json is Dictionary:
	print(res.json["name"])
```

## Error handling

When `res.ok` is `false`, `res.error` is an `ApiError` describing what went wrong. Its `kind` field categorizes the failure:

| `kind`         | Meaning                                                                                                                                              |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `&"transport"` | No usable HTTP response (DNS, connection, TLS, or the request could not start)                                                                       |
| `&"http"`      | A non-2xx status with no parseable API error body                                                                                                    |
| `&"api"`       | The server returned a structured error body — `message`, `code`, and `type` are pulled from a conventional `{"error": {...}}` JSON body when present |
| `&"client"`    | The request was rejected before being sent (e.g. an unsupported HTTP method)                                                                         |
| `&"cancelled"` | The caller aborted the request                                                                                                                       |

Every `ApiError` carries a human-readable `message` and the HTTP `status` (or `0` when not applicable). `str(error)` produces a compact one-line summary suitable for logs. On failures the full error body remains available on the response itself — raw on `res.body` and parsed on `res.json` — so nothing the server said is lost.
