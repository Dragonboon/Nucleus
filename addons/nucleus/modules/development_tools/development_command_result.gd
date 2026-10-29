class_name NucleusDevelopmentCommandResult
extends RefCounted
## Normalized outcome returned by development commands.

enum Status {
	SUCCESS,
	WARNING,
	ERROR,
}

var status: Status = Status.SUCCESS
var message: String = ""
var data: Variant


static func success(
	p_message: String = "",
	p_data: Variant = null,
) -> NucleusDevelopmentCommandResult:
	return _build(Status.SUCCESS, p_message, p_data)


static func warning(
	p_message: String,
	p_data: Variant = null,
) -> NucleusDevelopmentCommandResult:
	return _build(Status.WARNING, p_message, p_data)


static func failure(
	p_message: String,
	p_data: Variant = null,
) -> NucleusDevelopmentCommandResult:
	return _build(Status.ERROR, p_message, p_data)


static func _build(
	p_status: Status,
	p_message: String,
	p_data: Variant,
) -> NucleusDevelopmentCommandResult:
	var result := NucleusDevelopmentCommandResult.new()
	result.status = p_status
	result.message = p_message
	result.data = p_data
	return result


func is_success() -> bool:
	return status == Status.SUCCESS


func status_name() -> String:
	match status:
		Status.WARNING:
			return "WARNING"
		Status.ERROR:
			return "ERROR"
		_:
			return "SUCCESS"
