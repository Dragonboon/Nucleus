# Lightweight bullet field lab

Open bullet_field_lab.tscn in Godot 4.7.2. Change target_bullet_count,
emission_per_frame, projectile_speed, lifetime and projectile_radius to
evaluate workload under the actual target renderer and hardware.

This fixture creates one NucleusBulletField2D and admits bounded radial
bursts across frames. It logs active bullets and instantaneous FPS every two
seconds. It does not create a DamageReceiver or game-specific bullet entity,
does not certify latency or a minimum FPS, and does not test multiplayer.

Compare this workload to a Godot-native approach (for example, a
MultiMeshInstance2D, GPU particles, or a smaller number of full scene-owned
Area2D projectiles) before choosing a renderer for production. For collision
with many targets, benchmark a spatial broad phase instead of calling the
O(bullets) query once for each target.
