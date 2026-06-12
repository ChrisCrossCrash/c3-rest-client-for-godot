@tool
class_name C3RestClient
extends Node
## Asynchronous client for JSON REST APIs.
##
## Add the node to the scene tree, point [member base_url] at a server, and
## [code]await[/code] [method request]. Every call returns a response object
## carrying [member RestResponse.ok] and a typed [member RestResponse.error],
## so a single [code]if not response.ok[/code] check covers transport failures,
## non-2xx statuses, and malformed bodies alike.


## Emitted when a request fails. The [member RestResponse.ok] field of the
## returned response object is the primary way to detect failure; this signal
## is a secondary broadcast for optional cross-cutting concerns such as global
## error logging.
signal request_failed(error: ApiError)

# HTTP method names accepted by request(), mapped to the HTTPClient constants
# taken by _http_request().
const _HTTP_METHODS: Dictionary = {
	"GET": HTTPClient.METHOD_GET,
	"HEAD": HTTPClient.METHOD_HEAD,
	"POST": HTTPClient.METHOD_POST,
	"PUT": HTTPClient.METHOD_PUT,
	"DELETE": HTTPClient.METHOD_DELETE,
	"OPTIONS": HTTPClient.METHOD_OPTIONS,
	"PATCH": HTTPClient.METHOD_PATCH,
}

## The base URL that every [method request] path is appended to, including any
## API version prefix — for example [code]"https://api.example.com/v1"[/code].
@export var base_url := ""
## When non-empty, sent as a Bearer token in the [code]Authorization[/code]
## header of every request. Leave empty for APIs that need no authentication.
var api_key := ""


## Sends a request to [param path] — appended to [member base_url], with a
## leading [code]"/"[/code] added when missing — using the client's auth and
## JSON headers, and returns the response body parsed but uninterpreted on
## [member RestResponse.raw_body]. [br]
## [param method] is an HTTP method name (case-insensitive): [code]"GET"[/code],
## [code]"HEAD"[/code], [code]"POST"[/code], [code]"PUT"[/code],
## [code]"DELETE"[/code], [code]"OPTIONS"[/code], or [code]"PATCH"[/code]. [br]
## [param body] is sent as the JSON request body; leave empty to send no body
## (as a GET usually would). [br]
## [param query] entries are URL-encoded and appended to the URL as a query
## string; leave empty for none. [br]
## Returns a [RestResponse] with [member RestResponse.ok] set to
## [code]false[/code] and emits [signal request_failed] on failure — including
## when a non-empty 2xx body is not a JSON object. An empty 2xx body (e.g.
## [code]204 No Content[/code]) succeeds with [member RestResponse.raw_body]
## set to [code]{}[/code].
func request(
	path: String, method: String, body: Dictionary = {}, query: Dictionary = {}
) -> RestResponse:
	var res := RestResponse.new()
	var method_int: int = _HTTP_METHODS.get(method.to_upper(), -1)
	if method_int == -1:
		push_error('C3RestClient: Unsupported HTTP method "%s".' % method)
		res.ok = false
		res.error = ApiError.client_error(
			'Unsupported HTTP method "%s".' % method
		)
		return res
	if not path.begins_with("/"):
		path = "/" + path
	var url := base_url + path
	if not query.is_empty():
		url += "?" + HTTPClient.new().query_string_from_dict(query)
	var request_body := "" if body.is_empty() else JSON.stringify(body)
	var response := await _http_request(
		method_int, url, _headers(), request_body
	)
	if not response["ok"]:
		res.ok = false
		res.error = response["error"]
		request_failed.emit(res.error)
		return res
	var body_str := (response["body"] as PackedByteArray).get_string_from_utf8()
	# A bodyless 2xx (e.g. 204 from a DELETE) is a success with nothing to parse.
	if body_str.strip_edges().is_empty():
		return res
	var parser := JSON.new()
	if parser.parse(body_str) != OK:
		res.ok = false
		res.error = ApiError.parse_failure(
			"Failed to parse response body as JSON.", body_str
		)
		request_failed.emit(res.error)
		return res
	var json: Variant = parser.get_data()
	if not json is Dictionary:
		res.ok = false
		res.error = ApiError.parse_failure(
			"Response JSON is not an object.", body_str
		)
		request_failed.emit(res.error)
		return res
	res.raw_body = json
	return res


func _http_request(
	method: int, url: String, headers: PackedStringArray, body: String = ""
) -> Dictionary:
	var req := HTTPRequest.new()
	add_child(req)
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return {
			"ok": false,
			"error":
			ApiError.transport("Failed to start request (error %d)." % err)
		}
	var args: Array = await req.request_completed
	req.queue_free()
	return _process_http_result(args)


