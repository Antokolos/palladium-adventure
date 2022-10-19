extends ColorRect

func _ready():
	__PLDRT.settings.connect("image_adjust_changed", self, "_on_image_adjust_changed")
	_on_image_adjust_changed(__PLDRT.settings.use_image_adjust, __PLDRT.settings.brightness, __PLDRT.settings.contrast, __PLDRT.settings.saturation)

func _on_image_adjust_changed(enabled, brightness, contrast, saturation):
	material.set_shader_param("use_image_adjust", enabled)
	material.set_shader_param("brightness", brightness)
	material.set_shader_param("contrast", contrast)
	material.set_shader_param("saturation", saturation)
