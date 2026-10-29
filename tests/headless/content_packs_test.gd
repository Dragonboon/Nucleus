extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_manifest_validation()
	_test_data_mod_policy()
	_test_signature_verification()
	_test_runtime_loader_rejects_patch()
	return finish()


func _test_manifest_validation() -> void:
	var manifest := NucleusContentPackManifest.new()
	manifest.pack_id = &"frozen_north"
	manifest.display_name = "Frozen North"
	manifest.version = "1.2.0"
	manifest.kind = NucleusContentPackTypes.Kind.DLC
	manifest.minimum_game_version = "1.0.0"
	manifest.maximum_game_version = "2.0.0"
	manifest.resource_prefix = "res://content/frozen_north/"
	manifest.archive_sha256 = "a".repeat(64)

	expect_true(
		manifest.validate(true).is_empty(),
		"A well-formed DLC manifest should validate.",
	)
	expect_true(
		manifest.is_game_version_compatible("1.5.0"),
		"Compatible game versions should pass.",
	)
	expect_false(
		manifest.is_game_version_compatible("3.0.0"),
		"Incompatible game versions should fail.",
	)

	manifest.resource_prefix = "res://addons/nucleus/core/"
	expect_false(
		manifest.validate(true).is_empty(),
		"Additive packs must stay inside their declared content namespace.",
	)


func _test_data_mod_policy() -> void:
	var policy := NucleusDataModPolicy.new()

	expect_true(
		policy.is_relative_path_allowed("data/fish.json"),
		"JSON data should be allowed by default.",
	)
	expect_false(
		policy.is_relative_path_allowed("../escape.json"),
		"Path traversal must be rejected.",
	)
	expect_false(
		policy.is_relative_path_allowed("scripts/evil.gd"),
		"GDScript must be rejected for community data mods.",
	)
	expect_false(
		policy.is_relative_path_allowed("scene/evil.tscn"),
		"Godot scenes must be rejected for community data mods.",
	)
	expect_false(
		policy.allow_store_only_zip,
		"Community ZIP ingestion should be opt-in.",
	)


func _test_signature_verification() -> void:
	var crypto := Crypto.new()
	var private_key: CryptoKey = crypto.generate_rsa(2048)
	var public_key := CryptoKey.new()

	expect_equal(
		public_key.load_from_string(
			private_key.save_to_string(true),
			true,
		),
		OK,
		"Public verification key should load.",
	)

	var manifest_bytes: PackedByteArray = (
		"{\"pack_id\":\"signed\"}\n".to_utf8_buffer()
	)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(manifest_bytes)
	var digest: PackedByteArray = context.finish()
	var signature: PackedByteArray = crypto.sign(
		HashingContext.HASH_SHA256,
		digest,
		private_key,
	)

	expect_true(
		NucleusContentPackVerifier.verify_signature(
			manifest_bytes,
			signature,
			public_key,
		),
		"A signature made by the private key should verify publicly.",
	)

	var tampered: PackedByteArray = (
		"{\"pack_id\":\"tampered\"}\n".to_utf8_buffer()
	)
	expect_false(
		NucleusContentPackVerifier.verify_signature(
			tampered,
			signature,
			public_key,
		),
		"Changing the signed manifest must invalidate its signature.",
	)


func _test_runtime_loader_rejects_patch() -> void:
	var manifest := NucleusContentPackManifest.new()
	manifest.pack_id = &"patch_1"
	manifest.display_name = "Patch"
	manifest.version = "1.0.0"
	manifest.kind = NucleusContentPackTypes.Kind.PATCH
	manifest.archive_sha256 = "a".repeat(64)

	var forged_verification := {
		"error": OK,
		"verified": true,
		"manifest": manifest,
		"archive_path": "user://does_not_need_to_exist.pck",
	}

	expect_false(
		NucleusContentPackLoader.mount_verified_additive(
			forged_verification
		),
		"Runtime additive loader must refuse patch-kind packs.",
	)
