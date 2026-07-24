class_name ProximityChatSettings
extends Resource

## Distance-based voice falloff for a Chat mic listener.
##
## When [member enabled] is false, chat is open-mic (lobby-style): no distance
## attenuation. When true, remote chat volume uses the range/volume fields below
## (applied by match voice / playback code).

## Master switch. Off = open mic; on = proximity falloff.
@export var enabled: bool = false

@export_group("Range")
## Inside this radius, remote chat stays at [member max_volume_db].
@export_range(0.0, 200.0, 0.1, "or_greater", "suffix:m")
var full_volume_m: float = 8.0

## At this distance volume reaches [member min_volume_db]; farther peers are silent / culled.
@export_range(0.1, 500.0, 0.1, "or_greater", "suffix:m")
var max_range_m: float = 40.0

@export_group("Volume")
## Loudness inside [member full_volume_m]. 0 dB is full scale.
@export_range(-80.0, 24.0, 0.1, "suffix:dB")
var max_volume_db: float = 0.0

## Loudness at [member max_range_m] (floor before cull).
@export_range(-80.0, 0.0, 0.1, "suffix:dB")
var min_volume_db: float = -40.0


## True when proximity falloff should drive chat playback.
func is_active() -> bool:
	return enabled


func _validate_property(property: Dictionary) -> void:
	## Hide tunables while proximity is off so the Inspector only shows the toggle.
	if not enabled and property.name in [
		"full_volume_m",
		"max_range_m",
		"max_volume_db",
		"min_volume_db",
	]:
		property.usage = PROPERTY_USAGE_STORAGE
