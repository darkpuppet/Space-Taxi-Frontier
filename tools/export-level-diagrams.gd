extends SceneTree
## Export editable SVGs from the actual scene markers and configured hazard arrays.
const CAMPAIGN = preload("res://scripts/campaign.gd")
const OUTPUT = "res://docs/level-diagrams"
var parts: PackedStringArray = []
var inventory: PackedStringArray = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for number in [5, 20]:
		if not export_level(number):
			quit(1)
			return
	quit(0)

func escaped(value: String) -> String:
	return value.xml_escape(true)

func label(x: float, y: float, value: String, size: int = 23, color: String = "#263445") -> void:
	parts.append('<text x="%s" y="%s" font-family="sans-serif" font-size="%d" fill="%s">%s</text>' % [x, y, size, color, escaped(value)])

func layer(id: String, title: String) -> void:
	parts.append('<g id="%s" inkscape:groupmode="layer" inkscape:label="%s">' % [id, title])

func object_start(id: String, p: Vector2, title: String) -> void:
	parts.append('<g id="%s" inkscape:label="%s" transform="translate(%s %s)"><title>%s</title>' % [id, escaped(title), p.x, p.y, escaped(title)])

func bounds(id: String, p: Vector2, half: Vector2, color: String) -> void:
	parts.append('<rect id="%s-range" x="%s" y="%s" width="%s" height="%s" fill="none" stroke="%s" stroke-width="2" stroke-dasharray="10 8"/>' % [id, p.x-half.x, p.y-half.y, half.x*2, half.y*2, color])

func record(id: String, p: Vector2) -> void:
	inventory.append("%s   (%d, %d)" % [id, roundi(p.x), roundi(p.y)])

