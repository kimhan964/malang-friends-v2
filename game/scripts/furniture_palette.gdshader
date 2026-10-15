shader_type canvas_item;
#include "res://scripts/cozy_palette.gdshaderinc"
varying vec4 vertex_tint;
uniform int color_choice=0;
uniform int finish_choice=0;
uniform bool protect_nature=false;
uniform vec4 accent_color : source_color = vec4(1.0);
void vertex() { vertex_tint=COLOR; }
void fragment() {
 vec4 pixel=texture(TEXTURE,UV);
 vec3 quiet=cozy_palette(pixel.rgb);
 float peak=max(quiet.r,max(quiet.g,quiet.b));
 float low=min(quiet.r,min(quiet.g,quiet.b));
 float saturation=(peak-low)/max(peak,0.0001);
 // Bring old orange wood and red upholstery into the new muted palette.
 quiet=mix(vec3(peak),quiet,min(1.0,0.43/max(saturation,0.0001)));
 // Only warm furniture surfaces; preserve glass, plants and dark outlines.
 float surface=smoothstep(0.12,0.30,peak)*(1.0-smoothstep(0.93,0.99,peak));
 surface*=smoothstep(-0.015,0.04,pixel.r-pixel.b);
 if(protect_nature) surface*=smoothstep(-0.025,0.01,pixel.r-pixel.g);
 if(color_choice>0) {
   float light=dot(quiet,vec3(0.2126,0.7152,0.0722));
   quiet=mix(quiet,accent_color.rgb*clamp(light/0.72,0.25,1.18),surface*0.75);
 }
 vec2 p=UV/TEXTURE_PIXEL_SIZE;
 float detail=0.0;
 if(finish_choice==1) detail=sin(p.y*0.06+sin(p.x*0.012)*3.0)*0.020;
 if(finish_choice==2) detail=(sin(p.x*0.18)+sin(p.y*0.18))*0.012;
 if(finish_choice==3) quiet=mix(quiet,vec3(dot(quiet,vec3(0.2126,0.7152,0.0722))),surface*0.08);
 quiet=clamp(quiet+vec3(detail*surface),vec3(0.0),vec3(1.0));
 COLOR=vec4(quiet,pixel.a)*vertex_tint;
}
