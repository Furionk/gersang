@tool
class_name DamageFormula
extends RefCounted
const NAMES: PackedStringArray = ["strength", "attack", "intelligence", "agility", "vitality", "level", "luck"]
const ALIASES: Dictionary = {"攻擊力":"attack", "攻击力":"attack", "傷害":"attack", "伤害":"attack", "力量":"strength", "智慧":"intelligence", "智力":"intelligence", "敏捷":"agility", "體質":"vitality", "体质":"vitality", "等級":"level", "等级":"level", "幸運":"luck", "幸运":"luck"}
static var cache: Dictionary = {}
static func normalize(text: String) -> String:
	var result: String = text.replace("×", "*").replace("÷", "/")
	for alias: String in ALIASES:
		result = result.replace(alias, ALIASES[alias])
	return result
static func evaluate(text: String, stats: Dictionary) -> Dictionary:
	var normalized: String = normalize(text)
	var token: RegEx = RegEx.new()
	token.compile("[A-Za-z_][A-Za-z_0-9]*")
	for found: RegExMatch in token.search_all(normalized):
		if found.get_string() not in NAMES:
			return {"valid":false, "value":0.0, "error":"未知變數：" + found.get_string()}
	var allowed: RegEx = RegEx.new()
	allowed.compile("^[0-9A-Za-z_+*/(). \\t\\r\\n-]+$")
	if allowed.search(normalized) == null or normalized.strip_edges() == "":
		return {"valid":false, "value":0.0, "error":"只允許數值、能力、括號與 + - * /"}
	var calls: RegEx = RegEx.new()
	calls.compile("[A-Za-z_][A-Za-z_0-9]*\\s*\\(")
	if calls.search(normalized) != null:
		return {"valid":false, "value":0.0, "error":"不接受函式或物件呼叫"}
	var expression: Expression
	if cache.has(normalized):
		expression = cache[normalized]
	else:
		expression = Expression.new()
		if expression.parse(normalized, NAMES) != OK:
			return {"valid":false, "value":0.0, "error":expression.get_error_text()}
		cache[normalized] = expression
	var inputs: Array = []
	for key: String in NAMES:
		inputs.append(float(stats.get(key, 1.0 if key == "level" else 20.0)))
	var value: Variant = expression.execute(inputs, null, false, true)
	if expression.has_execute_failed() or not (value is float or value is int):
		return {"valid":false, "value":0.0, "error":"無法計算，請檢查除零"}
	if not is_finite(float(value)):
		return {"valid":false, "value":0.0, "error":"結果不是有限數值"}
	return {"valid":true, "value":maxf(0, float(value)), "error":""}
static func mitigate(value: float, armor: float) -> float:
	return maxf(0, value) * (1.0 - clampf(armor, 0, 0.9))
