class_name NucleusMobilePermissions
extends RefCounted
## Narrow permission-request boundary for mobile projects.
##
## Permission rationale UI remains game-owned. Android permissions must also be
## declared in the export preset where required.


static func request(permission: String) -> bool:
	var normalized: String = permission.strip_edges()
	if normalized.is_empty():
		return false

	if not NucleusPlatform.is_android():
		return false

	return OS.request_permission(normalized)


static func request_android_dangerous_permissions() -> bool:
	if not NucleusPlatform.is_android():
		return false

	return OS.request_permissions()
