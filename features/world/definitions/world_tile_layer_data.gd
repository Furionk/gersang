@tool
class_name WorldTileLayerData
extends Resource
@export var layer_name: String = "地面"
@export var tile_set: TileSet
@export var cells: PackedByteArray = PackedByteArray()
@export var offset: Vector2 = Vector2(-32,0)
@export var z: int = -3500
