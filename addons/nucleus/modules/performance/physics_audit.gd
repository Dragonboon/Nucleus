class_name NucleusPhysicsAudit
extends RefCounted
## Development-time structural audit for reusable physics cost signals.
##
## The audit reports broad workload indicators. It never changes sleep,
## monitoring, collision layers, shapes, or physics quality automatically.


static func inspect(
	root: Node,
	awake_body_threshold: int = 64,
	no_sleep_threshold: int = 16,
	contact_monitor_threshold: int = 32,
	monitoring_area_threshold: int = 64,
) -> Array[NucleusPerformanceDiagnostic]:
	var diagnostics: Array[NucleusPerformanceDiagnostic] = []
	if root == null:
		return diagnostics

	var rigid_bodies: int = 0
	var awake_bodies: int = 0
	var no_sleep_bodies: int = 0
	var contact_monitors: int = 0
	var monitoring_areas: int = 0

	for node: Node in NucleusNodeUtils.descendants(root, true):
		if node is RigidBody2D:
			var body_2d := node as RigidBody2D
			rigid_bodies += 1
			if not body_2d.sleeping:
				awake_bodies += 1
			if not body_2d.can_sleep:
				no_sleep_bodies += 1
			if body_2d.contact_monitor:
				contact_monitors += 1
		elif node is RigidBody3D:
			var body_3d := node as RigidBody3D
			rigid_bodies += 1
			if not body_3d.sleeping:
				awake_bodies += 1
			if not body_3d.can_sleep:
				no_sleep_bodies += 1
			if body_3d.contact_monitor:
				contact_monitors += 1
		elif node is Area2D:
			if (node as Area2D).monitoring:
				monitoring_areas += 1
		elif node is Area3D:
			if (node as Area3D).monitoring:
				monitoring_areas += 1

	if awake_bodies >= maxi(awake_body_threshold, 1):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"physics_audit_awake_bodies",
				"Many rigid bodies are currently awake",
				"A large awake set can increase broad-phase and solver work.",
				PackedStringArray([
					"Awake rigid bodies: %d" % awake_bodies,
					"Audited rigid bodies: %d" % rigid_bodies,
				]),
				PackedStringArray([
					"Correlate this count with native physics time before changing behavior.",
					"Allow naturally idle bodies to sleep when gameplay permits it.",
				]),
			)
		)

	if no_sleep_bodies >= maxi(no_sleep_threshold, 1):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.WARNING,
				&"physics_audit_sleep_disabled",
				"Sleep is disabled on many rigid bodies",
				"Bodies that can never sleep remain candidates for continuous simulation.",
				PackedStringArray([
					"Rigid bodies with can_sleep=false: %d" % no_sleep_bodies,
				]),
				PackedStringArray([
					"Keep can_sleep=false only where continuous simulation is required.",
					"Use static bodies for geometry that never needs rigid simulation.",
				]),
			)
		)

	if contact_monitors >= maxi(contact_monitor_threshold, 1):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"physics_audit_contact_monitors",
				"Many rigid bodies have contact monitoring enabled",
				"Contact reporting adds bookkeeping beyond ordinary collision response.",
				PackedStringArray([
					"Contact-monitoring rigid bodies: %d" % contact_monitors,
				]),
				PackedStringArray([
					"Disable contact_monitor where no gameplay system consumes contacts.",
					"Prefer focused Areas when overlap semantics are sufficient.",
				]),
			)
		)

	if monitoring_areas >= maxi(monitoring_area_threshold, 1):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"physics_audit_monitoring_areas",
				"Many Areas are actively monitoring overlaps",
				"Dense overlap monitoring can grow pair-management work.",
				PackedStringArray([
					"Monitoring Areas: %d" % monitoring_areas,
				]),
				PackedStringArray([
					"Gate sensors that are irrelevant to current gameplay.",
					"Audit collision layers and masks before reducing physics quality.",
				]),
			)
		)

	return diagnostics
