class_name NucleusSaveMigrationPipeline
extends RefCounted
## Applies a deterministic chain of save migrations.


static func migrate(
	document: NucleusSaveDocument,
	target_version: int,
	migrations: Array[NucleusSaveMigration],
) -> Error:
	if document.schema_version > target_version:
		return ERR_FILE_UNRECOGNIZED

	while document.schema_version < target_version:
		var migration: NucleusSaveMigration = _find_migration(
			document.schema_version,
			migrations,
		)

		if migration == null:
			return ERR_DOES_NOT_EXIST

		var error: Error = migration.migrate(
			document.payload,
			document.metadata,
		)

		if error != OK:
			return error

		document.schema_version = migration.to_version

		if document.schema_version > target_version:
			return ERR_INVALID_DATA

	return OK


static func _find_migration(
	from_version: int,
	migrations: Array[NucleusSaveMigration],
) -> NucleusSaveMigration:
	for migration: NucleusSaveMigration in migrations:
		if migration and migration.from_version == from_version:
			return migration

	return null
