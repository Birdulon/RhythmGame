extends Node

const SQRT2 := sqrt(2)
const DEG45 := deg2rad(45.0)
const DEG90 := deg2rad(90.0)
const DEG135 := deg2rad(135.0)

# ----------------------------------------------------------------------------------------------------------------------------------------------------
# Helper functions to generate meshes from vertex arrays
static func make_tap_mesh(mesh: ArrayMesh, note_center: Vector2, scale:=1.0, color_array:=GameTheme.COLOR_ARRAY_TAP):
	var dim = GameTheme.sprite_size2 * scale
	var vertex_array = PoolVector2Array([note_center + Vector2(-dim, -dim), note_center + Vector2(dim, -dim), note_center + Vector2(-dim, dim), note_center + Vector2(dim, dim)])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_TEX_UV] = GameTheme.UV_ARRAY_TAP
	arrays[Mesh.ARRAY_COLOR] = color_array
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)

static func make_hold_mesh(mesh: ArrayMesh, note_center: Vector2, note_center_rel: Vector2, scale:=1.0, angle:=0.0, color_array = GameTheme.COLOR_ARRAY_HOLD):
	var dim = GameTheme.sprite_size2 * scale
	var dim2 = dim * SQRT2
	var a1 = angle - DEG45
	var a2 = angle + DEG45
	var a3 = angle - DEG90
	var a4 = angle + DEG90
	var a5 = angle - DEG135
	var a6 = angle + DEG135
	var vertex_array = PoolVector2Array([
		note_center + polar2cartesian(dim2, a1), note_center + polar2cartesian(dim2, a2),
		note_center + polar2cartesian(dim, a3), note_center + polar2cartesian(dim, a4),
		note_center_rel + polar2cartesian(dim, a3), note_center_rel + polar2cartesian(dim, a4),
		note_center_rel + polar2cartesian(dim2, a5), note_center_rel + polar2cartesian(dim2, a6)
		])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_TEX_UV] = GameTheme.UV_ARRAY_HOLD
	arrays[Mesh.ARRAY_COLOR] = color_array
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)

static func make_star_mesh(mesh: ArrayMesh, note_center: Vector2, scale:=1.0, angle:=0.0, color_array:=GameTheme.COLOR_ARRAY_STAR):
	var dim = GameTheme.sprite_size2 * scale * SQRT2
	var a1 = angle - DEG45
	var a2 = angle + DEG45
	var a3 = angle - DEG135
	var a4 = angle + DEG135
	var vertex_array = PoolVector2Array([
		note_center + polar2cartesian(dim, a1), note_center + polar2cartesian(dim, a2),
		note_center + polar2cartesian(dim, a3), note_center + polar2cartesian(dim, a4)
		])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_TEX_UV] = GameTheme.UV_ARRAY_STAR
	arrays[Mesh.ARRAY_COLOR] = color_array
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)

#func make_arrow_mesh(mesh: ArrayMesh, vertex_array, color_array = GameTheme.COLOR_ARRAY_TAP):
#	var arrays = []
#	arrays.resize(Mesh.ARRAY_MAX)
#	arrays[Mesh.ARRAY_VERTEX] = vertex_array
#	arrays[Mesh.ARRAY_TEX_UV] = UV_ARRAY_ARROW
#	arrays[Mesh.ARRAY_COLOR] = color_array
#	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)


