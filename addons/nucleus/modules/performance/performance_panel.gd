class_name NucleusPerformancePanel
extends PanelContainer
## Optional development dashboard for NucleusPerformanceSampler.
##
## This HUD is intentionally a high-level diagnostic surface. Godot's native
## Profiler, Network Profiler, and Video RAM tooling remain the deep-dive tools.

@export var sampler_path: NodePath = NodePath("Sampler")
@export var hide_in_release: bool = true
@export_range(1, 12, 1) var max_visible_diagnostics: int = 5
@export_range(5, 120, 5) var trend_seconds: int = 30

const _DIAGNOSTIC_ITEM_SCENE: PackedScene = preload(
	"res://addons/nucleus/modules/performance/ui/performance_diagnostic_item.tscn"
)

const PerformanceMetricCard = preload(
	"res://addons/nucleus/modules/performance/ui/performance_metric_card.gd"
)
const PerformanceMetricRow = preload(
	"res://addons/nucleus/modules/performance/ui/performance_metric_row.gd"
)
const PerformanceDiagnosticItem = preload(
	"res://addons/nucleus/modules/performance/ui/performance_diagnostic_item.gd"
)
const PerformanceTrendGraph = preload(
	"res://addons/nucleus/modules/performance/ui/performance_trend_graph.gd"
)

const _STATE_NONE: int = PerformanceMetricCard.STATE_NONE
const _STATE_NORMAL: int = PerformanceMetricCard.STATE_NORMAL
const _STATE_WARNING: int = PerformanceMetricCard.STATE_WARNING
const _STATE_CRITICAL: int = PerformanceMetricCard.STATE_CRITICAL
const _STATE_INFO: int = 3

const _COLOR_MUTED: Color = Color(0.60, 0.66, 0.73)
const _COLOR_INFO: Color = Color(0.45, 0.70, 0.95)
const _COLOR_NORMAL: Color = Color(0.30, 0.80, 0.54)
const _COLOR_WARNING: Color = Color(0.96, 0.68, 0.24)
const _COLOR_CRITICAL: Color = Color(0.95, 0.33, 0.36)

@onready var _target_label: Label = %Target
@onready var _status_badge: PanelContainer = %GlobalStatusBadge
@onready var _status_label: Label = %GlobalStatus
@onready var _diagnostics_count: Label = %DiagnosticsCount
@onready var _diagnostics_list: GridContainer = %DiagnosticsList
@onready var _diagnostics_empty: Label = %DiagnosticsEmpty
@onready var _hint_label: Label = %Hint

@onready var _fps_card: PerformanceMetricCard = %FpsCard
@onready var _frame_card: PerformanceMetricCard = %FrameCard
@onready var _physics_card: PerformanceMetricCard = %PhysicsCard
@onready var _navigation_card: PerformanceMetricCard = %NavigationCard

@onready var _trend_graph: PerformanceTrendGraph = %TrendGraph
@onready var _trend_stats: Label = %TrendStats
@onready var _trend_window: Label = %TrendWindow
@onready var _trend_thresholds: Label = %TrendThresholds

@onready var _render_draw_calls: PerformanceMetricRow = %RenderDrawCalls
@onready var _render_objects: PerformanceMetricRow = %RenderObjects
@onready var _render_primitives: PerformanceMetricRow = %RenderPrimitives
@onready var _render_video_memory: PerformanceMetricRow = %RenderVideoMemory
@onready var _render_texture_memory: PerformanceMetricRow = %RenderTextureMemory
@onready var _render_buffer_memory: PerformanceMetricRow = %RenderBufferMemory

@onready var _scene_objects: PerformanceMetricRow = %SceneObjects
@onready var _scene_resources: PerformanceMetricRow = %SceneResources
@onready var _scene_nodes: PerformanceMetricRow = %SceneNodes
@onready var _scene_orphans: PerformanceMetricRow = %SceneOrphans
@onready var _scene_static_memory: PerformanceMetricRow = %SceneStaticMemory

