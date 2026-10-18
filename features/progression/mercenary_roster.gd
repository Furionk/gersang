class_name MercenaryRoster
extends RefCounted
## 正式七人及候補倉庫的純資料驗證；不寫存檔、不更改共享兵種 Resource。
const VERSION: int = 2
const CAPACITY: int = 100
const ACTIVE_CAPACITY: int = 10

static func paths() -> Array[String]:
	var result: Array[String] = Catalog.PARTY_PATHS.duplicate()
	for data: UnitDefinition in Catalog.additional_mercenaries():
		if data.resource_path not in result: result.append(data.resource_path)
	return result

static func decode(data: Variant) -> Dictionary:
	if not data is Dictionary or data.get("version",-1) not in [1,VERSION]: return {}
	if not data.get("party") is Array or data.party.is_empty() or data.party.size()>ACTIVE_CAPACITY: return {}
	if data.version==1 and data.party.size()!=7: return {}
	var reserve: Variant = data.get("reserve",[])
	if not reserve is Array or reserve.size()>CAPACITY: return {}
	var active: Array[CharacterRecord] = []
	var stored: Array[CharacterRecord] = []
	var ids: Dictionary = {}
	var species: Dictionary = {}
	var allowed: Array[String] = paths()
	for group: int in 2:
		var source: Array = data.party if group==0 else reserve
		for i: int in source.size():
			if not source[i] is Dictionary: return {}
			var entry: Dictionary = source[i]
			var id: String = str(entry.get("id",""))
			if id.is_empty() or ids.has(id): return {}
			var path: String = str(entry.get("definition_path",""))
			if data.version==1 and group==0:
				path=Catalog.PARTY_PATHS[i]
				if id!="party_%d"%i: return {}
			if path not in allowed: return {}
			if species.has(path): return {}
			species[path]=true
			var definition: UnitDefinition = load(path) as UnitDefinition
			if definition==null: return {}
			var record: CharacterRecord = CharacterRecord.new()
			record.initialize(definition,id,false)
			if not record.restore(entry): return {}
			ids[id]=true
			if group==0: active.append(record)
			else: stored.append(record)
	# The travelling merchant remains the main character; six mercenary slots are interchangeable.
	if active[0].persistent_id!="party_0" or active[0].definition.resource_path!=Catalog.PARTY_PATHS[0]: return {}
	return {"active":active,"reserve":stored}

static func recruit(data: Dictionary, definition_path: String) -> Dictionary:
	return {} # Fixed unique roster: permanent recruitment removed.

static func _legacy_recruit_unused(data: Dictionary, definition_path: String) -> Dictionary:
	if definition_path not in paths() or definition_path==Catalog.PARTY_PATHS[0]: return {}
	var decoded: Dictionary = decode(data)
	if decoded.is_empty() or decoded.reserve.size()>=CAPACITY: return {}
	var used: Dictionary = {}
	for record: CharacterRecord in decoded.active+decoded.reserve: used[record.persistent_id]=true
	var serial: int = 1
	while used.has("recruit_%d"%serial): serial+=1
	var record: CharacterRecord = CharacterRecord.new()
	record.initialize(load(definition_path) as UnitDefinition,"recruit_%d"%serial,false)
	record.experience=0
	record.health=record.stats().health
	record.mana=record.stats().mana
	var candidate: Dictionary = data.duplicate(true)
	candidate.version=VERSION
	# Normalize legacy members before promoting the schema version.
	candidate.party=[]
	for member: CharacterRecord in decoded.active: candidate.party.append(member.serialize())
	candidate.reserve=[]
	for member: CharacterRecord in decoded.reserve: candidate.reserve.append(member.serialize())
	candidate.reserve.append(record.serialize())
	return candidate

static func exchange(data: Dictionary, reserve_id: String, slot: int) -> Dictionary:
	if slot<1 or slot>=data.get("party",[]).size(): return {}
	var decoded: Dictionary=decode(data)
	if decoded.is_empty(): return {}
	var candidate: Dictionary=data.duplicate(true)
	for i: int in decoded.reserve.size():
		if decoded.reserve[i].persistent_id==reserve_id:
			var old: Dictionary=candidate.party[slot]
			candidate.party[slot]=candidate.reserve[i]
			candidate.reserve[i]=old
			candidate.selected=slot
			return candidate
	return {}

static func deposit(data: Dictionary, slot: int) -> Dictionary:
	var decoded: Dictionary=decode(data)
	if decoded.is_empty() or slot<1 or slot>=decoded.active.size() or decoded.reserve.size()>=CAPACITY: return {}
	var candidate: Dictionary=data.duplicate(true)
	candidate.reserve.append(candidate.party[slot])
	candidate.party.remove_at(slot)
	var selected: int=int(candidate.get("selected",0))
	candidate.selected=clampi(selected-1 if selected>slot else 0 if selected==slot else selected,0,candidate.party.size()-1)
	return candidate

static func withdraw(data: Dictionary, reserve_id: String) -> Dictionary:
	var decoded: Dictionary=decode(data)
	if decoded.is_empty() or decoded.active.size()>=ACTIVE_CAPACITY: return {}
	var candidate: Dictionary=data.duplicate(true)
	for i: int in decoded.reserve.size():
		if decoded.reserve[i].persistent_id==reserve_id:
			candidate.party.append(candidate.reserve[i])
			candidate.reserve.remove_at(i)
			candidate.selected=candidate.party.size()-1
			return candidate
	return {}
