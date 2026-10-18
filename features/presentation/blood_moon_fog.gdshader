shader_type canvas_item;
uniform vec4 fog_color : source_color = vec4(0.55,0.008,0.04,1.0);
uniform float opacity=0.23;
uniform float density=0.9;
uniform float speed=0.35;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*vec2(5.0,3.2)+vec2(TIME*speed,-TIME*speed*0.35);
 float mist=noise(p)*0.55+noise(p*2.1+7.0)*0.3+noise(p*4.3)*0.15;
 float edge=pow(length((UV-0.5)*1.3),1.8);
 float wisps=smoothstep(0.25,0.82,mist)*density;
 float ribbon=smoothstep(0.35,0.95,sin(UV.y*14.0+noise(p*0.7)*6.0-TIME*speed))*wisps;
 COLOR=vec4(fog_color.rgb*(0.7+mist*0.9),clamp((0.08+wisps+0.7*ribbon+edge*0.45)*opacity,0.0,0.55));
}