@onready var _physics_section: PanelContainer = %PhysicsSection
@onready var _physics_3d_active: PerformanceMetricRow = %Physics3DActive
@onready var _physics_3d_pairs: PerformanceMetricRow = %Physics3DPairs
@onready var _physics_3d_islands: PerformanceMetricRow = %Physics3DIslands
@onready var _physics_2d_active: PerformanceMetricRow = %Physics2DActive
@onready var _physics_2d_pairs: PerformanceMetricRow = %Physics2DPairs
@onready var _physics_2d_islands: PerformanceMetricRow = %Physics2DIslands

@onready var _navigation_section: PanelContainer = %NavigationSection
@onready var _navigation_3d_regions: PerformanceMetricRow = %Navigation3DRegions
@onready var _navigation_3d_agents: PerformanceMetricRow = %Navigation3DAgents
@onready var _navigation_3d_obstacles: PerformanceMetricRow = %Navigation3DObstacles
@onready var _navigation_2d_regions: PerformanceMetricRow = %Navigation2DRegions
@onready var _navigation_2d_agents: PerformanceMetricRow = %Navigation2DAgents
@onready var _navigation_2d_obstacles: PerformanceMetricRow = %Navigation2DObstacles

var _sampler: NucleusPerformanceSampler
var _diagnostic_items: Array[PerformanceDiagnosticItem] = []


func _ready() -> void:
	if hide_in_release and not OS.is_debug_build():
		queue_free()
		return

	_set_mouse_filter_recursive(self)
	_update_hint()
	_set_global_status("WAITING", _STATE_NONE)

	_sampler = get_node_or_null(sampler_path) as NucleusPerformanceSampler
	if _sampler == null:
		_show_sampler_error()
		return

	_sampler.snapshot_sampled.connect(_on_snapshot_sampled)
	_sampler.diagnostics_updated.connect(_on_diagnostics_updated)
	_update_target()

	var snapshot := _sampler.get_latest_snapshot()
	if snapshot != null:
		_on_snapshot_sampled(snapshot)
		_on_diagnostics_updated(_sampler.get_latest_diagnostics())


func _update_target() -> void:
	if _sampler == null or _sampler.profile == null:
		_target_label.text = "Target profile: unconfigured"
		return

	var environment := ""
	if Engine.is_embedded_in_editor():
		environment = " · editor embedded"

	_target_label.text = (
		"%s · %d FPS · %.2f ms target cadence%s"
		% [
			_sampler.profile.target_name,
			_sampler.profile.target_fps,
			_sampler.profile.frame_budget_ms(),
			environment,
		]
	)


func _update_hint() -> void:
	_hint_label.text = (
		"Frame health uses effective FPS and pacing history; TIME_PROCESS is "
		+ "informational. Reports can be compared against a captured baseline."
	)


func _show_sampler_error() -> void:
	_target_label.text = "No NucleusPerformanceSampler found"
	_fps_card.set_metric("FPS", "--", "Sampler unavailable")
	_frame_card.set_metric("PACING P95", "--", "Sampler unavailable")
	_physics_card.set_metric("PHYSICS", "--", "Sampler unavailable")
	_navigation_card.set_metric("NAVIGATION", "--", "Sampler unavailable")
	_set_global_status("NO SAMPLER", _STATE_CRITICAL)
	_diagnostics_count.text = "configuration error"
	_diagnostics_empty.text = (
		"Assign sampler_path or add a Sampler child to PerformancePanel."
	)
	_diagnostics_empty.show()


func _on_snapshot_sampled(snapshot: NucleusPerformanceSnapshot) -> void:
	if snapshot == null:
		return

	var profile := _sampler.profile
	_update_summary_cards(snapshot, profile)
	_update_trend(snapshot, profile)
	_update_rendering(snapshot, profile)
	_update_scene_memory(snapshot, profile)
	_update_physics(snapshot, profile)
	_update_navigation(snapshot, profile)


