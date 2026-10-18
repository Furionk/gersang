class_name BloodMoonTransition
extends CanvasLayer
## Native visual-only cinematic; the controller supplies its bounded pause clock.
@export var old_frame:TextureRect
@export var shade:ColorRect
@export var headline:Label
@export var subtitle:Label
var age:float=0
var duration:float=2
var style:BattlePhasePresentation
var title_origin:Vector2
func configure(data:BattlePhasePresentation,image:Texture2D,seconds:float)->void:
	layer=20;style=data;duration=maxf(0.01,seconds)
	# Required native scene children remain authorable; no runtime layout rebuild.
	assert(old_frame!=null and shade!=null and headline!=null and subtitle!=null)
	old_frame.texture=image
	headline.text=style.headline
	headline.add_theme_font_size_override("font_size",style.title_size);headline.add_theme_color_override("font_color",style.title_color)
	subtitle.text=style.subtitle;title_origin=headline.position
	advance(0)
func advance(delta:float)->void:
	age+=delta
	var fade:float=clampf(age/maxf(0.05,style.fade_out_seconds),0,1)
	old_frame.modulate=Color(1,1-fade*0.9,1-fade*0.85,1-fade)
	var flash:float=exp(-pow((age-style.fade_out_seconds)/0.10,2.0))*style.flash_opacity
	shade.color=Color(0.45+flash,0.005,0.025,(1-fade)*0.45+flash)
	var reveal:float=smoothstep(0.15,0.5,age)
	var ending:float=1-smoothstep(duration*0.72,duration,age)
	headline.modulate.a=reveal*ending;subtitle.modulate.a=reveal*ending
	var size:Vector2=get_viewport().get_visible_rect().size
	headline.pivot_offset=size*0.5;headline.scale=Vector2.ONE*(1.0+0.16*exp(-age*4))
	headline.position=title_origin+Vector2(sin(age*47),cos(age*39))*maxf(0,1-age)*3
	subtitle.modulate.a=reveal*ending
