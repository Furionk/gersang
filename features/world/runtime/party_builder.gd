@tool
class_name PartyBuilder
extends RefCounted

static func resolve_member(definition: UnitDefinition, level: int, id: String, equipment_power: int = 0) -> Dictionary:
	var attributes: Dictionary = {"strength":definition.strength,"agility":definition.agility,"intelligence":definition.intelligence,"luck":definition.luck,"vitality":definition.vitality}
	var stats: Dictionary = CombatStats.calculate(definition, attributes, level)
	return {"unit_id":id,"definition_id":String(definition.id),"definition_revision":definition.content_revision,"balance_revision":definition.balance_revision,"level":level,"definition_path":definition.resource_path,"resolved_stats":stats,"current_hp":stats["health"],"current_mp":stats["mana"],"rated_power":PowerCalculator.unit_rating(definition, level, equipment_power),"experience_reward":definition.experience_reward,"equipment_power":equipment_power}

static func build(template: PartyTemplate, rng: RandomNumberGenerator, allocate: Callable) -> Dictionary:
	var party: Dictionary = {"party_id":allocate.call("party"),"template_id":template.template_id,"display_name":template.display_name,"roster_revision":1,"deployed_units":[],"reserve_units":[],"representative_path":template.representative.resource_path}
	for rule: MemberRule in template.members:
		for i: int in rng.randi_range(rule.min_count, maxi(rule.min_count, rule.max_count)):
			party["deployed_units"].append(resolve_member(rule.definition, rng.randi_range(rule.min_level, maxi(rule.min_level, rule.max_level)), allocate.call("unit"), rule.equipment_power))
	party["total_power"] = PowerCalculator.make_summary(party)["power"]
	return party
