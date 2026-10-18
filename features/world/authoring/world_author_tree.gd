@tool
class_name WorldAuthorTree
extends RefCounted
## Shared traversal for grouped maps. Archived provenance never becomes authority.
static func nodes(root: Node, include_archive: bool = false) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in root.get_children():
		if child.get_meta("authoring_archived",false) and not include_archive: continue
		result.append(child)
		result.append_array(nodes(child,include_archive))
	if result.any(func(n: Node) -> bool: return n.has_meta("authoring_order")):
		result.sort_custom(func(a: Node,b: Node) -> bool: return int(a.get_meta("authoring_order",1000000))<int(b.get_meta("authoring_order",1000000)))
	return result

static func canvas_transform(node: Node2D, root: Node) -> Transform2D:
	var value: Transform2D = node.transform
	var parent: Node = node.get_parent()
	while parent!=null and parent!=root:
		if parent is Node2D: value = (parent as Node2D).transform*value
		parent = parent.get_parent()
	return value

static func logical_position(node: WorldAuthorNode, root: Node) -> Vector2:
	var point: Vector2 = canvas_transform(node,root).origin
	return Iso.unproject(point) if node.coordinate_space==WorldAuthorNode.CoordinateSpace.CANVAS else point
