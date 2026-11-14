shader_type spatial;
render_mode depth_draw_always, cull_disabled;


uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D tex : source_color, hint_default_black;

uniform float Specular : hint_range(0.0, 1.0) = 0.5;
uniform float Hardness : hint_range(1.0, 511.0, 1.0) = 50.0;
uniform vec3 BaseColor : source_color = vec3(0.05, 0.3, 1.0);
uniform vec3 HighlightColor : source_color = vec3(0.6, 0.9, 1.0);
uniform float Opacity : hint_range(0.0, 1.0) = 0.2;
uniform float refraction : hint_range(10000, 100000) = 60000.0;


uniform vec3 slime_center = vec3(0.0);


mat3 rotation_from_cam_translation(mat4 view_matrix, vec3 camera_position_world, vec3 center_world) {

	vec3 dir1 = vec3(0.0, 0.0, 1.0);  // source
	vec3 dir2 = (view_matrix * vec4(normalize(camera_position_world - center_world), 0.0)).xyz;  // target

	vec3 c = cross(dir1, dir2);
	if (length(c) < 0.0001) {
		return mat3(1.0);
	}

	vec3 axis = normalize(c);

	float cos_angle = clamp(dot(dir1, dir2), -1.0, 1.0);
	float angle = acos(cos_angle);
	float sin_angle = sin(angle);

	// Rodrigues' Rotation Formula
	mat3 rot_matrix = mat3(
		vec3(
			cos_angle + axis.x * axis.x * (1.0 - cos_angle),
			axis.x * axis.y * (1.0 - cos_angle) - axis.z * sin_angle,
			axis.x * axis.z * (1.0 - cos_angle) + axis.y * sin_angle
		),
		vec3(
			axis.y * axis.x * (1.0 - cos_angle) + axis.z * sin_angle,
			cos_angle + axis.y * axis.y * (1.0 - cos_angle),
			axis.y * axis.z * (1.0 - cos_angle) - axis.x * sin_angle
		),
		vec3(
			axis.z * axis.x * (1.0 - cos_angle) - axis.y * sin_angle,
			axis.z * axis.y * (1.0 - cos_angle) + axis.x * sin_angle,
			cos_angle + axis.z * axis.z * (1.0 - cos_angle)
		)
	);

	return rot_matrix;
}


void fragment() {

	NORMAL = rotation_from_cam_translation(VIEW_MATRIX, CAMERA_POSITION_WORLD, slime_center) * NORMAL;

	vec3 refracted = texture(
		screen_texture,
		SCREEN_UV + vec2(-NORMAL.x * VIEWPORT_SIZE.y, NORMAL.y * VIEWPORT_SIZE.x) / refraction
	).rgb + texture(tex, UV).rgb;

	float density = 1.0 - dot(NORMAL, vec3(0.0, 0.0, 1.0));

	ALBEDO = mix(mix(refracted * BaseColor, BaseColor, Opacity), HighlightColor, smoothstep(0.4, 0.7, density));
}


void light() {

	vec3 L = normalize(LIGHT);
	vec3 N = normalize(NORMAL);

	float NdotL = dot(N, L) * ATTENUATION;

	vec3 V = normalize(VIEW);
	vec3 H = normalize(L + V);

	float specular = max(0.0, pow(dot(H, NORMAL), Hardness)) * Specular;
	vec3 finalSpecular = (vec3(specular) * LIGHT_COLOR / PI) * max(0.0, 1.0 - pow(1.0 - NdotL, 20));

	SPECULAR_LIGHT += finalSpecular;
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / PI;
}
