extends RefCounted

static func water_hit(w,target: Mon,dir: Vector2,pulse: bool) -> void:
	var body := Vector2(0,-target.radius*0.45)
	if pulse:
		for i in 2:
			w.add_fx("sprite",target.position+body,{"text":"g4_ring_q","body_impact":true,"follow":target,"offset":body,"size":target.radius*2.6,"stretch":0.72,"grow":2.1,"rot":float(i)*0.45,"color":Color(0.4,0.85,1.0,0.8),"delay":float(i)*0.08,"lifetime":0.34+float(i)*0.08,"fade_out":0.75})
	else:
		w.add_fx("sprite",target.position+body,{"text":"g4_splash","body_impact":true,"follow":target,"offset":body,"size":target.radius*2.2,"grow":1.4,"color":Color(0.7,0.95,1.0,0.88),"lifetime":0.22,"fade_out":0.7})
		w.add_fx("sprite",target.position+body,{"text":"g4_droplets","body_impact":true,"follow":target,"offset":body,"size":target.radius*2.1,"grow":1.6,"color":Color(0.35,0.78,1.0,0.85),"lifetime":0.28,"fade_out":0.8})
	for i in (6 if pulse else 3):
		var flow := dir.rotated((float(i)-(2.5 if pulse else 1.0))*(0.65 if pulse else 0.75))
		var offset := body+flow*target.radius*0.65
		w.add_fx("sprite",target.position+offset,{"text":"g4_glow","body_impact":true,"follow":target,"offset":offset,"size":3.2+float(i%2),"grow":0.35,"color":Color(0.45,0.87,1.0,0.8),"dir":flow,"speed":24.0+float(i%3)*6.0,"arc_h":6.0 if pulse else 4.0,"lifetime":0.32 if pulse else 0.25,"fade_out":0.75})

static func needle_hit(w,target: Mon,dir: Vector2) -> void:
	var body := Vector2(0,-target.radius*0.45)
	var entry := body-dir*target.radius*0.35
	w.add_fx("sprite",target.position+entry,{"text":"poison_needle","body_impact":true,"follow":target,"offset":entry,"size":5.3,"grow":0.35,"rot":dir.angle()+PI/2.0,"color":Color(0.96,0.83,1.0,0.85),"lifetime":0.10,"fade_out":0.6})
	w.add_fx("sprite",target.position+body,{"text":"g4_hitburst","body_impact":true,"follow":target,"offset":body,"size":target.radius*1.8,"grow":1.25,"color":Color(0.88,0.56,1.0,0.85),"lifetime":0.15,"fade_out":0.7})
	for i in 4:
		var offset := body+Vector2(float(i)-1.5,-0.5)*target.radius*0.4
		var flow := Vector2((float(i)-1.5)*0.35,-1).normalized()
		w.add_fx("sprite",target.position+offset,{"text":"g4_glow","body_impact":true,"follow":target,"offset":offset,"size":3.2+float(i%2),"grow":1.5,"color":Color(0.67,0.34,0.85,0.55),"dir":flow,"speed":10.0+float(i%2)*4.0,"delay":float(i)*0.02,"lifetime":0.30+float(i)*0.02,"fade_in":0.08,"fade_out":0.75})

# Native contact particles; only successful hits call this. No combat RNG.
static func contact_hit(w,target: Mon,move: String,dir: Vector2) -> void:
	var body := Vector2(0,-target.radius*0.45)
	var at := target.position+body
	var burst := "kanto_%s_%d"%[move,1 if move!="peck" else 0]
	var color := Color(1.0,0.88,0.42,0.95)
	var size := target.radius*(2.6 if move=="pound" else 1.9)
	w.add_fx("sprite",at,{"text":burst,"color":color,"size":size,"grow":1.45,"rot":dir.angle()+PI/4.0,"lifetime":0.18,"body_impact":true,"follow":target,"offset":body,"fade_out":0.7})
	if move=="pound":
		for i in 4:
			var flow := dir.rotated((float(i)-1.5)*0.65)
			w.add_fx("sprite",at+flow*target.radius*0.6,{"text":"kanto_pound_0","color":Color(1.0,0.57,0.20,0.75),"size":4.0,"grow":0.2,"dir":flow,"speed":28.0,"lifetime":0.22,"fade_out":0.7,"body_impact":true,"follow":target,"offset":body+flow*target.radius*0.6})
	elif move=="peck":
		w.add_fx("sprite",at,{"text":"kanto_peck_1","color":Color(1.0,0.96,0.78,0.9),"size":target.radius*2.3,"grow":1.4,"lifetime":0.22,"body_impact":true,"follow":target,"offset":body,"fade_out":0.8})
	else:
		for i in 5:
			var flow := Vector2.from_angle(TAU*float(i)/5.0)
			w.add_fx("sprite",at+flow*target.radius*0.7,{"text":"kanto_astonish_0","color":Color(0.4,0.85,1.0,0.8),"size":4.0+float(i%2),"grow":0.45,"dir":flow,"speed":32.0,"arc_h":5.0,"lifetime":0.27,"fade_out":0.8,"body_impact":true,"follow":target,"offset":body+flow*target.radius*0.7})

