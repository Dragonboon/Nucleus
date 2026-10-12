# PC Handheld Detection Lab

Run `handheld_detection_lab.tscn`.

The first selection reports actual Godot/Linux DMI evidence. Other selections
are **simulated**, so developers can verify classifications on a desktop.
Detection never alters quality, FPS, input mapping or platform SDKs.

See `docs/components/handheld_detection.md`.

## Opt-in graphics proposals

Open `handheld_tuning_lab.tscn` to compare three optional tuning Resources
against current NucleusSettings values. Use **Apply** to choose a profile
explicitly and **Undo** to restore that session's values, provided nothing
else has changed them. This does not set TDP, display refresh rate, input
mapping or guaranteed FPS.
