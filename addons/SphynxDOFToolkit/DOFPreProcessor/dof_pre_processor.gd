extends "res://addons/SphynxDOFToolkit/dof_compositor_effect.gd"
class_name DofPreProcessor

@export_group("Shader Stages")
@export var pre_blur_processor_stage : ShaderStageResource = preload("res://addons/SphynxDOFToolkit/DOFPreProcessor/dof_pre_processor_stage.tres"):
	set(value):
		unsubscribe_shader_stage(pre_blur_processor_stage)
		pre_blur_processor_stage = value
		subscirbe_shader_stage(value)

var custom_depth : StringName = "custom_depth"

func _render_callback_2(render_size : Vector2i, render_scene_buffers : RenderSceneBuffersRD, render_scene_data : RenderSceneDataRD):
	ensure_texture(custom_depth, render_scene_buffers, RenderingDevice.DATA_FORMAT_R32_SFLOAT)
	
	rd.draw_command_begin_label("Pre Blur Processing", Color(1.0, 1.0, 1.0, 1.0))
	
	var float_pre_blur_push_constants: PackedFloat32Array = [
		0,
		0,
		0,
		0,
	]
	
	var int_pre_blur_push_constants : PackedInt32Array = [
	]
	
	var byte_array = float_pre_blur_push_constants.to_byte_array()
	byte_array.append_array(int_pre_blur_push_constants.to_byte_array())
	
	var view_count = render_scene_buffers.get_view_count()
	
	for view in range(view_count):
		var depth_image := render_scene_buffers.get_depth_layer(view)
		var custom_depth_image := render_scene_buffers.get_texture_slice(context, custom_depth, view, 0, 1, 1)
		var scene_data_buffer : RID = render_scene_data.get_uniform_buffer()
		var scene_data_buffer_uniform := RDUniform.new()
		scene_data_buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
		scene_data_buffer_uniform.binding = 5
		scene_data_buffer_uniform.add_id(scene_data_buffer)
		
		var x_groups := floori((render_size.x - 1) / 16 + 1)
		var y_groups := floori((render_size.y - 1) / 16 + 1)
		
		dispatch_stage(pre_blur_processor_stage, 
		[
			get_sampler_uniform(depth_image, 0, false),
			get_image_uniform(custom_depth_image, 1),
			scene_data_buffer_uniform
		],
		byte_array,
		Vector3i(x_groups, y_groups, 1), 
		"Process Depth Buffer", 
		view)
	
	rd.draw_command_end_label()
