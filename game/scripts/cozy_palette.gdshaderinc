// Shared final color grade: preserve species hues, soften intense accents.
vec3 cozy_palette(vec3 rgb) {
 float luminance=dot(rgb,vec3(0.2126,0.7152,0.0722));
 vec3 quiet=mix(vec3(luminance),rgb,0.90);
 return clamp(quiet*vec3(1.0,0.994,0.982)+vec3(0.004,0.003,0.002),vec3(0.0),vec3(1.0));
}
