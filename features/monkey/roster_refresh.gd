@tool
extends RefCounted
## Additive encounter-specific migration. Reserved encounters retain their exact snapshot.
static func apply(context: WorldContext, runtime: Dictionary) -> bool:
	if context.paused or not context.state.active_encounter.is_empty(): return false
	var changed:=false
	var parties: Array=runtime.parties.values().duplicate()
	for slot: Dictionary in runtime.slots.values():
		if not slot.get("pending_party",{}).is_empty(): parties.append(slot.pending_party)
	for party: Dictionary in parties:
		if not String(party.get("template_id","")).begins_with("monkey_garden"): continue
		var habitat: WorldHabitat=context.map_definitions[runtime.map_id].habitat(party.get("habitat_id",""))
		if habitat==null:
			for candidate: WorldHabitat in context.map_definitions[runtime.map_id].habitats:
				if not candidate.profile.templates.is_empty() and candidate.profile.templates[0].template_id==party.template_id: habitat=candidate; break
		if habitat==null or habitat.profile.templates.is_empty(): continue
		var template: PartyTemplate=habitat.profile.templates[0]
		var updated:=false
		for rule: MemberRule in template.members:
			var count:=0
			for member: Dictionary in party.deployed_units:
				if member.definition_id!=String(rule.definition.id): continue
				count+=1
				if member.level!=rule.min_level:
					var ratio: float=float(member.current_hp)/maxf(1,member.resolved_stats.health)
					var fresh:=PartyBuilder.resolve_member(rule.definition,rule.min_level,member.unit_id)
					fresh.current_hp=fresh.resolved_stats.health*ratio
					member.merge(fresh,true); updated=true
			while count<rule.min_count:
				party.deployed_units.append(PartyBuilder.resolve_member(rule.definition,rule.min_level,context.allocate("unit")))
				count+=1; updated=true
		if party.display_name!=template.display_name: party.display_name=template.display_name; updated=true
		if updated:
			party.total_power=PowerCalculator.make_summary(party).power
			party.roster_revision=int(party.get("roster_revision",1))+1
			changed=true
	return changed