func _update_summary_cards(
	snapshot: NucleusPerformanceSnapshot,
	profile: NucleusPerformanceProfile,
) -> void:
	var native_fps := snapshot.get_metric(NucleusPerformanceMetricIds.FPS)
	var window_fps := snapshot.get_metric(
		NucleusPerformanceMetricIds.WINDOW_FPS,
		native_fps,
	)
	var fps := window_fps if window_fps > 0.0 else native_fps
	var process_ms := snapshot.get_metric(NucleusPerformanceMetricIds.PROCESS_MS)
	var p95_ms := snapshot.get_metric(
		NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS
	)
	var physics_ms := snapshot.get_metric(NucleusPerformanceMetricIds.PHYSICS_MS)
	var navigation_ms := snapshot.get_metric(
		NucleusPerformanceMetricIds.NAVIGATION_MS
	)

	if profile == null:
		_fps_card.set_metric("FPS", "%.0f" % fps)
		_frame_card.set_metric(
			"PACING P95",
			"%.2f ms" % p95_ms if p95_ms > 0.0 else "--",
			"Godot TIME_PROCESS %.2f ms" % process_ms,
		)
		_physics_card.set_metric("PHYSICS", "%.2f ms" % physics_ms)
		_navigation_card.set_metric("NAVIGATION", "%.2f ms" % navigation_ms)
		return

	var fps_stats := _sampler.get_metric_statistics(
		NucleusPerformanceMetricIds.WINDOW_FPS,
		profile.frame_evaluation_samples,
	)
	var fps_for_state := fps
	var fps_samples := int(fps_stats.get("samples", 0))
	var fps_detail := "Target %d FPS" % profile.target_fps
	if fps_samples > 0:
		fps_for_state = float(fps_stats.get("average", fps))
		fps_detail += " · avg %.1f" % fps_for_state

	var fps_state := _STATE_NONE
	if fps_samples >= profile.frame_evaluation_samples:
		fps_state = _fps_state(fps_for_state, profile)

	_fps_card.set_metric(
		"FPS",
		"%.0f" % fps,
		fps_detail,
		-1.0,
		fps_state,
	)

	if p95_ms > 0.0:
		var warning_ms := profile.frame_budget_ms() * profile.pacing_warning_ratio
		var pacing_stats := _sampler.get_metric_statistics(
			NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS,
			profile.frame_evaluation_samples,
		)
		var pacing_for_state := p95_ms
		var pacing_samples := int(pacing_stats.get("samples", 0))
		if pacing_samples > 0:
			pacing_for_state = float(pacing_stats.get("average", p95_ms))

		var pacing_state := _STATE_NONE
		if pacing_samples >= profile.frame_evaluation_samples:
			pacing_state = _pacing_state(pacing_for_state, profile)

		_frame_card.set_metric(
			"PACING P95",
			"%.2f ms" % p95_ms,
			"target %.2f ms · warn > %.2f ms" % [
				profile.frame_budget_ms(),
				warning_ms,
			],
			-1.0,
			pacing_state,
		)
	else:
		_frame_card.set_metric(
			"PACING P95",
			"--",
			"Collecting frame window · TIME_PROCESS %.2f ms" % process_ms,
		)

	_update_budget_card(
		_physics_card,
		"PHYSICS",
		physics_ms,
		profile.max_physics_ms,
	)
	_update_budget_card(
		_navigation_card,
		"NAVIGATION",
		navigation_ms,
		profile.max_navigation_ms,
	)


