class_name TestArtifacts
extends RefCounted
## Generated evidence only; approved fixtures and all test entry paths stay under res://tests/.
static func output(suite:String,filename:String)->String:
	assert(not suite.is_empty() and not filename.is_empty() and not suite.contains("/") and not suite.contains("\\") and not suite.contains("..") and not filename.contains("/") and not filename.contains("\\") and not filename.contains(".."))
	var folder:String="res://artifacts/tests/"+suite
	var error:Error=DirAccess.make_dir_recursive_absolute(folder)
	if error!=OK: push_error("無法建立測試輸出資料夾："+folder)
	return folder+"/"+filename
