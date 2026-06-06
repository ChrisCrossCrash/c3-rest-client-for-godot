shader_type spatial;

/** 3D noise texture that drives the vertex displacement. The third dimension is used as the time axis so the pattern animates smoothly. */
uniform sampler3D noise_texture_3d : source_color, filter_linear_mipmap, repeat_enable;
/** How far each vertex is pushed outward along its normal. Higher values produce larger, more dramatic bumps. */
uniform float noise_strength : hint_range(0.0, 2.0) = 0.5;
/** How fast the noise pattern animates over time. */
uniform float movement_speed = 1.0;
/** UV step size used when estimating the surface slope for normal recalculation. Smaller values are more accurate but may introduce precision artifacts. */
uniform float normal_eps : hint_range(0.001, 0.05) = 0.01;
/** How strongly the displacement influences the lighting normals. At 0 the surface lights as a smooth sphere; higher values make the bumps more visible under directional light. */
uniform float normal_depth : hint_range(0.0, 4.0) = 1.0;

float get_displacement(vec2 uv, float t) {
    float noise_val = texture(noise_texture_3d, vec3(uv, t)).r;

    // Masking the very top and bottoms of the UV sphere helps avoid issues
    // where the seams don't line up.
    float top_mask    = smoothstep(0.0, 0.1, uv.y);
    float bottom_mask = smoothstep(1.0, 0.9, uv.y);

    return noise_val * noise_strength * top_mask * bottom_mask;
}

void vertex() {
    float t = TIME * movement_speed * 0.05;
    VERTEX += NORMAL * get_displacement(UV, t);
}

void fragment() {
    // The vertex shader displaces each vertex along its original mesh normal,
    // but the fragment stage still sees the original smooth-sphere normals.
    // We recompute normals here by finite-differencing the displacement
    // function (i.e. checking how much the height changes between neighboring
    // UV points — if the surface rises steeply in some direction, the normal
    // should tilt that way too): sample the height at the current UV and at two
    // nearby offsets, then estimate the surface slope in each UV direction.
    // This gives us a perturbed normal that matches the displaced geometry.
    float t = TIME * movement_speed * 0.05;

    float h    = get_displacement(UV, t);
    float h_du = get_displacement(UV + vec2(normal_eps, 0.0), t);
    float h_dv = get_displacement(UV + vec2(0.0, normal_eps), t);

    // Approximate partial derivatives of height with respect to UV coords
    float dh_du = (h_du - h) / normal_eps;
    float dh_dv = (h_dv - h) / normal_eps;

    // Build tangent-space normal; normal_depth scales the XY influence
    // (a larger value makes lighting react more strongly to the displacement)
    vec3 ts_normal = normalize(vec3(
        -dh_du * normal_depth,
        -dh_dv * normal_depth,
        1.0  // Z=1 points straight out before any tilt is applied
    ));

    // Transform the tangent-space normal into view space using the TBN matrix
    // (TANGENT, BINORMAL, NORMAL are all in view space at the fragment stage)
    mat3 TBN = mat3(normalize(TANGENT), normalize(BINORMAL), normalize(NORMAL));
    NORMAL = normalize(TBN * ts_normal);
}