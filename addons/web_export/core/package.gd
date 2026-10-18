@tool
extends RefCounted
const Files = preload("files.gd")

static func build(native_dir:String, stage:String, profile:Dictionary, analysis:Dictionary, progress:Callable=Callable(), cancelled:Callable=Callable()) -> Dictionary:
	var manifest:Dictionary = {"schema":1,"project":profile.project_id,"files":[]}
	var chunk_bytes:int = int(profile.chunk_mib)*1048576
	var seen:Dictionary = {}
	var first_bytes:int = 0
	var unpacked:int = 0
	var processed:int=0
	var total_bytes:int=0
	for name:String in ["index.wasm","index.pck"]:
		var source:FileAccess=FileAccess.open(native_dir.path_join(name),FileAccess.READ)
		if source==null: return {"error":"Missing native output: "+name}
		total_bytes+=source.get_length()
	for name:String in ["index.wasm","index.pck"]:
		var file:FileAccess = FileAccess.open(native_dir.path_join(name),FileAccess.READ)
		if file == null: return {"error":"Missing native output: "+name}
		var record:Dictionary = {"name":name,"bytes":file.get_length(),"sha256":FileAccess.get_sha256(native_dir.path_join(name)),"parts":[]}
		unpacked += file.get_length()
		while file.get_position() < file.get_length():
			if cancelled.is_valid() and cancelled.call(): return {"error":"Cancelled packaging; previous entry preserved."}
			var bytes:PackedByteArray = file.get_buffer(mini(chunk_bytes,file.get_length()-file.get_position()))
			var hash:String = Files.sha(bytes)
			var encoded:PackedByteArray = bytes
			var encoding:String = "identity"
			if profile.compression == "gzip":
				var compressed:PackedByteArray = bytes.compress(FileAccess.COMPRESSION_GZIP)
				if compressed.size() < bytes.size(): encoded=compressed; encoding="gzip"
			var relative:String = "objects/"+hash+(".bin.gz" if encoding=="gzip" else ".bin")
			if not seen.has(relative):
				if not Files.write(stage.path_join(relative),encoded): return {"error":"Cannot write chunk: "+relative}
				seen[relative] = true; first_bytes += encoded.size()
				var verify:PackedByteArray = FileAccess.get_file_as_bytes(stage.path_join(relative))
				if encoding == "gzip": verify=verify.decompress(bytes.size(),FileAccess.COMPRESSION_GZIP)
				if Files.sha(verify)!=hash: return {"error":"Chunk verification failed"}
			processed+=bytes.size()
			if progress.is_valid(): progress.call("Packaging and verifying chunks",processed,total_bytes,"bytes")
			record.parts.append({"url":relative,"bytes":bytes.size(),"sha256":hash,"wire_bytes":encoded.size(),"encoding":encoding})
		manifest.files.append(record)
	var runtime:PackedByteArray = FileAccess.get_file_as_bytes("res://addons/web_export/web/runtime.js")
	var html:String = FileAccess.get_file_as_string(native_dir.path_join("index.html"))
	for token:String in ["WEB_EXPORT_SHELL_V1","__WX_META__","__WX_RUNTIME__","__WX_LOGO__","__WX_TITLE__"]:
		if not html.contains(token): return {"error":"Custom HTML template is missing "+token}
	var native_names:PackedStringArray=DirAccess.get_files_at(native_dir); native_names.sort()
	var identity:String = JSON.stringify(manifest,"",true)+Files.sha(runtime)+html+JSON.stringify(profile,"",true)
	for name:String in native_names:
		if name not in ["index.pck","index.wasm","index.html"]: identity += name+FileAccess.get_sha256(native_dir.path_join(name))
	if not str(profile.logo).is_empty(): identity += FileAccess.get_sha256(str(profile.logo))
	var release:String = identity.sha256_text().substr(0,24)
	manifest.release = release
	var prefix:String = "releases/"+release+"/"
	for name:String in native_names:
		if name in ["index.pck","index.wasm","index.html"]: continue
		if not Files.copy_verified(native_dir.path_join(name),stage.path_join(prefix+name)): return {"error":"Sidecar copy failed: "+name}
	if not Files.write(stage.path_join(prefix+"runtime.js"),runtime): return {"error":"Runtime write failed"}
	if not Files.json_write(stage.path_join(prefix+"manifest.json"),manifest): return {"error":"Manifest write failed"}
	var logo:String = ""
	if not str(profile.logo).is_empty():
		logo=prefix+"logo."+str(profile.logo).get_extension().to_lower()
		if not Files.copy_verified(str(profile.logo),stage.path_join(logo)): return {"error":"Logo copy failed"}
	var metadata:Dictionary = {"schema":1,"project":profile.project_id,"manifest":prefix+"manifest.json","base":prefix,"cache":profile.cache,"cache_bytes":int(profile.cache_mib)*1048576,"parallel":profile.parallel,"diagnostics":profile.get("diagnostics",false)}
	html=html.replace('__WX_META__',JSON.stringify(metadata)).replace('__WX_RUNTIME__',prefix+'runtime.js').replace('__WX_LOGO__',logo).replace('__WX_TITLE__',str(ProjectSettings.get_setting("application/config/name","Game")).xml_escape())
	html=html.replace('src="index.js"','src="'+prefix+'index.js"').replace('href="index.icon.png"','href="'+prefix+'index.icon.png"').replace('href="index.apple-touch-icon.png"','href="'+prefix+'index.apple-touch-icon.png"')
	if not html.contains('src="'+prefix+'index.js"'): return {"error":"Template must load the Godot script using src=\"$GODOT_URL\"."}
	if not Files.write(stage.path_join("index.html"),html.to_utf8_buffer()): return {"error":"HTML write failed"}
	var apache:String = """# Web Export Studio: place inside the game's own directory.
AddType application/wasm .wasm
AddType application/octet-stream .bin .pck
AddEncoding gzip .gz
<IfModule mod_setenvif.c>
SetEnvIfNoCase Request_URI "\\.bin\\.gz$" no-gzip=1
</IfModule>
<IfModule mod_headers.c>
<FilesMatch "^(index\\.html|.*manifest\\.json)$">
Header set Cache-Control "no-cache, must-revalidate"
</FilesMatch>
<FilesMatch "^[a-f0-9]{64}\\.bin(\\.gz)?$">
Header set Cache-Control "public, max-age=31536000, immutable"
</FilesMatch>
</IfModule>
"""
	if not Files.write(stage.path_join(".htaccess"),apache.to_utf8_buffer()): return {"error":"Server configuration write failed"}
	var paths:Dictionary = {}
	var total:int = 0
	for path:String in Files.list_files(stage,false):
		var relative:String = path.trim_prefix(stage+"/")
		paths[relative]=FileAccess.get_sha256(path)
		total += FileAccess.open(path,FileAccess.READ).get_length()
	var overhead:int = total
	for object_path:String in seen: overhead -= FileAccess.open(stage.path_join(object_path),FileAccess.READ).get_length()
	var report:Dictionary = {"release":release,"project":profile.project_id,"files":paths,"server_bytes":total,"first_transfer_bytes":first_bytes+overhead,"decoded_pack_bytes":unpacked,"loader_memory_estimate_bytes":unpacked+chunk_bytes*int(profile.parallel),"transfer_note":"First-transfer upper bound includes all release sidecars; actual browser requests can be smaller. Server bytes describe this release, not retained older releases.","memory_note":"Assembly buffers only; excludes WASM heap, engine copies, decoded textures and driver memory.","analysis":analysis,"warnings":[]}
	if report.first_transfer_bytes>int(profile.first_budget_mib)*1048576: report.warnings.append("First-download budget exceeded.")
	if total>int(profile.total_budget_mib)*1048576: report.warnings.append("Server-storage budget exceeded.")
	if profile.compression=="gzip": report.warnings.append("Host must serve .bin.gz with Content-Encoding: gzip. Use preview then verify production response headers.")
	return report
