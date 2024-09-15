#[compute]
#version 450

#define FLT_MAX 3.402823466e+38
#define FLT_MIN 1.175494351e-38

layout(set = 0, binding = 0) uniform sampler2D depth_sampler;
layout(r32f, set = 0, binding = 1) uniform writeonly image2D depth_output;

struct SceneData {
	highp mat4 projection_matrix;
	highp mat4 inv_projection_matrix;
	highp mat4 inv_view_matrix;
	highp mat4 view_matrix;

	// only used for multiview
	highp mat4 projection_matrix_view[2];
	highp mat4 inv_projection_matrix_view[2];
	highp vec4 eye_offset[2];

	// Used for billboards to cast correct shadows.
	highp mat4 main_cam_inv_view_matrix;

	highp vec2 viewport_size;
	highp vec2 screen_pixel_size;

	// Use vec4s because std140 doesn't play nice with vec2s, z and w are wasted.
	highp vec4 directional_penumbra_shadow_kernel[32];
	highp vec4 directional_soft_shadow_kernel[32];
	highp vec4 penumbra_shadow_kernel[32];
	highp vec4 soft_shadow_kernel[32];

	mediump mat3 radiance_inverse_xform;

	mediump vec4 ambient_light_color_energy;

	mediump float ambient_color_sky_mix;
	bool use_ambient_light;
	bool use_ambient_cubemap;
	bool use_reflection_cubemap;

	highp vec2 shadow_atlas_pixel_size;
	highp vec2 directional_shadow_pixel_size;

	uint directional_light_count;
	mediump float dual_paraboloid_side;
	highp float z_far;
	highp float z_near;

	bool roughness_limiter_enabled;
	mediump float roughness_limiter_amount;
	mediump float roughness_limiter_limit;
	mediump float opaque_prepass_threshold;

	bool fog_enabled;
	uint fog_mode;
	highp float fog_density;
	highp float fog_height;
	highp float fog_height_density;

	highp float fog_depth_curve;
	highp float pad;
	highp float fog_depth_begin;

	mediump vec3 fog_light_color;
	highp float fog_depth_end;

	mediump float fog_sun_scatter;
	mediump float fog_aerial_perspective;
	highp float time;
	mediump float reflection_multiplier; // one normally, zero when rendering reflections

	vec2 taa_jitter;
	bool material_uv2_mode;
	float emissive_exposure_normalization;

	float IBL_exposure_normalization;
	bool pancake_shadows;
	uint camera_visible_layers;
	float pass_alpha_multiplier;
};

layout(set = 0, binding = 5, std140) uniform SceneDataBlock {
	SceneData data;
	SceneData prev_data;
}
scene;

layout(push_constant, std430) uniform Params 
{
	float nan1;
	float nan2;
	float nan3;
	float nan4;
} params;

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

float sharp_step(float lower, float upper, float x)
{
	return clamp((x - lower) / (upper - lower), 0, 1);
}

float get_view_depth(float depth)
{
	return 0.;
}

void main() 
{
	ivec2 render_size = ivec2(textureSize(depth_sampler, 0));
	ivec2 uvi = ivec2(gl_GlobalInvocationID.xy);
	if ((uvi.x >= render_size.x) || (uvi.y >= render_size.y)) 
	{
		return;
	}
	// must be on pixel center for whole values (tested)
	vec2 uvn = vec2(uvi + vec2(0.5)) / render_size;
	
	SceneData scene_data = scene.data;
	
	SceneData previous_scene_data = scene.prev_data;

	float depth = textureLod(depth_sampler, uvn, 0.0).x;

	vec4 view_position = inverse(scene_data.projection_matrix) * vec4(uvn * 2.0 - 1.0, depth, 1.0);

	view_position.xyz /= view_position.w;

	float true_depth = -view_position.z;

	imageStore(depth_output, uvi, vec4(true_depth));

#ifdef DEBUG
	imageStore(debug_5_image, uvi, vec4(true_depth / 10));
#endif
}