const slide_arrows_per_unit_length := 10
static func make_slide_trail_mesh(note) -> ArrayMesh:
	# Generates a mesh centered around origin. Make sure the MeshInstance2D that draws this is centered on the screen.
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PoolVector2Array()
	var uvs := PoolVector2Array()
	var colors := PoolColorArray()
	var size := GameTheme.sprite_size2 * sqrt(2)
	var color := GameTheme.COLOR_DOUBLE_SLIDE if note.double_hit else GameTheme.COLOR_SLIDE

	match note.get_points():
		[var positions, var angles]:
			var trail_length : int = len(positions)
			vertices.resize(3*trail_length)
			uvs.resize(3*trail_length)
			colors.resize(3*trail_length)
			for i in trail_length:
				var idx = (trail_length-i-1)*3  # We want the earliest ones to be drawn last so that loops/sharp bends will have the first pass on top
				var u = GameTheme.UV_ARRAY_SLIDE_ARROW if i%3 else GameTheme.UV_ARRAY_SLIDE_ARROW2
				for j in 3:
					uvs[idx+j] = u[j]
					colors[idx+j] = Color(color.r, color.g, color.b, (1.0+float(i))/float(trail_length))
				var angle : float = angles[i]
				var offset : Vector2 = positions[i] * GameTheme.receptor_ring_radius
				vertices[idx] = offset
				vertices[idx+1] = offset + polar2cartesian(size, angle+PI*0.75)
				vertices[idx+2] = offset + polar2cartesian(size, angle-PI*0.75)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh



#----------------------------------------------------------------------------------------------------------------------------------------------
# Text UVs

# Old dynamic code:
#var text_UV_arrays := []
#func make_text_UV(row: int, column: int) -> PoolVector2Array:
#	return PoolVector2Array([Vector2(column/4.0, row/8.0), Vector2((column+1)/4.0, row/8.0), Vector2(column/4.0, (row+1)/8.0), Vector2((column+1)/4.0, (row+1)/8.0)])
#func make_text_UVs():
#	for row in 8:
#		for column in 4:
#			text_UV_arrays.append(make_text_UV(row, column))

# This is replaced by a quick hacky python codegen:
#>>> def make_text_UV(row, column):
#...     return f'PoolVector2Array([Vector2({column}/4.0, {row}/8.0), Vector2({column+1}/4.0, {row}/8.0), Vector2({column}/4.0, {row+1}/8.0), Vector2({column+1}/4.0, {row+1}/8.0)])'
#>>> for row in range(8):
#...  for col in range(4):
#...   print(make_text_UV(row, col) + ',')

