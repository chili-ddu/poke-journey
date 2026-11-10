extends SceneTree

## Read-only content inventory. Never loads a player save or gameplay scene.
const Continent=preload("res://scripts/data/continent_world.gd")
const Regional=preload("res://scripts/story/regional_quests.gd")
const Campaign=preload("res://scripts/story/campaign_quests.gd")
const OUT="res://docs/continent_world/route_event_inventory.json"

func _init() -> void:run.call_deferred()

func run() -> void:
	var roads: Array=[]
	var native:=Continent.scene()
	var offset:=Continent.offset()
	var kanto: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/kanto_world/map.json"))
	for number in range(1,49):
		var id: String="route%d" % number
		var rectangles: Array=[]
		if number<=25:
			for area in kanto.areas:
				if area.id!=id and not (number==21 and String(area.id).begins_with("route21_")):continue
				rectangles.append([int(area.x),int(area.y),int(area.w),int(area.h)])
		else:
			var header:=0
			for key in Continent.collection().manifest.headers:
				if Continent.collection().manifest.headers[key].constant=="MAP_ROUTE_%d" % number:header=int(key)
			assert(header!=0,"Missing native route "+str(number))
			for area in native.areas:
				if int(area.header)!=header:continue
				rectangles.append([int(area.x)+offset.x,int(area.z)+offset.y,int(area.width),int(area.height)])
		assert(not rectangles.is_empty(),"Missing exterior route "+str(number))
		var center:=Vector2.ZERO;var weight:=0.0
		var centers: Array[Vector2]=[]
		for rect in rectangles:
			var at:=Vector2(rect[0]+rect[2]*0.5,rect[1]+rect[3]*0.5)
			centers.append(at);center+=at*float(rect[2]*rect[3]);weight+=float(rect[2]*rect[3])
		center/=weight
		centers.sort_custom(func(a,b):return a.distance_squared_to(center)<b.distance_squared_to(center))
		roads.append({"number":number,"area":id,"rects":rectangles,"anchor":[centers[0].x,centers[0].y]})
	var result: Dictionary={"roads":roads,"regional_quests":Regional.quests("charmander"),"campaign_quests":Campaign.quests(),
		"rival_stages":preload("res://scripts/data/rival_progression.gd").STAGES,
		"gyms":TrainerDB.GymData.GYMS,"source":"current runtime catalogs and original exterior area rectangles","save_access":false}
	FileAccess.open(OUT,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("Inventoried ",roads.size()," routes, ",result.regional_quests.size()," regional quests, ",result.campaign_quests.size()," campaign entries, ",result.gyms.size()," gyms")
	quit()