# Shared species-independent FX. No hit geometry, status rolls or combat RNG here.
# SV still-image reference: green energy; path/count/timing remain real-time adaptations.
static func drain(w,source: Mon,target: Mon,mega: bool) -> void:
	var count := 8 if mega else 5
	var from := target.position+Vector2(0,-target.radius*0.5)
	var prefix := "kanto_mega_drain_" if mega else "kanto_absorb_"
	w.add_fx("sprite",from,{"text":prefix+"2","color":Color(0.55,0.95,0.38,0.75),"size":target.radius*2.4,"grow":0.45,"lifetime":0.28,"follow":target,"offset":Vector2(0,-target.radius*0.5)})
	for i in count:
		var delay := float(i)*0.016
		var origin := from+Vector2.from_angle(TAU*float(i)/count)*target.radius*0.65
		w.add_fx("sprite",origin,{"text":"g4_glow","color":Color(0.48,0.96,0.24,0.9),"size":5.5 if mega else 4.0,"grow":0.65,"delay":delay,"lifetime":delay+0.40,"fade_in":0.12,"fade_out":0.22,
			"seek_target":source,"seek_from":origin,"seek_offset":Vector2(0,-source.radius*0.5),"seek_bend":(12.0 if i%2==0 else -12.0)*(1.3 if mega else 1.0),"arc_h":8.0})
	w.add_fx("sprite",source.position,{"text":prefix+"3","color":Color(0.60,0.96,0.40,0.7),"size":source.radius*(2.4 if mega else 1.8),"grow":1.4,"delay":0.30,"lifetime":0.60,"follow":source,"offset":Vector2(0,-source.radius*0.5),"fade_in":0.15,"fade_out":0.6})

static func sonic(w,source: Mon,mouth: Vector2,dir: Vector2,reach: float) -> void:
	var side := dir.orthogonal()
	for pulse in 3:
		for lane in 5:
			var offset := float(lane-2)/2.0
			var flow := (dir+side*offset*0.38).normalized()
			var delay := float(pulse)*0.075
			w.add_fx("sprite",mouth+side*offset*source.radius*0.4,{"text":"g4_streak","sound_fracture":true,"color":Color(1.0,0.81,0.24,0.9-float(pulse)*0.15),"size":1.5,"stretch":3.4,"grow":2.3,
				"rot":side.angle()+PI/2.0+offset*0.20,"dir":flow,"speed":reach/0.36,"delay":delay,"lifetime":delay+0.36,"fade_in":0.04,"fade_out":0.5})
		# Broken original Supersonic wave fragments; never a complete circle.
		w.add_fx("sprite",mouth,{"text":"kanto_supersonic_0","sound_fracture":true,"color":Color(1,0.92,0.48,0.6),"size":source.radius*1.2,"grow":2.6,"stretch":0.65,"rot":dir.angle()+PI/4.0,"dir":dir,"speed":reach/0.38,"delay":pulse*0.075,"lifetime":pulse*0.075+0.38,"fade_out":0.6})

