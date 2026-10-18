@tool
class_name PowerCalculator
extends RefCounted

static func unit_rating(definition: UnitDefinition, level: int, equipment_bonus: int = 0) -> int:
	return maxi(0, definition.base_power + definition.level_power_growth * (level - 1) + equipment_bonus)

static func make_summary(party: Dictionary) -> Dictionary:
	var total: int = 0
	for unit: Dictionary in party.get("deployed_units", []):
		total += maxi(0, int(unit.get("rated_power", 0)))
	return {"party_id":party.get("party_id", ""), "name":party.get("display_name", ""), "power":total, "count":party.get("deployed_units", []).size(), "revision":party.get("roster_revision", 1)}
