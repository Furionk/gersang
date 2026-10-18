@tool
extends EditorInspectorPlugin
const Review=preload("res://addons/skill_authoring/content_review.gd")
const Preview=preload("res://addons/skill_authoring/sprite_preview.gd")
func _can_handle(object:Object) -> bool:
	return object is UnitDefinition or object is SpriteSheetLayout or object is GearItemDefinition or object is SpriteAnimationClip or object is SkillEffectDefinition or object is CombatStatRules or object is MercenaryCatalog or object is UnitTrialEntry
func note(text:String) -> void:
	var label:Label=Label.new(); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.text=text; add_custom_control(label)
func link(title:String,resource:Resource) -> void:
	if resource==null: return
	var button:Button=Button.new(); button.text="開啟 "+title
	button.pressed.connect(func()->void: EditorInterface.edit_resource(resource))
	add_custom_control(button)
func _parse_begin(object:Object) -> void:
	if object is UnitDefinition:
		note("兵種模板只配置資料，不存每隻兵的當前HP。改共用技能會影響所有引用者；只改此兵請複製技能、改獨立ID/Action，再替換Skills引用。")
		var preview:VBoxContainer=Preview.new(); preview.set("data",object)
		var fold:FoldableContainer=FoldableContainer.new(); fold.title="八方向／動作／切圖預覽"; fold.folded=true; fold.add_child(preview); add_custom_control(fold)
		link("切圖／動作",object.sprite_layout)
		link("派生能力规则",object.stat_rules if object.stat_rules!=null else CombatStats.DEFAULT_RULES)
		for skill:SkillDefinition in object.skills:
			if skill!=null: link("技能："+skill.display_name,skill)
		var captions:Dictionary={"portrait_texture":"頭像 Portrait Texture","eyes_texture":"隊伍橫幅 Eyes Texture","standee_texture":"立繪 Standee Texture","voice_profile":"語音 Voice Profile","death_evolution":"死亡進化模板"}
		for field:String in captions: link(captions[field],object.get(field) as Resource)
		var issues:PackedStringArray=Review.unit_issues(object)
		note("資料檢查："+("基本配置有效（不代表平衡已完成）。" if issues.is_empty() else "\n"+"\n".join(issues)))
		var stats:Dictionary=Review.template_stats(object,maxi(1,object.level))
		note("模板Lv%d／無裝備、未配點：HP %.1f、MP %.1f、攻擊 %.1f–%.1f、移速 %.1f。實際傭兵由存檔等級／配點決定；怪物由怪區的成員規則決定。"%[object.level,stats.health,stats.mana,stats.attack_min,stats.attack_max,stats.speed])
		var level_panel:VBoxContainer=VBoxContainer.new()
		var caption:Label=Label.new(); caption.text="等級試算（不改模板／存檔）"; level_panel.add_child(caption)
		var level:SpinBox=SpinBox.new(); level.min_value=1; level.max_value=100; level.value=maxi(1,object.level); level_panel.add_child(level)
		var derived:Label=Label.new(); derived.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; level_panel.add_child(derived)
		var calculate:Callable=func(value:float)->void:
			var values:Dictionary=Review.template_stats(object,int(value))
			derived.text="Lv%d：HP %.1f／MP %.1f\n攻擊 %.1f–%.1f／防禦 %.1f–%.1f\n不含裝備、已分配能力點、戰鬥buff。"%[int(value),values.health,values.mana,values.attack_min,values.attack_max,values.defense_min,values.defense_max]
		level.value_changed.connect(calculate); calculate.call(level.value); add_custom_control(level_panel)
	elif object is SpriteSheetLayout:
		note("每個動作可有不同幀數、FPS及停留權重；舊6×8素材无需重建。改方向映射／鏡像只改圖像，不改實際移動。請保存資源再試玩。")
		var initialize:Button=Button.new(); initialize.text="空白新圖集：初始化等分裁切（可Undo）"
		initialize.disabled=not object.frame_rects.is_empty() or object.source_texture==null
		initialize.tooltip_text="只接受空白Rects，不會重切現有Artist圖集。估計腳底需在預覽逐幀校準。"
		initialize.pressed.connect(func()->void:
			if not object.frame_rects.is_empty() or object.source_texture==null: return
			var values:Dictionary=object.regular_grid_values(Vector2i(object.source_texture.get_size()))
			if values.is_empty(): return
			var undo:EditorUndoRedoManager=EditorInterface.get_editor_undo_redo()
			undo.create_action("初始化新圖集裁切",UndoRedo.MERGE_DISABLE,object)
			for field:String in values:
				undo.add_do_property(object,field,values[field]); undo.add_undo_property(object,field,object.get(field))
			undo.commit_action()
			object.notify_property_list_changed.call_deferred())
		add_custom_control(initialize)
		var preview:VBoxContainer=Preview.new(); preview.set("layout",object); preview.set("texture",object.source_texture)
		if object.source_texture==null:
			for unit:UnitDefinition in UnitResourcePaths.definitions():
				if unit.sprite_layout==object: preview.set("data",unit); break
		var fold:FoldableContainer=FoldableContainer.new(); fold.title="切圖原圖與腳底預覽"; fold.folded=true; fold.add_child(preview); add_custom_control(fold)
	elif object is GearItemDefinition:
		note("裝備Modifiers與Granted Skills是能力来源；食用效果由Use Effect決定，不是只改Description。格數／重量／堆疊與使用效果分開。")
		note("資料檢查："+"；".join(Review.item_issues(object)))
		for skill:SkillDefinition in object.granted_skills:
			if skill!=null: link("裝備技能："+skill.display_name,skill)
	elif object is SkillEffectDefinition:
		note("效果細節資源可能被多個技能共用。公式使用釋放時能力快照。AI嘗試間隔不是冷卻，動畫幀數不是傷害tick數。")
		link("召喚兵種",object.summon_definition)
	elif object is CombatStatRules:
		note("全局或兵種指定的派生規則。預設以20點為能力参考值；體質目前只供技能公式，不直接增加HP，HP由力量／等級規則增加。要改成另一設計需明確調整規則及回歸，不要只改文字。")
	elif object is MercenaryCatalog:
		note("Definitions保留追加兵種目錄。Trials的Friendly／Enemy直接引用任意檔名的兵／怪；此表只提供F2進階試兵，不會加入倉庫。新遊戲名單請改Demo Setup。")
		for entry:UnitTrialEntry in object.trials:
			if entry!=null: link("試兵配對",entry)
	elif object is UnitTrialEntry:
		note("Friendly是按鈕代表的模板；Enemy可留空。敵友可以共用同一張圖，但能力／Skills可用不同UnitDefinition。只改本場，回圖不存入正式編隊。")
		link("友軍模板",object.friendly); link("敵軍模板",object.enemy)
	else: note("動作Columns決定播放順序，可重複／倒序／任意幀數。Frame Durations為相對權重，非秒；此動畫不發放傷害、不限制施法接收。")