func export_level(number: int) -> bool:
	var scene: PackedScene = load(CAMPAIGN.level_scene_path(number - 1))
	var level = scene.instantiate()
	var config: Dictionary = level.configuration()
	var pads: Array = level.pad_layout()
	level.configure(config, pads)
	parts = PackedStringArray()
	inventory = PackedStringArray()
	parts.append('<?xml version="1.0" encoding="UTF-8"?>')
	parts.append('<svg xmlns="http://www.w3.org/2000/svg" xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" width="3100" height="1740" viewBox="0 0 3100 1740">')
	parts.append('<title>Level %02d - %s layout</title>' % [number, escaped(config["name"])])
	layer("page", "Page and legend")
	parts.append('<rect width="3100" height="1740" fill="white"/>')
	label(80, 65, "LEVEL %02d / %s" % [number, config["name"]], 36)
	label(80, 105, "2400 x 1440 world units | origin at upper left | X right, Y down | 100-unit grid", 23)
	parts.append('</g>')
	# Outer translation aligns the drawing with page margins; inner object transforms
	# remain world coordinates for straightforward editing in a vector program.
	parts.append('<g id="world" transform="translate(80 160)">')
	parts.append('<defs><clipPath id="world-clip"><rect width="2400" height="1440"/></clipPath></defs>')
	layer("grid", "Grid and world boundary")
	for x in range(0, 2401, 100):
		parts.append('<path d="M %d 0 V 1440" stroke="#e3e7ec" fill="none"/>' % x)
		if x % 200 == 0:
			label(x - 12, -16, str(x), 19)
	for y in range(0, 1441, 100):
		parts.append('<path d="M 0 %d H 2400" stroke="#e3e7ec" fill="none"/>' % y)
		if y % 200 == 0:
			label(-62, y + 7, str(y), 19)
	parts.append('<rect width="2400" height="1440" fill="none" stroke="#536174" stroke-width="3"/></g>')
	layer("movement", "Movement guides - center ranges, not collision extents")
	parts.append('<g clip-path="url(#world-clip)">')
	for i in range(level.aliens.size()):
		bounds("scout-%d" % (i+1), level.aliens[i]["home"], Vector2(145,55), "#b74135")
	for i in range(level.holes.size()):
		var hole: Dictionary = level.holes[i]
		bounds("well-%d" % (i+1), hole["home"], Vector2(hole["drift"],25), "#7443a4")
	for i in range(level.gates.size()):
		bounds("gate-%d" % (i+1), Vector2(1040,670), Vector2(9,80), "#ad6c13")
	for i in range(level.drones.size()):
		bounds("drone-%d" % (i+1), level.drones[i]["home"], Vector2(80,35), "#b74135")
	# Meteors wrap independently on each axis. Draw the first ten seconds only,
	# splitting paths at wraps so no false diagonal connects opposite boundaries.
	for i in range(level.meteors.size()):
		var home: Vector2 = level.meteors[i]["home"]
		var path := ""
		var previous := Vector2(-9999,-9999)
		for step in range(101):
			var t: float = step / 10.0
			var p := Vector2(fposmod(home.x+t*32,2200)+100, fposmod(home.y+t*65,1220)+100)
			path += (" M" if p.distance_to(previous)>100 else " L") + "%s %s" % [p.x,p.y]
			previous = p
		parts.append('<path id="meteor-%d-trace" d="%s" fill="none" stroke="#ad6c13" stroke-width="3" stroke-dasharray="10 8"/>' % [i+1,path])
	parts.append('</g></g>')
	layer("platforms", "Platforms - move each labelled group")
	for pad in pads:
		var p := Vector2(pad["x"],pad["y"])
		var id := "P%d" % pad["id"]
		object_start(id,p,"%s platform; width %d; %s" % [id,pad["width"],str(pad["services"])])
		var color := "#7451a8" if not pad["services"].is_empty() else "#21766d"
		parts.append('<rect x="%s" y="0" width="%s" height="27" fill="%s" fill-opacity="0.18" stroke="%s" stroke-width="2"/><path d="M %s 0 H %s" stroke="%s" stroke-width="5"/>' % [-pad["width"]/2,pad["width"],color,color,-pad["width"]/2,pad["width"]/2,color])
		label(-pad["width"]/2,-40,"%s%s" % [id," / SERVICES" if not pad["services"].is_empty() else ""],25,color)
		label(-pad["width"]/2,-12,"(%d, %d)  w=%d" % [p.x,p.y,pad["width"]],20)
		parts.append('</g>')
	parts.append('</g>')
	for family in ["asteroids","gates","mines","beams","holes","aliens","drones","meteors"]:
		layer(family, family.capitalize())
		var bodies: Array = level.get(family)
		var prefix: String = {"asteroids":"A","gates":"G","mines":"N","beams":"B","holes":"W","aliens":"S","drones":"D","meteors":"M"}[family]
		for i in range(bodies.size()):
			var p: Vector2 = bodies[i]["position"]
			var id := "%s%d" % [prefix,i+1]
			object_start(id,p,"%s %s" % [id,family])
			var color := "#b74135" if family in ["aliens","drones"] else ("#7443a4" if family=="holes" else "#ad6c13")
			match family:
				"gates":
					parts.append('<rect x="-9" y="-48" width="18" height="96" fill="#f4e0be" stroke="%s" stroke-width="3"/>' % color)
				"beams":
					parts.append('<rect x="-96" y="-6" width="192" height="12" fill="#f4e0be" stroke="%s" stroke-width="3"/>' % color)
				"mines", "drones":
					parts.append('<path d="M 0 -18 L 18 0 L 0 18 L -18 0 Z" fill="white" stroke="%s" stroke-width="3"/>' % color)
				_:
					var radius: int = 28 if family=="asteroids" else (24 if family=="aliens" else 18)
					parts.append('<circle r="%d" fill="white" stroke="%s" stroke-width="3"/>' % [radius,color])
					if family=="holes":
						parts.append('<circle r="10" fill="%s"/>' % color)
			label(32,40 if family=="holes" else -18,id,24,color)
			parts.append('</g>')
			record(id,p)
		parts.append('</g>')
	parts.append('</g>')
	layer("notes", "Legend, object coordinates and notes")
	var notes := ["KEY", "P  Platform (top = landing height)", "S  Scout     D  Hunter drone", "A  Asteroid  G  Moving gate", "N  Mine      B  Electric beam", "W  Gravity well   M  Meteor", "", "MOVEMENT GUIDES", "Dashed boxes: center ranges.", "Drones: nominal patrol only;", "can pursue and avoid docks/exit.", "Meteor trace: first 10 seconds;", "wraps at flight-lane edges.", "Wells pull across the whole world.", "Beam: on 3.0-4.8s of each 6s.", "", "INITIAL CENTERS (X, Y)"]
	var y := 185
	for line in notes:
		label(2540,y,line,22)
		y += 34
	for line in inventory:
		label(2540,y,line,22)
		y += 30
	label(80,1650,"Object positions: configure() snapshot before the first physics tick. Movement guides describe subsequent behavior.",22)
	label(80,1685,"Editable layout proposal: SVG edits do not change the game until applied to its level scenes / hazard configuration.",22)
	parts.append('</g></svg>')
	var path := "%s/level-%02d.svg" % [OUTPUT,number]
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		push_error("Cannot write " + path)
		level.free()
		return false
	file.store_string("\n".join(parts))
	file.close()
	print("Exported level %02d: %d pads, %d hazards" % [number,pads.size(),inventory.size()])
	level.free()
	return true
