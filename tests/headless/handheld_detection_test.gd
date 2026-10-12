extends "res://tests/headless/test_case.gd"

func run() -> Dictionary:
	var deck := NucleusHandheldDetector.classify({
		"os_name": "Linux", "sys_vendor": "Valve", "product_name": "Jupiter",
	})
	expect_equal(deck["family"], &"steam_deck", "Jupiter identified.")
	expect_equal(deck["confidence"], &"confirmed", "DMI is strong evidence.")
	var oled := NucleusHandheldDetector.classify({
		"os_name": "Linux", "sys_vendor": "Valve", "product_name": "Galileo",
	})
	expect_equal(oled["model"], "Steam Deck OLED", "OLED board identified.")
	for host: String in ["Windows", "Linux"]:
		var ally := NucleusHandheldDetector.classify({
			"os_name": host, "model": "ASUS ROG Ally",
		})
		expect_equal(ally["family"], &"rog_ally", "Ally detected on either OS.")
		var x := NucleusHandheldDetector.classify({
			"os_name": host, "sys_vendor": "ASUSTeK", "product_name": "RC72LA",
		})
		expect_equal(x["model"], "ROG Ally X", "Ally X DMI identified.")
	for sample: Dictionary in [
		{"os_name": "Linux", "distribution": "SteamOS"},
		{"os_name": "Windows", "processor": "Ryzen Z1 Extreme"},
		{"os_name": "Windows", "model": "ASUS ROG Strix Laptop"},
		{"os_name": "Linux", "gpu": "AMD Radeon Graphics"},
		{"os_name": "Android", "model": "Steam Deck"},
		{"os_name": "Windows", "product_name": "RC71L", "sys_vendor": "ACME"},
	]:
		expect_false(NucleusHandheldDetector.classify(sample)["is_handheld"],
			"Weak hints must not count as known handhelds.")
	var probable := NucleusHandheldDetector.classify({
		"os_name": "Linux", "gpu": "RADV VANGOGH",
	})
	expect_equal(probable["confidence"], &"probable", "GPU alone is not confirmation.")
	for model: String in ["Legion Go", "MSI Claw", "AYANEO 2S", "GPD WIN 4",
		"ONEXPLAYER X1"]:
		expect_true(NucleusHandheldDetector.classify({
			"os_name": "Windows", "model": model,
		})["is_handheld"], "Recognize family: " + model)
	var live: Dictionary = NucleusPlatform.get_handheld_info()
	expect_equal(live["os_name"], OS.get_name(), "Live probe uses Godot host.")
	expect_equal(NucleusPlatform.is_pc_handheld(), bool(live["is_handheld"]),
		"Facade and detector agree.")
	return finish()
