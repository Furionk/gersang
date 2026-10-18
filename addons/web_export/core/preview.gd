extends SceneTree
const Files = preload("files.gd")
var server:TCPServer=TCPServer.new()
var clients:Array=[]
var folder:String
func _initialize() -> void:
	var args:PackedStringArray=OS.get_cmdline_user_args()
	if args.size()<2: quit(2); return
	folder=args[0].simplify_path().replace("\\","/").trim_suffix("/")
	var error:Error=server.listen(int(args[1]),"127.0.0.1")
	if error!=OK: print("PREVIEW_FAILED ",error); quit(1); return
	print("PREVIEW_READY http://127.0.0.1:",args[1],"/")
func _process(_delta:float) -> bool:
	while server.is_connection_available(): clients.append({"socket":server.take_connection(),"request":PackedByteArray(),"response":PackedByteArray(),"offset":0,"started":Time.get_ticks_msec()})
	for client:Dictionary in clients.duplicate():
		var socket:StreamPeerTCP=client.socket
		socket.poll()
		if socket.get_status()!=StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec()-int(client.started)>30000:
			socket.disconnect_from_host(); clients.erase(client); continue
		if client.response.is_empty():
			var count:int=socket.get_available_bytes()
			if count>0:
				var read:Array=socket.get_data(count)
				if read[0]!=OK: clients.erase(client); continue
				client.request.append_array(read[1])
			if client.request.size()>16384: socket.disconnect_from_host(); clients.erase(client); continue
			var text:String=client.request.get_string_from_utf8()
			if not text.contains("\r\n\r\n"): continue
			var first:PackedStringArray=text.get_slice("\r\n",0).split(" ")
			var url:String=first[1].get_slice("?",0).uri_decode() if first.size()>1 else ""
			var relative:String=url.trim_prefix("/")
			if relative.is_empty(): relative="index.html"
			var path:String=folder.path_join(relative).simplify_path()
			var code:String="200 OK"; var body:PackedByteArray=[]; var mime:String="application/octet-stream"
			if not Files.relative_safe(relative) or not path.begins_with(folder+"/") or not FileAccess.file_exists(path): code="404 Not Found"
			elif first[0] not in ["GET","HEAD"]: code="405 Method Not Allowed"
			else: body=FileAccess.get_file_as_bytes(path)
			match path.get_extension():
				"html": mime="text/html; charset=utf-8"
				"js": mime="text/javascript"
				"json": mime="application/json"
				"wasm": mime="application/wasm"
				"png": mime="image/png"
				"svg": mime="image/svg+xml"
				"webp": mime="image/webp"
				"jpg","jpeg": mime="image/jpeg"
			var header:String="HTTP/1.1 "+code+"\r\nContent-Type: "+mime+"\r\nContent-Length: "+str(body.size())+"\r\nCache-Control: no-store\r\nConnection: close\r\n"
			if relative.ends_with(".bin.gz") and code=="200 OK": header+="Content-Encoding: gzip\r\n"
			client.response=(header+"\r\n").to_utf8_buffer()
			if first[0]!="HEAD": client.response.append_array(body)
		var end:int=mini(int(client.offset)+65536,client.response.size())
		var sent:Array=socket.put_partial_data(client.response.slice(int(client.offset),end))
		if sent[0]!=OK: socket.disconnect_from_host(); clients.erase(client); continue
		client.offset+=sent[1]
		if client.offset==client.response.size(): socket.disconnect_from_host(); clients.erase(client)
	return false