func _update_trend(
	snapshot: NucleusPerformanceSnapshot,
	profile: NucleusPerformanceProfile,
) -> void:
	if _sampler == null:
		_trend_graph.clear_series()
		return

	var interval := maxf(_sampler.sample_interval_seconds, 0.1)
	var sample_count := maxi(2, int(ceil(float(trend_seconds) / interval)))
	var p50 := _sampler.get_metric_series(
		NucleusPerformanceMetricIds.FRAME_INTERVAL_P50_MS,
		sample_count,
		true,
	)
	var p95 := _sampler.get_metric_series(
		NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS,
		sample_count,
		true,
	)
	var maximum := _sampler.get_metric_series(
		NucleusPerformanceMetricIds.FRAME_INTERVAL_MAX_MS,
		sample_count,
		true,
	)

	var target_ms := 0.0
	var warning_ms := 0.0
	var critical_ms := 0.0
	if profile != null:
		target_ms = profile.frame_budget_ms()
		warning_ms = target_ms * profile.pacing_warning_ratio
		critical_ms = target_ms * profile.pacing_critical_ratio

	_trend_graph.set_series(
		p50,
		p95,
		maximum,
		target_ms,
		warning_ms,
		critical_ms,
	)

	var current_p50 := snapshot.get_metric(
		NucleusPerformanceMetricIds.FRAME_INTERVAL_P50_MS
	)
	var current_p95 := snapshot.get_metric(
		NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS
	)
	var current_max := snapshot.get_metric(
		NucleusPerformanceMetricIds.FRAME_INTERVAL_MAX_MS
	)
	if current_p95 > 0.0:
		_trend_stats.text = "P50 %.2f · P95 %.2f · MAX %.2f ms" % [
			current_p50,
			current_p95,
			current_max,
		]
	else:
		_trend_stats.text = "Collecting pacing history..."

	var visible_seconds := minf(
		float(trend_seconds),
		float(maxi(p95.size(), 1)) * interval,
	)
	_trend_window.text = "%.0f s" % visible_seconds

	if profile == null:
		_trend_thresholds.text = "No pacing target configured"
	else:
		_trend_thresholds.text = (
			"target %.2f ms · warning %.2f ms · critical %.2f ms"
			% [target_ms, warning_ms, critical_ms]
		)


func _update_budget_card(
	card: PerformanceMetricCard,
	title: String,
	value_ms: float,
	budget_ms: float,
) -> void:
	if budget_ms <= 0.0:
		card.set_metric(
			title,
			"%.2f ms" % value_ms,
			"Budget not configured",
		)
		return

	var ratio := value_ms / maxf(budget_ms, 0.001)
	var state := _STATE_WARNING if ratio > 1.0 else _STATE_NORMAL
	card.set_metric(
		title,
		"%.2f ms" % value_ms,
		"%.0f%% of %.2f ms budget" % [ratio * 100.0, budget_ms],
		ratio,
		state,
	)


func _update_rendering(
	snapshot: NucleusPerformanceSnapshot,
	profile: NucleusPerformanceProfile,
) -> void:
	var draw_calls := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.RENDER_DRAW_CALLS)
	)
	var render_objects := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.RENDER_OBJECTS)
	)
	var primitives := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.RENDER_PRIMITIVES)
	)
	var video_memory := snapshot.get_metric(
		NucleusPerformanceMetricIds.VIDEO_MEMORY_BYTES
	)
	var texture_memory := snapshot.get_metric(
		NucleusPerformanceMetricIds.TEXTURE_MEMORY_BYTES
	)
	var buffer_memory := snapshot.get_metric(
		NucleusPerformanceMetricIds.BUFFER_MEMORY_BYTES
	)

	var max_draw_calls := profile.max_draw_calls if profile != null else 0
	var max_render_objects := profile.max_render_objects if profile != null else 0
	var max_primitives := profile.max_primitives if profile != null else 0
	var max_video_mb := profile.max_video_memory_mb if profile != null else 0.0

	_render_draw_calls.set_metric(
		"Draw calls",
		_format_count(draw_calls),
		_format_count_budget(max_draw_calls),
		_state_for_max(float(draw_calls), float(max_draw_calls)),
	)
	_render_objects.set_metric(
		"Render objects",
		_format_count(render_objects),
		_format_count_budget(max_render_objects),
		_state_for_max(float(render_objects), float(max_render_objects)),
	)
	_render_primitives.set_metric(
		"Primitives",
		_format_count(primitives),
		_format_count_budget(max_primitives),
		_state_for_max(float(primitives), float(max_primitives)),
	)

	var video_budget_bytes := max_video_mb * 1048576.0
	_render_video_memory.set_metric(
		"Video memory",
		_format_bytes(video_memory),
		_format_memory_budget(max_video_mb),
		_state_for_max(video_memory, video_budget_bytes),
	)
	_render_texture_memory.set_metric(
		"Texture memory",
		_format_bytes(texture_memory),
	)
	_render_buffer_memory.set_metric(
		"Buffer memory",
		_format_bytes(buffer_memory),
	)


