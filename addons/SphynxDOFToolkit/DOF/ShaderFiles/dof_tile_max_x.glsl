#[compute]
#version 450

#define FLT_MAX 3.402823466e+38
#define FLT_MIN 1.175494351e-38

layout(set = 0, binding = 0) uniform sampler2D depth_sampler;
layout(r32f, set = 0, binding = 1) uniform writeonly image2D tile_max_x;

layout(push_constant, std430) uniform Params 
{	
	float nan5;
	float nan6;
	float nan7;
	float nan8;
	int tile_size;
	int nan2;
	int nan3;
	int nan4;
} params;

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;


void main() 
{
	ivec2 render_size = ivec2(textureSize(depth_sampler, 0));
	ivec2 output_size = imageSize(tile_max_x);
	ivec2 uvi = ivec2(gl_GlobalInvocationID.xy);
	ivec2 global_uvi = uvi * ivec2(params.tile_size, 1);
	if ((uvi.x >= output_size.x) || (uvi.y >= output_size.y) || (global_uvi.x >= render_size.x) || (global_uvi.y >= render_size.y))  
	{
		return;
	}

	vec2 uvn = (vec2(global_uvi) + vec2(0.5)) / render_size;

	float max_depth = 0;

	for(int i = 0; i < params.tile_size; i++)
	{
		vec2 current_uv = uvn + vec2(float(i) / render_size.x, 0);
		float depth_sample = textureLod(depth_sampler, current_uv, 0.0).x;
		if(depth_sample > max_depth)
		{
			max_depth = depth_sample;
		}
	}
	imageStore(tile_max_x, uvi, vec4(max_depth));
}