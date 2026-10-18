@tool
class_name MonsterBalanceRefresh
extends RefCounted
## Pure numeric migration: IDs, level, composition, locations and timers never change.
static func apply(context:WorldContext,runtime:Dictionary)->bool:
	if context.paused or not context.state.active_encounter.is_empty():return false
	var changed:bool=false
	var parties:Array=runtime.parties.values().duplicate()
	for slot:Dictionary in runtime.slots.values():
		if not slot.get("pending_party",{}).is_empty():parties.append(slot.pending_party)
	for party:Dictionary in parties:
		var refreshed:bool=false
		for member:Dictionary in party.deployed_units:
			var path:String=member.get("definition_path","")
			if not path.begins_with("res://features/units/data/monsters/") or not ResourceLoader.exists(path):continue
			var data:UnitDefinition=load(path)
			if data.balance_revision<=int(member.get("balance_revision",0)):continue
			var old:Dictionary=member.resolved_stats
			var hp_ratio:float=clampf(float(member.current_hp)/maxf(1,old.health),0,1)
			var mp_ratio:float=clampf(float(member.current_mp)/maxf(1,old.mana),0,1)
			var resolved:Dictionary=PartyBuilder.resolve_member(data,member.level,member.unit_id,member.get("equipment_power",0))
			member.resolved_stats=resolved.resolved_stats;member.rated_power=resolved.rated_power
			member.current_hp=resolved.resolved_stats.health*hp_ratio;member.current_mp=resolved.resolved_stats.mana*mp_ratio
			member.balance_revision=data.balance_revision;refreshed=true;changed=true
		if refreshed:party.total_power=PowerCalculator.make_summary(party).power
	return changed
