class_name LegacyPartyFixture
extends RefCounted
## Historical mechanics use explicit Lv1 seven-unit fixtures, not demo defaults.
## The real ten-unit bootstrap is verified separately by demo_roster_suite.
static func install() -> void:
	assert(not WorldSession.context.save.enabled)
	PartyProgress.records.clear(); PartyProgress.reserves.clear(); PartyProgress.selected_slot=0
	for i: int in Catalog.party().size():
		var record: CharacterRecord=CharacterRecord.new(); record.initialize(Catalog.party()[i],"party_%d"%i)
		record.changed.connect(PartyProgress._record_changed.bind(i)); PartyProgress.records.append(record)
	WorldSession.context.refresh_player(PartyProgress.serialize())