func _update_scene_memory(
	snapshot: NucleusPerformanceSnapshot,
	profile: NucleusPerformanceProfile,
) -> void:
	var objects := int(snapshot.get_metric(NucleusPerformanceMetricIds.OBJECT_COUNT))
	var resources := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.RESOURCE_COUNT)
	)
	var nodes := int(snapshot.get_metric(NucleusPerformanceMetricIds.NODE_COUNT))
	var orphans := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.ORPHAN_NODE_COUNT)
	)
	var static_memory := snapshot.get_metric(
		NucleusPerformanceMetricIds.STATIC_MEMORY_BYTES
	)

	var max_nodes := profile.max_node_count if profile != null else 0
	var max_orphans := profile.max_orphan_nodes if profile != null else -1
	var max_static_mb := profile.max_static_memory_mb if profile != null else 0.0

	_scene_objects.set_metric("Objects", _format_count(objects))
	_scene_resources.set_metric("Resources", _format_count(resources))
	_scene_nodes.set_metric(
		"Nodes",
		_format_count(nodes),
		_format_count_budget(max_nodes),
		_state_for_max(float(nodes), float(max_nodes)),
	)

	var orphan_budget := ""
	var orphan_state := _STATE_NONE
	if max_orphans >= 0:
		orphan_budget = "max %d" % max_orphans
		orphan_state = (
			_STATE_WARNING if orphans > max_orphans else _STATE_NORMAL
		)
	_scene_orphans.set_metric(
		"Orphan nodes",
		_format_count(orphans),
		orphan_budget,
		orphan_state,
	)

	var static_budget_bytes := max_static_mb * 1048576.0
	_scene_static_memory.set_metric(
		"Static memory",
		_format_bytes(static_memory),
		_format_memory_budget(max_static_mb),
		_state_for_max(static_memory, static_budget_bytes),
	)


func _update_physics(
	snapshot: NucleusPerformanceSnapshot,
	profile: NucleusPerformanceProfile,
) -> void:
	var active_3d := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.PHYSICS_3D_ACTIVE)
	)
	var pairs_3d := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.PHYSICS_3D_PAIRS)
	)
	var islands_3d := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.PHYSICS_3D_ISLANDS)
	)
	var active_2d := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.PHYSICS_2D_ACTIVE)
	)
	var pairs_2d := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.PHYSICS_2D_PAIRS)
	)
	var islands_2d := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.PHYSICS_2D_ISLANDS)
	)

	var max_active_3d := (
		profile.max_physics_3d_active_objects if profile != null else 0
	)
	var max_pairs_3d := (
		profile.max_physics_3d_collision_pairs if profile != null else 0
	)
	var max_active_2d := (
		profile.max_physics_2d_active_objects if profile != null else 0
	)
	var max_pairs_2d := (
		profile.max_physics_2d_collision_pairs if profile != null else 0
	)

	_physics_3d_active.set_metric(
		"3D active bodies",
		_format_count(active_3d),
		_format_count_budget(max_active_3d),
		_state_for_max(float(active_3d), float(max_active_3d)),
	)
	_physics_3d_pairs.set_metric(
		"3D collision pairs",
		_format_count(pairs_3d),
		_format_count_budget(max_pairs_3d),
		_state_for_max(float(pairs_3d), float(max_pairs_3d)),
	)
	_physics_3d_islands.set_metric("3D islands", _format_count(islands_3d))

	_physics_2d_active.set_metric(
		"2D active bodies",
		_format_count(active_2d),
		_format_count_budget(max_active_2d),
		_state_for_max(float(active_2d), float(max_active_2d)),
	)
	_physics_2d_pairs.set_metric(
		"2D collision pairs",
		_format_count(pairs_2d),
		_format_count_budget(max_pairs_2d),
		_state_for_max(float(pairs_2d), float(max_pairs_2d)),
	)
	_physics_2d_islands.set_metric("2D islands", _format_count(islands_2d))

	var relevant_3d := (
		active_3d > 0
		or pairs_3d > 0
		or islands_3d > 0
		or max_active_3d > 0
		or max_pairs_3d > 0
	)
	var relevant_2d := (
		active_2d > 0
		or pairs_2d > 0
		or islands_2d > 0
		or max_active_2d > 0
		or max_pairs_2d > 0
	)

	_physics_3d_active.visible = relevant_3d
	_physics_3d_pairs.visible = relevant_3d
	_physics_3d_islands.visible = relevant_3d
	_physics_2d_active.visible = relevant_2d
	_physics_2d_pairs.visible = relevant_2d
	_physics_2d_islands.visible = relevant_2d
	_physics_section.visible = relevant_3d or relevant_2d