const text_UV_arrays := [
	PoolVector2Array([Vector2(0/4.0, 0/8.0), Vector2(1/4.0, 0/8.0), Vector2(0/4.0, 1/8.0), Vector2(1/4.0, 1/8.0)]),
	PoolVector2Array([Vector2(1/4.0, 0/8.0), Vector2(2/4.0, 0/8.0), Vector2(1/4.0, 1/8.0), Vector2(2/4.0, 1/8.0)]),
	PoolVector2Array([Vector2(2/4.0, 0/8.0), Vector2(3/4.0, 0/8.0), Vector2(2/4.0, 1/8.0), Vector2(3/4.0, 1/8.0)]),
	PoolVector2Array([Vector2(3/4.0, 0/8.0), Vector2(4/4.0, 0/8.0), Vector2(3/4.0, 1/8.0), Vector2(4/4.0, 1/8.0)]),
	PoolVector2Array([Vector2(0/4.0, 1/8.0), Vector2(1/4.0, 1/8.0), Vector2(0/4.0, 2/8.0), Vector2(1/4.0, 2/8.0)]),
	PoolVector2Array([Vector2(1/4.0, 1/8.0), Vector2(2/4.0, 1/8.0), Vector2(1/4.0, 2/8.0), Vector2(2/4.0, 2/8.0)]),
	PoolVector2Array([Vector2(2/4.0, 1/8.0), Vector2(3/4.0, 1/8.0), Vector2(2/4.0, 2/8.0), Vector2(3/4.0, 2/8.0)]),
	PoolVector2Array([Vector2(3/4.0, 1/8.0), Vector2(4/4.0, 1/8.0), Vector2(3/4.0, 2/8.0), Vector2(4/4.0, 2/8.0)]),
	PoolVector2Array([Vector2(0/4.0, 2/8.0), Vector2(1/4.0, 2/8.0), Vector2(0/4.0, 3/8.0), Vector2(1/4.0, 3/8.0)]),
	PoolVector2Array([Vector2(1/4.0, 2/8.0), Vector2(2/4.0, 2/8.0), Vector2(1/4.0, 3/8.0), Vector2(2/4.0, 3/8.0)]),
	PoolVector2Array([Vector2(2/4.0, 2/8.0), Vector2(3/4.0, 2/8.0), Vector2(2/4.0, 3/8.0), Vector2(3/4.0, 3/8.0)]),
	PoolVector2Array([Vector2(3/4.0, 2/8.0), Vector2(4/4.0, 2/8.0), Vector2(3/4.0, 3/8.0), Vector2(4/4.0, 3/8.0)]),
	PoolVector2Array([Vector2(0/4.0, 3/8.0), Vector2(1/4.0, 3/8.0), Vector2(0/4.0, 4/8.0), Vector2(1/4.0, 4/8.0)]),
	PoolVector2Array([Vector2(1/4.0, 3/8.0), Vector2(2/4.0, 3/8.0), Vector2(1/4.0, 4/8.0), Vector2(2/4.0, 4/8.0)]),
	PoolVector2Array([Vector2(2/4.0, 3/8.0), Vector2(3/4.0, 3/8.0), Vector2(2/4.0, 4/8.0), Vector2(3/4.0, 4/8.0)]),
	PoolVector2Array([Vector2(3/4.0, 3/8.0), Vector2(4/4.0, 3/8.0), Vector2(3/4.0, 4/8.0), Vector2(4/4.0, 4/8.0)]),
	PoolVector2Array([Vector2(0/4.0, 4/8.0), Vector2(1/4.0, 4/8.0), Vector2(0/4.0, 5/8.0), Vector2(1/4.0, 5/8.0)]),
	PoolVector2Array([Vector2(1/4.0, 4/8.0), Vector2(2/4.0, 4/8.0), Vector2(1/4.0, 5/8.0), Vector2(2/4.0, 5/8.0)]),
	PoolVector2Array([Vector2(2/4.0, 4/8.0), Vector2(3/4.0, 4/8.0), Vector2(2/4.0, 5/8.0), Vector2(3/4.0, 5/8.0)]),
	PoolVector2Array([Vector2(3/4.0, 4/8.0), Vector2(4/4.0, 4/8.0), Vector2(3/4.0, 5/8.0), Vector2(4/4.0, 5/8.0)]),
	PoolVector2Array([Vector2(0/4.0, 5/8.0), Vector2(1/4.0, 5/8.0), Vector2(0/4.0, 6/8.0), Vector2(1/4.0, 6/8.0)]),
	PoolVector2Array([Vector2(1/4.0, 5/8.0), Vector2(2/4.0, 5/8.0), Vector2(1/4.0, 6/8.0), Vector2(2/4.0, 6/8.0)]),
	PoolVector2Array([Vector2(2/4.0, 5/8.0), Vector2(3/4.0, 5/8.0), Vector2(2/4.0, 6/8.0), Vector2(3/4.0, 6/8.0)]),
	PoolVector2Array([Vector2(3/4.0, 5/8.0), Vector2(4/4.0, 5/8.0), Vector2(3/4.0, 6/8.0), Vector2(4/4.0, 6/8.0)]),
	PoolVector2Array([Vector2(0/4.0, 6/8.0), Vector2(1/4.0, 6/8.0), Vector2(0/4.0, 7/8.0), Vector2(1/4.0, 7/8.0)]),
	PoolVector2Array([Vector2(1/4.0, 6/8.0), Vector2(2/4.0, 6/8.0), Vector2(1/4.0, 7/8.0), Vector2(2/4.0, 7/8.0)]),
	PoolVector2Array([Vector2(2/4.0, 6/8.0), Vector2(3/4.0, 6/8.0), Vector2(2/4.0, 7/8.0), Vector2(3/4.0, 7/8.0)]),
	PoolVector2Array([Vector2(3/4.0, 6/8.0), Vector2(4/4.0, 6/8.0), Vector2(3/4.0, 7/8.0), Vector2(4/4.0, 7/8.0)]),
	PoolVector2Array([Vector2(0/4.0, 7/8.0), Vector2(1/4.0, 7/8.0), Vector2(0/4.0, 8/8.0), Vector2(1/4.0, 8/8.0)]),
	PoolVector2Array([Vector2(1/4.0, 7/8.0), Vector2(2/4.0, 7/8.0), Vector2(1/4.0, 8/8.0), Vector2(2/4.0, 8/8.0)]),
	PoolVector2Array([Vector2(2/4.0, 7/8.0), Vector2(3/4.0, 7/8.0), Vector2(2/4.0, 8/8.0), Vector2(3/4.0, 8/8.0)]),
	PoolVector2Array([Vector2(3/4.0, 7/8.0), Vector2(4/4.0, 7/8.0), Vector2(3/4.0, 8/8.0), Vector2(4/4.0, 8/8.0)])
]

