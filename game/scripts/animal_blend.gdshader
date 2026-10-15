shader_type canvas_item;
#include "res://scripts/cozy_palette.gdshaderinc"
uniform sampler2D next_frame : filter_linear;
uniform float frame_mix = 0.0;
uniform bool has_meal = false;
uniform float meal_opacity = 1.0;
uniform bool modern_meal = false;
uniform bool baby_meal = false;
uniform vec4 baby_grip;
uniform sampler2D menu_texture : filter_linear;
uniform vec4 old_rect;
uniform vec4 prop_rect;
uniform vec4 bite_color : source_color;
uniform bool food_bite = true;
uniform bool fur_match=false;
uniform vec3 fur_levels;
uniform vec3 fur_shift0;
uniform vec3 fur_shift1;
uniform vec3 fur_shift2;
uniform bool tone_match=false;
uniform vec4 tone_source0 : source_color;
uniform vec4 tone_source1 : source_color;
uniform vec4 tone_source2 : source_color;
uniform vec4 tone_target0 : source_color;
uniform vec4 tone_target1 : source_color;
uniform vec4 tone_target2 : source_color;
varying vec4 vertex_tint;
vec3 stable_tone(vec3 color) {
 vec3 a=tone_source0.rgb, b=tone_target0.rgb;
 float distance=length(color-a);
 if(length(color-tone_source1.rgb)<distance) {a=tone_source1.rgb;b=tone_target1.rgb;distance=length(color-a);}
 if(length(color-tone_source2.rgb)<distance) {a=tone_source2.rgb;b=tone_target2.rgb;distance=length(color-a);}
 float mask=(1.0-smoothstep(.07,.28,distance))*smoothstep(.10,.22,dot(color,vec3(.2126,.7152,.0722)));
 return clamp(color+(b-a)*mask,vec3(0.0),vec3(1.0));
}
vec3 match_fur(vec3 color) {
 float l=(color.r+color.g+color.b)/3.0;
 float warmth=color.r-color.b;
 float warm_mask=smoothstep(.015,.04,warmth)*(1.0-smoothstep(.35,.40,warmth));
 warm_mask*=smoothstep(-.006,.025,color.g-color.b)*smoothstep(-.02,.025,color.r-color.g);
 warm_mask*=1.0-smoothstep(.01,.04,(color.r-color.g)-2.0*(color.g-color.b));
 warm_mask*=smoothstep(.25,.43,l)*(1.0-smoothstep(.80,.94,l));
 vec3 shift=mix(fur_shift0,fur_shift1,clamp((l-fur_levels.x)/max(.001,fur_levels.y-fur_levels.x),0.0,1.0));
 if(l>fur_levels.y) shift=mix(fur_shift1,fur_shift2,clamp((l-fur_levels.y)/max(.001,fur_levels.z-fur_levels.y),0.0,1.0));
 return clamp(color+shift*warm_mask,vec3(0.0),vec3(1.0));
}
void vertex() { vertex_tint=COLOR; }
void fragment() {
 vec4 a=texture(TEXTURE,UV), b=texture(next_frame,UV);
 float alpha=mix(a.a,b.a,frame_mix);
 vec4 original=vec4(mix(a.rgb*a.a,b.rgb*b.a,frame_mix)/max(alpha,0.00001),alpha);
 if(fur_match) original.rgb=match_fur(original.rgb);
 if(tone_match) original.rgb=stable_tone(original.rgb);
 vec4 c=original;
 if(has_meal) {
   vec2 q=(UV-old_rect.xy)/old_rect.zw;
   vec2 p=(UV-prop_rect.xy)/prop_rect.zw;
   if(p.x>=0.0 && p.x<=1.0 && p.y>=0.0 && p.y<=1.0) {
     vec4 dish=texture(menu_texture,p);
     dish.a*=meal_opacity;
     c=mix(c,dish,dish.a);
     c.a=max(original.a,dish.a);
   }
   float grip=1.0-smoothstep(0.8,1.0,length((q-vec2(1.0,0.57))/vec2(0.19,0.33)));
   if(!food_bite) grip=max(grip,1.0-smoothstep(0.8,1.0,length((q-vec2(0.0,0.57))/vec2(0.19,0.33))));
   if(modern_meal) {
     grip=1.0-smoothstep(.7,1.0,length((q-vec2(1.0,.7))/vec2(.22,.32)));
     if(!food_bite) grip=max(grip,1.0-smoothstep(.7,1.0,length((q-vec2(0.0,.7))/vec2(.22,.32))));
   }
   if(baby_meal) {
     grip=1.0-smoothstep(.7,1.0,length((UV-baby_grip.xy)/baby_grip.zw));
   }
   c=mix(c,original,grip);
   float golden=step(0.72,original.r)*step(original.b,0.36)*step(0.10,original.r-original.g);
   float bite_area=step(old_rect.x-0.15,UV.x)*step(UV.x,old_rect.x+old_rect.z)*step(old_rect.y-0.20,UV.y)*step(UV.y,old_rect.y);
   if(food_bite && !modern_meal && golden*bite_area>0.5) c.rgb=mix(c.rgb,bite_color.rgb,0.88);
 }
 c.rgb=cozy_palette(c.rgb);
 COLOR=c*vertex_tint;
}
