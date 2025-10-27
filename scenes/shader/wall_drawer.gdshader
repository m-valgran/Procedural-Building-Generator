shader_type spatial;
uniform sampler2D wall_texture: filter_nearest_mipmap_anisotropic, source_color;
uniform sampler2D detail_texture: filter_nearest_mipmap_anisotropic, source_color;
uniform sampler2D window_texture: filter_nearest, source_color;
uniform sampler2D door_texture: repeat_disable, filter_nearest, source_color;
uniform float cell_w;
uniform float cell_h; 
uniform float total_w;
uniform float total_h;
uniform bool draw_door;

vec2 scale(vec2 uv, float x, float y){
	mat2 scale = mat2(vec2(x, 0.0), vec2(0.0, y));
	uv -= 0.5;
	uv = uv * scale;
	uv += 0.5;
	return uv;
}

vec2 offset(vec2 uv, float x, float y){
	uv.x += x;
	uv.y += y;
	return uv;
}

vec2 grid(vec2 uv, float columns, float rows){
	return fract(vec2(uv.x * columns, uv.y * rows));
}

//float line(vec2 p1, vec2 p2, float width, vec2 uv){
	//float dist = distance(p1, p2);
	//float dist_uv = distance(p1, uv);
	//return 1.0 - floor(1.0 - (width) + 
		//distance (mix(p1, p2, clamp(dist_uv / dist, 0.0, 1.0)),  uv));
//}

// Takes all the black pixels to generate the mask
vec3 mask_from_blacks(vec3 source){
	if(source != vec3(0,0,0)){ source = vec3(1,1,1); }
	return source;
}

// Generates a straight line mask
vec3 generate_linear_mask(
		float cells, 
		float cell_edge, 
		float mask_width, 
		vec3 surface_texture, 
		float axis,
		float mask_pos
	){
	float mask_map = 1.0 / cell_edge / cells;
	float post_axis_crop = mask_map * (mask_pos + mask_width);
	float pre_axis_crop = post_axis_crop - mask_map * mask_width;
	vec3 mask = mask_from_blacks(surface_texture * step(pre_axis_crop,axis));
	mask = mask * step(axis,post_axis_crop);
	return mask;
}

void fragment() {
	float cols = total_w/cell_w;
	float rows = total_h/cell_h;
	
	float pos = 0.0;
	float decor_width = 0.25;
	
	vec3 albedo = texture(wall_texture, scale(UV,cols*cell_w,rows*cell_h)).rgb;
	vec2 uv = grid(UV, cols, rows);
	vec3 windows = texture(window_texture, uv).rgb;
	vec3 window_mask = mask_from_blacks(windows);
	
	vec3 detail = texture(detail_texture, scale(UV,total_w,total_h)).rgb;
	vec3 mask = generate_linear_mask(cols,cell_w,decor_width,albedo,UV.x,pos);
	albedo = mix(albedo,detail,mask);
	mask = generate_linear_mask(cols,cell_w,decor_width,albedo,UV.x,pos + total_w-decor_width);
	albedo = mix(albedo,detail,mask);
	mask = generate_linear_mask(rows,cell_h,decor_width,albedo,UV.y,pos);
	albedo = mix(albedo,detail,mask);
	mask = generate_linear_mask(rows,cell_h,decor_width,albedo,UV.y,pos + total_h-decor_width);
	albedo = mix(albedo,detail,mask);
	
	float door_y_offset = -0.5 * (rows - 1.0);
	uv = offset(scale(UV,cols,rows), 0.0, door_y_offset);
	vec3 door = texture(door_texture, uv).rgb;
	vec3 door_mask = mask_from_blacks(door);
	
	albedo = mix(albedo, windows, window_mask);
	if(draw_door){ albedo = mix(albedo, door, door_mask); }
	
	ALBEDO = albedo;
	SPECULAR = 0.0;
}