func _update_navigation(
	snapshot: NucleusPerformanceSnapshot,
	profile: NucleusPerformanceProfile,
) -> void:
	var regions_3d := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.NAVIGATION_3D_REGIONS)
	)
	var agents_3d := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.NAVIGATION_3D_AGENTS)
	)
	var obstacles_3d := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.NAVIGATION_3D_OBSTACLES)
	)
	var regions_2d := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.NAVIGATION_2D_REGIONS)
	)
	var agents_2d := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.NAVIGATION_2D_AGENTS)
	)
	var obstacles_2d := int(
		snapshot.get_metric(NucleusPerformanceMetricIds.NAVIGATION_2D_OBSTACLES)
	)

	var max_agents_3d := (
		profile.max_navigation_3d_agents if profile != null else 0
	)
	var max_agents_2d := (
		profile.max_navigation_2d_agents if profile != null else 0
	)

	_navigation_3d_regions.set_metric("3D regions", _format_count(regions_3d))
	_navigation_3d_agents.set_metric(
		"3D agents",
		_format_count(agents_3d),
		_format_count_budget(max_agents_3d),
		_state_for_max(float(agents_3d), float(max_agents_3d)),
	)
	_navigation_3d_obstacles.set_metric(
		"3D obstacles",
		_format_count(obstacles_3d),
	)

	_navigation_2d_regions.set_metric("2D regions", _format_count(regions_2d))
	_navigation_2d_agents.set_metric(
		"2D agents",
		_format_count(agents_2d),
		_format_count_budget(max_agents_2d),
		_state_for_max(float(agents_2d), float(max_agents_2d)),
	)
	_navigation_2d_obstacles.set_metric(
		"2D obstacles",
		_format_count(obstacles_2d),
	)

	var relevant_3d := (
		regions_3d > 0
		or agents_3d > 0
		or obstacles_3d > 0
		or max_agents_3d > 0
	)
	var relevant_2d := (
		regions_2d > 0
		or agents_2d > 0
		or obstacles_2d > 0
		or max_agents_2d > 0
	)

	_navigation_3d_regions.visible = relevant_3d
	_navigation_3d_agents.visible = relevant_3d
	_navigation_3d_obstacles.visible = relevant_3d
	_navigation_2d_regions.visible = relevant_2d
	_navigation_2d_agents.visible = relevant_2d
	_navigation_2d_obstacles.visible = relevant_2d
	_navigation_section.visible = relevant_3d or relevant_2d


func _on_diagnostics_updated(
	diagnostics: Array[NucleusPerformanceDiagnostic],
) -> void:
	var visible_count := mini(diagnostics.size(), max_visible_diagnostics)
	_ensure_diagnostic_pool(visible_count)

	for index: int in range(_diagnostic_items.size()):
		var item := _diagnostic_items[index]
		if index < visible_count:
			item.set_diagnostic(diagnostics[index])
		else:
			item.hide()

	_diagnostics_empty.visible = diagnostics.is_empty()
	if diagnostics.is_empty():
		_diagnostics_empty.text = "No active performance diagnostics."
		_diagnostics_count.text = "0 active"
	else:
		_diagnostics_count.text = "%d active" % diagnostics.size()
		if diagnostics.size() > visible_count:
			_diagnostics_count.text += " · %d shown" % visible_count

	_update_global_status(diagnostics)


