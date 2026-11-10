extends SceneTree

func _init() -> void:
	var counts: Dictionary={}
	var rows: Array=[]
	var native:=0
	for id in SpeciesDB.all_ids():
		var species:=SpeciesDB.get_species(id)
		var row: Dictionary={"id":id,"dex":int(species.dex),"height_dm":int(species.height_dm),
			"size_tier":int(species.size_tier),"display_span":float(species.display_span),"radius":float(species.radius)}
		var tier:=str(row.size_tier)
		counts[tier]=int(counts.get(tier,0))+1
		row.native_art=FileAccess.file_exists(MonSprite.ROOT%int(species.dex)+"AnimData.xml")
		if row.native_art:
			var sprites:=MonSprite.load_set(int(species.dex))
			row.reference_span=float(sprites.reference_span)
			row.sprite_scale=PokemonSize.scale_for(species,sprites)
			native+=1
		rows.append(row)
	var report: Dictionary={"registered_species":rows.size(),"native_sprite_species":native,
		"common_eight_size_tiers_applied":true,"basis":"Default-form Pokedex height/body length, in decimeters",
		"tier_distribution":counts,"tiers":PokemonSize.tiers(),
		"display_size":"Tier display span divided by the maximum opaque Walk-frame extent across directions. One stable scale per species; shiny uses normal scale.",
		"ground_footprint":"Tier radius, capped below half of a 24px tile for one-tile doors. Gameplay movement speed and stats are unchanged.",
		"carrier":"Tiers 1-3: Pidgeotto; tiers 4-8: Pidgeot; scaled native head/claw contact.","species":rows}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/pokemon_sizes"))
	var json:=JSON.stringify(report,"  ")
	FileAccess.open("res://docs/pokemon_sizes/checks.json",FileAccess.WRITE).store_string(json)
	FileAccess.open("res://docs/fly_map/pokemon_sizes.json",FileAccess.WRITE).store_string(json)
	print("Size audit: %d species, eight shared tiers; %d native sprite sets normalized; distribution %s"%[rows.size(),native,str(counts)])
	quit()
