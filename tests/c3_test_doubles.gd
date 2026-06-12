class_name C3TestDoubles
## Shared test doubles for [C3RestClient] tests.


## Test double for [C3RestClient] that bypasses real HTTP requests.
## Set [member preset_response] before calling any method that triggers a request.
## Inspect [member request_log] after the call to assert which endpoints were called
## and with what bodies. Each entry is:[br]
## [code]{"method": String, "url": String, "body": String, "headers": PackedStringArray}[/code]
## [br]where [code]body[/code] is the raw JSON [String] (possibly empty).
@warning_ignore("missing_tool")
class TestableClient extends C3RestClient:
	## The response returned by the fake HTTP layer. Defaults to an empty success.
	var preset_response := {"ok": true, "body": PackedByteArray()}
	## Ordered log of all requests made.
	## Each entry is:[br]
	## [code]{"method": String, "url": String, "body": String, "headers": PackedStringArray}[/code].
	var request_log: Array[Dictionary] = []

	func _http_request(
		method: int, url: String, headers: PackedStringArray, body: String = ""
	) -> Dictionary:
		request_log.append({
			"method": _HTTP_METHODS.find_key(method),
			"url": url,
			"body": body,
			"headers": headers,
		})
		return preset_response
