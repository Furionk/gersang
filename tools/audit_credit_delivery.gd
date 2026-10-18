extends SceneTree
func _initialize() -> void:
 var result:Dictionary=preload("res://addons/web_export/core/object_audit.gd").run("L:/git/furionkcom/gersang","d20cc28b84fe4a598d8d9da183bf59cf")
 var summary:Dictionary={}
 for key in ["release","current_valid","retained_valid","latest_only","missing","corrupt","obsolete","unknown","unsafe","manifest_errors"]:
  summary[key]=result.get(key)
 summary["objects"]=result.get("current",[]).size()
 if result.has("error"): summary["error"]=result.error
 var file:=FileAccess.open("res://artifacts/credits-release/object-audit.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(summary,"\t")); file.close()
 print("CREDIT_DELIVERY_AUDIT ",JSON.stringify(summary))
 quit(0 if result.get("latest_only",false) else 1)