func _ensure_diagnostic_pool(count: int) -> void:
	while _diagnostic_items.size() < count:
		var item := (
			_DIAGNOSTIC_ITEM_SCENE.instantiate()
			as PerformanceDiagnosticItem
		)
		_diagnostics_list.add_child(item)
		_set_mouse_filter_recursive(item)
		_diagnostic_items.append(item)


func _update_global_status(
	diagnostics: Array[NucleusPerformanceDiagnostic],
) -> void:
	if diagnostics.is_empty():
		_set_global_status("HEALTHY", _STATE_NORMAL)
		return

	var highest_severity := NucleusPerformanceDiagnostic.Severity.INFO
	for diagnostic: NucleusPerformanceDiagnostic in diagnostics:
		highest_severity = maxi(highest_severity, diagnostic.severity)

	match highest_severity:
		NucleusPerformanceDiagnostic.Severity.CRITICAL:
			_set_global_status("CRITICAL", _STATE_CRITICAL)
		NucleusPerformanceDiagnostic.Severity.WARNING:
			_set_global_status("WARNING", _STATE_WARNING)
		_:
			_set_global_status("INFO", _STATE_INFO)


func _set_global_status(text: String, state: int) -> void:
	var color := _COLOR_MUTED
	match state:
		_STATE_NORMAL:
			color = _COLOR_NORMAL
		_STATE_WARNING:
			color = _COLOR_WARNING
		_STATE_CRITICAL:
			color = _COLOR_CRITICAL
		_STATE_INFO:
			color = _COLOR_INFO

	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)
	_status_badge.add_theme_stylebox_override(
		"panel",
		_build_badge_style(color),
	)


func _build_badge_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		color.r * 0.12,
		color.g * 0.12,
		color.b * 0.12,
		0.96,
	)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(color.r, color.g, color.b, 0.72)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style


func _set_mouse_filter_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child: Node in node.get_children():
		_set_mouse_filter_recursive(child)


func _fps_state(
	fps: float,
	profile: NucleusPerformanceProfile,
) -> int:
	if profile == null or profile.target_fps <= 0 or fps <= 0.0:
		return _STATE_NONE

	var target := float(profile.target_fps)
	if fps < target * profile.fps_critical_ratio:
		return _STATE_CRITICAL
	if fps < target * profile.fps_warning_ratio:
		return _STATE_WARNING
	return _STATE_NORMAL


func _pacing_state(
	p95_ms: float,
	profile: NucleusPerformanceProfile,
) -> int:
	if profile == null or p95_ms <= 0.0:
		return _STATE_NONE

	var budget_ms := profile.frame_budget_ms()
	if p95_ms >= budget_ms * profile.pacing_critical_ratio:
		return _STATE_CRITICAL
	if p95_ms >= budget_ms * profile.pacing_warning_ratio:
		return _STATE_WARNING
	return _STATE_NORMAL


func _state_for_max(value: float, maximum: float) -> int:
	if maximum <= 0.0:
		return _STATE_NONE
	return _STATE_WARNING if value > maximum else _STATE_NORMAL


func _format_count_budget(maximum: int) -> String:
	if maximum <= 0:
		return ""
	return "max %s" % _format_count(maximum)


func _format_memory_budget(maximum_mb: float) -> String:
	if maximum_mb <= 0.0:
		return ""
	return "max %s" % _format_bytes(maximum_mb * 1048576.0)


func _format_count(value: int) -> String:
	var absolute := absi(value)
	if absolute >= 1000000000:
		return "%.2f B" % (float(value) / 1000000000.0)
	if absolute >= 1000000:
		return "%.2f M" % (float(value) / 1000000.0)
	if absolute >= 10000:
		return "%.1f K" % (float(value) / 1000.0)
	return "%d" % value


func _format_bytes(bytes: float) -> String:
	if bytes >= 1073741824.0:
		return "%.2f GiB" % (bytes / 1073741824.0)
	if bytes >= 1048576.0:
		return "%.1f MiB" % (bytes / 1048576.0)
	if bytes >= 1024.0:
		return "%.1f KiB" % (bytes / 1024.0)
	return "%d B" % int(bytes)