# Maps the HTTPRequest.request_completed arguments to the shared response shape:
# {"ok": true, "body": PackedByteArray} on a 2xx response, or
# {"ok": false, "error": ApiError} on a transport failure or non-2xx status.
func _process_http_result(args: Array) -> Dictionary:
	var result: int = args[0]
	var status: int = args[1]
	var resp_body: PackedByteArray = args[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"error":
			ApiError.transport("HTTP transport failed (result %d)." % result)
		}
	if status < 200 or status >= 300:
		return {"ok": false, "error": ApiError.from_response(status, resp_body)}
	return {"ok": true, "body": resp_body}


func _headers() -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
	return headers


## Structured error placed on the [code]error[/code] field of every response
## object when [code]ok[/code] is [code]false[/code], and carried by
## [signal request_failed].
class ApiError:
	## Broad category of failure:[br]
	## [code]&"transport"[/code] — no usable HTTP response (DNS, connection, TLS,
	## or the request could not be started).[br]
	## [code]&"http"[/code] — a non-2xx status with no parseable API error body.[br]
	## [code]&"api"[/code] — the server returned a structured error body.[br]
	## [code]&"parse"[/code] — a 2xx body that could not be understood.[br]
	## [code]&"client"[/code] — the request was rejected before being sent (e.g.
	## an invalid argument).[br]
	## [code]&"cancelled"[/code] — the caller aborted the request.
	var kind := &""
	## Human-readable description. Never empty.
	var message := ""
	## HTTP status code, or [code]0[/code] when not applicable.
	var status := 0
	## Machine-readable API error code (e.g. [code]"invalid_api_key"[/code]), or
	## [code]""[/code] if absent.
	var code := ""
	## API error type (e.g. [code]"invalid_request_error"[/code]), or [code]""[/code].
	var type := ""
	## Raw response body, for debugging. May be [code]""[/code].
	var raw := ""

	## Builds an error for a transport-level failure with no usable HTTP response.
	static func transport(p_message: String) -> ApiError:
		var e := ApiError.new()
		e.kind = &"transport"
		e.message = p_message
		return e

	## Builds an error for a 2xx response whose body could not be understood.
	static func parse_failure(
		p_message: String, p_raw: String = ""
	) -> ApiError:
		var e := ApiError.new()
		e.kind = &"parse"
		e.message = p_message
		e.raw = p_raw
		return e

	## Builds an error for a caller-initiated cancellation.
	static func cancelled(p_message: String) -> ApiError:
		var e := ApiError.new()
		e.kind = &"cancelled"
		e.message = p_message
		return e

	## Builds an error for a request rejected before being sent (bad argument).
	static func client_error(p_message: String) -> ApiError:
		var e := ApiError.new()
		e.kind = &"client"
		e.message = p_message
		return e

	## Builds an error from a non-2xx response, pulling the server's own message,
	## code, and type from a conventional [code]{"error": {...}}[/code] JSON body
	## (the style used by OpenAI and many other APIs) when present. Falls back to
	## a generic HTTP-status message otherwise.
	static func from_response(p_status: int, body: PackedByteArray) -> ApiError:
		var e := ApiError.new()
		e.kind = &"http"
		e.status = p_status
		e.raw = body.get_string_from_utf8()
		e.message = "Request failed with status %d." % p_status
		var parser := JSON.new()
		if parser.parse(e.raw) == OK and parser.get_data() is Dictionary:
			var api_err: Variant = (parser.get_data() as Dictionary).get("error")
			if api_err is Dictionary:
				var d: Dictionary = api_err
				e.kind = &"api"
				if d.get("message") is String:
					e.message = d["message"]
				if d.get("code") is String:
					e.code = d["code"]
				if d.get("type") is String:
					e.type = d["type"]
		return e

	func _to_string() -> String:
		var parts := PackedStringArray(["[%s]" % kind])
		if status != 0:
			parts.append("status=%d" % status)
		if not code.is_empty():
			parts.append("code=%s" % code)
		parts.append(message)
		return " ".join(parts)


## The response returned by [method request].
class RestResponse:
	## [code]true[/code] if the request succeeded.
	var ok := true
	## Populated with error details when [member ok] is [code]false[/code].
	var error: ApiError = null
	## The full parsed response body as a [Dictionary] — [method request] does
	## not interpret it beyond parsing. Populated whenever the server returned a
	## JSON object; [code]{}[/code] when the 2xx body was empty (e.g.
	## [code]204 No Content[/code]) and on transport, HTTP, or non-JSON errors.
	var raw_body := {}
