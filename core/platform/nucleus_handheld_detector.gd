class_name NucleusHandheldDetector
extends RefCounted
## Conservative PC handheld identification; no graphics settings or gamepad state.
## classify() accepts injected snapshots for deterministic tests.

const UNKNOWN: StringName = &"unknown"
const STEAM_DECK: StringName = &"steam_deck"
const ROG_ALLY: StringName = &"rog_ally"
const LEGION_GO: StringName = &"legion_go"
const MSI_CLAW: StringName = &"msi_claw"
const AYANEO: StringName = &"ayaneo"
const GPD_WIN: StringName = &"gpd_win"
const ONEXPLAYER: StringName = &"onexplayer"

static func detect() -> Dictionary:
	return classify(collect_evidence())


## Read native hints only once when called, without spawning processes.
static func collect_evidence() -> Dictionary:
	var host: String = OS.get_name()
	var result: Dictionary = {"os_name": host}
	if host not in ["Windows", "Linux"]:
		return result
	result["model"] = OS.get_model_name()
	result["processor"] = OS.get_processor_name()
	result["gpu"] = RenderingServer.get_video_adapter_name()
	if host == "Linux":
		result["distribution"] = OS.get_distribution_name()
		for field: String in [
			"sys_vendor", "product_name", "board_name", "board_vendor",
		]:
			result[field] = _linux_dmi(field)
	return result


## Returns family, model, confidence, source, is_handheld and os_name.
## A Linux distribution, connected gamepad and Ryzen Z1 alone are not devices.
static func classify(evidence: Dictionary) -> Dictionary:
	var host: String = str(evidence.get("os_name", ""))
	var fallback: Dictionary = _result(UNKNOWN, "", &"unknown", "", host)
	if host not in ["Windows", "Linux"]:
		return fallback
	var model: String = _clean(evidence.get("model", ""))
	var product: String = _clean(evidence.get("product_name", ""))
	var board: String = _clean(evidence.get("board_name", ""))
	var vendor: String = _clean(evidence.get("sys_vendor", ""))
	var board_vendor: String = _clean(evidence.get("board_vendor", ""))
	var hardware: String = "%s %s %s" % [model, product, board]
	var vendors: String = vendor + " " + board_vendor
	if hardware.contains("steam deck"):
		return _result(STEAM_DECK, "Steam Deck", &"confirmed", "model_name", host)
	if vendors.contains("valve") and _any(product + " " + board, ["jupiter", "galileo"]):
		var deck: String = "Steam Deck OLED" if (
			_any(product + " " + board, ["galileo"])
		) else "Steam Deck LCD"
		return _result(STEAM_DECK, deck, &"confirmed", "linux_dmi", host)
	var asus: bool = _any(vendors, ["asus", "asustek"])
	if _any(hardware, ["rog ally", "rog xbox ally"]) or (
		asus and _any(product + " " + model, ["rc71l", "rc72la"])
	):
		var ally: String = "ROG Ally"
		if _any(hardware, ["ally x", "rc72la"]):
			ally = "ROG Ally X"
		if hardware.contains("rog xbox ally"):
			ally = "ROG Xbox Ally X" if hardware.contains("ally x") else "ROG Xbox Ally"
		return _result(ROG_ALLY, ally, &"confirmed", "model_name", host)
	for spec: Dictionary in [
		{"family": LEGION_GO, "model": "Legion Go", "match": "legion go"},
		{"family": MSI_CLAW, "model": "MSI Claw", "match": "msi claw"},
		{"family": AYANEO, "model": "AYANEO", "match": "ayaneo"},
		{"family": GPD_WIN, "model": "GPD Win", "match": "gpd win"},
		{"family": ONEXPLAYER, "model": "ONEXPLAYER", "match": "onexplayer"},
	]:
		if hardware.contains(spec["match"]):
			return _result(spec["family"], spec["model"], &"confirmed",
				"model_name", host)
	if host == "Linux":
		var gpu: String = _clean(evidence.get("gpu", ""))
		var cpu: String = _clean(evidence.get("processor", ""))
		if gpu.contains("vangogh") or cpu.contains("custom apu 0405"):
			return _result(STEAM_DECK, "Steam Deck (probable)", &"probable",
				"hardware_signature", host)
	return fallback


static func _result(
	family: StringName, model: String, confidence: StringName,
	source: String, host: String,
) -> Dictionary:
	return {
		"family": family,
		"model": model,
		"confidence": confidence,
		"is_handheld": family != UNKNOWN,
		"source": source,
		"os_name": host,
	}


static func _clean(value: Variant) -> String:
	return str(value).strip_edges().to_lower()


static func _any(value: String, needles: Array) -> bool:
	for term: String in needles:
		if value.contains(term):
			return true
	return false


static func _linux_dmi(field: String) -> String:
	# Fixed field names above; no commands or arbitrary user-controlled paths.
	var path: String = "/sys/class/dmi/id/" + field
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var raw: String = file.get_as_text().strip_edges()
	file.close()
	return raw.substr(0, 128)