enum TextStyle {STRAIGHT=0, ARC=1, ARC_EARLY=2, ARC_LATE=3}
enum TextWord {NICE=0, OK=4, NG=8, PERFECT=12, GREAT=16, GOOD=20, ALMOST=24, MISS=28}
const TextJudgement := {
	0: TextWord.PERFECT + TextStyle.ARC,
	1: TextWord.GREAT + TextStyle.ARC_LATE,
	-1: TextWord.GREAT + TextStyle.ARC_EARLY,
	2: TextWord.GOOD + TextStyle.ARC_LATE,
	-2: TextWord.GOOD + TextStyle.ARC_EARLY,
	3: TextWord.ALMOST + TextStyle.ARC_LATE,
	-3: TextWord.ALMOST + TextStyle.ARC_EARLY,
	'MISS': TextWord.MISS + TextStyle.ARC
}
const TextJudgementStraight := {
	0: TextWord.PERFECT + TextStyle.STRAIGHT,
	1: TextWord.GREAT + TextStyle.STRAIGHT,
	-1: TextWord.GREAT + TextStyle.STRAIGHT,
	2: TextWord.GOOD + TextStyle.STRAIGHT,
	-2: TextWord.GOOD + TextStyle.STRAIGHT,
	3: TextWord.ALMOST + TextStyle.STRAIGHT,
	-3: TextWord.ALMOST + TextStyle.STRAIGHT,
	'MISS': TextWord.MISS + TextStyle.STRAIGHT
}

static func make_text_mesh(mesh: ArrayMesh, text_id: int, pos: Vector2, angle: float, alpha:=1.0, scale:=1.0):
	var r := GameTheme.judge_text_size2 * scale
	var vertex_array := PoolVector2Array([
		pos+polar2cartesian(r, angle+GameTheme.JUDGE_TEXT_ANG2), # TODO: fix this UV/vertex order mess
		pos+polar2cartesian(r, angle+GameTheme.JUDGE_TEXT_ANG1),
		pos+polar2cartesian(r, angle+GameTheme.JUDGE_TEXT_ANG4),
		pos+polar2cartesian(r, angle+GameTheme.JUDGE_TEXT_ANG3)
	])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_TEX_UV] = text_UV_arrays[text_id]
	arrays[Mesh.ARRAY_COLOR] = GameTheme.color_array_text(alpha)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)

static func make_judgement_text(mesh: ArrayMesh, text_id: int, col: int, progress:=0.0):
	make_text_mesh(mesh, text_id,
		GameTheme.RADIAL_UNIT_VECTORS[col] * GameTheme.receptor_ring_radius * lerp(0.85, 0.85*0.75, progress),
		GameTheme.RADIAL_COL_ANGLES[col]-PI/2.0, lerp(1.0, 0.0, progress), lerp(1.0, 0.75, progress)
	)

