extends RefCounted
class_name MechanismChannelIds

const _COLOR_TO_INDEX := {
	"红": 0,
	"绿": 1,
	"蓝": 2,
	"黄": 3,
	"紫": 4,
	"橙": 5,
	"白": 6,
	"黑": 7,
}


static func color_to_channel_id(color_name: String) -> StringName:
	if not _COLOR_TO_INDEX.has(color_name):
		return StringName()
	return StringName(str(_COLOR_TO_INDEX[color_name]))