static func acid_hit(w,target: Mon,dir: Vector2) -> void:
	var body := Vector2(0,-target.radius*0.45)
	w.add_fx("sprite",target.position+body,{"text":"kanto_acid_1","color":Color(0.82,0.82,0.12,0.8),"size":target.radius*3.0,"grow":1.45,"lifetime":0.28,"follow":target,"offset":body,"fade_out":0.7})
	for i in 5:
		var spread := dir.rotated((i-2)*0.55)
		w.add_fx("sprite",target.position+body+spread*target.radius*0.8,{"text":"g4_glow","color":Color(0.72,0.73,0.10,0.85),"size":3.2+float(i%2),"grow":0.25,"dir":spread,"speed":26.0+float(i%3)*9.0,"lifetime":0.30,"arc_h":8.0,"fade_out":0.65})

static func sing(w,source: Mon,mouth: Vector2,dir: Vector2,reach: float) -> void:
	var side := dir.orthogonal()
	# SV stills show notes together with purple wave fronts. Timing stays custom.
	for pulse in 3:
		var delay := float(pulse)*0.12
		w.add_fx("sprite",mouth,{"text":"g4_ring_q","aimed_wave":true,"color":Color(0.72,0.47,1.0,0.58),"size":source.radius*2.0,"stretch":0.50,"grow":1.65,"rot":dir.angle()+PI/2.0,"dir":dir,"speed":reach/0.60,
			"delay":delay,"lifetime":delay+0.50,"fade_in":0.12,"fade_out":0.6})
	for i in 6:
		var delay := float(i)*0.075
		var flow := (dir+side*sin(float(i)*1.9)*0.20).normalized()
		w.add_fx("sprite",mouth,{"text":"kanto_sing_%d"%(1+i%3),"color":Color(0.78+float(i%2)*0.10,0.60,1.0,0.90),"size":9.0+float(i%3),"grow":1.10,"rot":sin(float(i))*0.12,"spin":0.5 if i%2==0 else -0.5,
			"dir":flow,"speed":reach/0.55,"arc_h":8.0+float(i%2)*3.0,"delay":delay,"lifetime":delay+0.55,"fade_in":0.08,"fade_out":0.4})

# SV still-image composition: blue rings and lavender crescents around the caster.
# Layer counts, orbit and timing are real-time adaptations; no fixed eye positions.
static func hypnosis(w,source: Mon,_dir: Vector2,_reach: float) -> void:
	var body := Vector2(0,-source.radius*0.35)
	for i in 3:
		var delay := float(i)*0.07
		w.add_fx("sprite",source.position+body,{"text":"g4_ring_q","caster_aura":true,"body_impact":true,"follow":source,"offset":body,
			"color":Color(0.36+float(i)*0.08,0.65+float(i)*0.04,1.0,0.42-float(i)*0.04),"size":source.radius*(2.3+float(i)*0.5),"stretch":1.0-float(i)*0.05,"grow":1.10,
			"rot":float(i)*0.12,"spin":0.3 if i%2==0 else -0.3,"delay":delay,"lifetime":delay+0.56,"fade_in":0.16,"fade_out":0.50})
	for i in 4:
		var phase := TAU*float(i)/4.0
		w.add_fx("sprite",source.position+body,{"text":"g4_vine_arc","caster_aura":true,"body_impact":true,"follow":source,"offset":body,
			"color":Color(0.84,0.72,1.0,0.70),"size":source.radius*1.8,"stretch":1.0,"grow":0.85,"rot":phase+PI,"spin":1.6,
			"orbit_r":source.radius*1.05,"orbit_speed":1.6,"orbit_phase":phase,"lifetime":0.62,"fade_in":0.16,"fade_out":0.50})

static func voice_hit(w,target: Mon) -> void:
	var body := Vector2(0,-target.radius*0.45)
	w.add_fx("sprite",target.position+body,{"text":"kanto_disarming_voice_0","body_impact":true,"color":Color(1.0,0.68,0.84,0.65),"size":target.radius*2.4,"grow":1.5,"lifetime":0.25,"follow":target,"offset":body,"fade_out":0.75})
	for i in 3:
		var offset := body+Vector2(float(i)-1.0,-0.3)*target.radius*0.8
		w.add_fx("sprite",target.position+offset,{"text":"kanto_sing_%d"%(1+i),"body_impact":true,"follow":target,"offset":offset,"color":Color(1.0,0.72,0.88,0.90),"size":5.5+float(i%2),"grow":0.75,"dir":Vector2((float(i)-1.0)*0.3,-1).normalized(),"speed":14.0,"rot":float(i-1)*0.1,"lifetime":0.28,"fade_out":0.7})
