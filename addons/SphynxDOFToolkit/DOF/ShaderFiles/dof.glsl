#[compute]
#version 450

#define FLT_MAX 3.402823466e+38
#define FLT_MIN 1.175494351e-38
#define M_PI 3.1415926535897932384626433832795

layout(set = 0, binding = 0) uniform sampler2D color_sampler;
layout(set = 0, binding = 1) uniform sampler2D depth_sampler;
layout(set = 0, binding = 2) uniform sampler2D neighbor_max;
layout(rgba16f, set = 0, binding = 3) uniform writeonly image2D output_color;


layout(push_constant, std430) uniform Params 
{	
	float focal_distance;
	float focal_amount;
	float maximum_jitter_value;
	float max_focal_amount;
	int tile_size;
	int sample_count;
	int frame;
	int nan4;
} params;

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

const int kernel_side = 9;

const float kernel[] = {
0.0000,	0.0000,	0.0000,	0.0001,	0.0001,	0.0001,	0.0000,	0.0000,	0.0000,
0.0000,	0.0000,	0.0004,	0.0014,	0.0023,	0.0014,	0.0004,	0.0000,	0.0000,
0.0000,	0.0004,	0.0037,	0.0146,	0.0232,	0.0146,	0.0037,	0.0004,	0.0000,
0.0001,	0.0014,	0.0146,	0.0584,	0.0926,	0.0584,	0.0146,	0.0014,	0.0001,
0.0001,	0.0023,	0.0232,	0.0926,	0.1466,	0.0926,	0.0232,	0.0023,	0.0001,
0.0001,	0.0014,	0.0146,	0.0584,	0.0926,	0.0584,	0.0146,	0.0014,	0.0001,
0.0000,	0.0004,	0.0037,	0.0146,	0.0232,	0.0146,	0.0037,	0.0004,	0.0000,
0.0000,	0.0000,	0.0004,	0.0014,	0.0023,	0.0014,	0.0004,	0.0000,	0.0000,
0.0000,	0.0000,	0.0000,	0.0001,	0.0001,	0.0001,	0.0000,	0.0000,	0.0000
};

// Guertin's functions https://research.nvidia.com/sites/default/files/pubs/2013-11_A-Fast-and/Guertin2013MotionBlur-small.pdf
// ----------------------------------------------------------
float z_compare(float a, float b, float sze)
{
	return clamp(1. - sze * (a - b) / min(a, b), 0, 1);
}
// ----------------------------------------------------------

// from https://www.shadertoy.com/view/ftKfzc
// ----------------------------------------------------------
float interleaved_gradient_noise(vec2 uv){
	uv += float(params.frame)  * (vec2(47, 17) * 0.695);

    vec3 magic = vec3( 0.06711056, 0.00583715, 52.9829189 );

    return fract(magic.z * fract(dot(uv, magic.xy)));
}
// ----------------------------------------------------------

// from https://github.com/bradparks/KinoMotion__unity_motion_blur/tree/master
// ----------------------------------------------------------

vec2 jitter_tile(vec2 uvi)
{
	float rx, ry;
	float angle = interleaved_gradient_noise(uvi + vec2(2, 0)) * M_PI * 2;
	rx = cos(angle);
	ry = sin(angle);
	return vec2(rx, ry) / textureSize(neighbor_max, 0) / 4;
}
// ----------------------------------------------------------

void main() 
{
	ivec2 render_size = ivec2(textureSize(color_sampler, 0));
	ivec2 tile_render_size = ivec2(textureSize(neighbor_max, 0));
	ivec2 uvi = ivec2(gl_GlobalInvocationID.xy);
	if ((uvi.x >= render_size.x) || (uvi.y >= render_size.y)) 
	{
		return;
	}

	vec2 x = (vec2(uvi) + vec2(0.5)) / vec2(render_size);

	float n =  textureLod(neighbor_max, x + vec2(params.tile_size / 2) / vec2(render_size) + jitter_tile(uvi), 0.0).x;

	float dn = min(params.max_focal_amount, abs(n - params.focal_distance) * params.focal_amount);

	vec4 base_color = textureLod(color_sampler, x, 0.0);

	float d = textureLod(depth_sampler, x, 0.0).x;

	float dx = min(params.max_focal_amount, abs(d - params.focal_distance) * params.focal_amount);
	
	//float j = interleaved_gradient_noise(uvi) * 2. - 1.;

	float weight = 1e-6;

	vec4 sum = base_color * weight;

	float nai_weight = 1e-6;

	vec4 nai_sum = base_color * nai_weight;

	for(int i = 0; i < kernel_side; i++)
	{
		for(int j = 0; j < kernel_side; j++)
		{
			vec2 sample_offset = (vec2(i, j) - vec2(kernel_side) / 2.0 + vec2(0.5)) / (vec2(kernel_side) / 2.0 - vec2(0.5));
			
			float sample_offset_length = length(sample_offset);

			vec2 sn = x + sample_offset / vec2(render_size)  * dn;
				
			float wsn = sample_offset_length * dn;
			
			float yn = textureLod(depth_sampler, sn, 0.0).x;

			float dyn = min(params.max_focal_amount, abs(yn - params.focal_distance) * params.focal_amount);

			vec2 sx = x + sample_offset / vec2(render_size) * dx;

			float wsx = sample_offset_length * dx;

			float dy = textureLod(depth_sampler, sx, 0.0).x;

			float dyx = min(params.max_focal_amount, abs(dy - params.focal_distance) * params.focal_amount);

			float sn_inside = (sn.x < 0 || sn.x > 1 || sn.y < 0 || sn.y > 1) ? 0 : 1;

			float sx_inside = (sx.x < 0 || sx.x > 1 || sx.y < 0 || sx.y > 1) ? 0 : 1;

			float ay = sn_inside * step(wsn, dyn) * step(yn, d) * (dn / dyn);
			weight += ay;
			sum += textureLod(color_sampler, sn, 0.0) * ay;

//			ay = sx_inside * step(wsx, dyx) * step(dy, d) * step(ay, 0);
//			weight += ay;
//			sum += textureLod(color_sampler, sx, 0.0) * ay;

			float nai_ay = sx_inside * step(d, dy);
			nai_weight += nai_ay;
			nai_sum += textureLod(color_sampler, sx, dyx) * nai_ay;
		}
	}

	sum /= weight;

	weight /= kernel_side * kernel_side;

	nai_sum /= nai_weight;

	sum = mix(nai_sum, sum, weight);
	
	//sum /= weight;

	imageStore(output_color, uvi, sum);
#ifdef DEBUG
	imageStore(debug_1_image, uvi, base_color);
	imageStore(debug_2_image, uvi, vec4(dn));
	imageStore(debug_3_image, uvi, vec4(dx));
#endif
}