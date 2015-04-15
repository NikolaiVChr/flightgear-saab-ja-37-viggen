

var AcModel        = props.globals.getNode("sim/ja37");
var OurHdg         = props.globals.getNode("orientation/heading-deg");
var OurRoll        = props.globals.getNode("orientation/roll-deg");
var OurPitch       = props.globals.getNode("orientation/pitch-deg");
var HudReticleDev  = props.globals.getNode("sim/ja37/hud/reticle-total-deviation", 1);#polar coords
var HudReticleDeg  = props.globals.getNode("sim/ja37/hud/reticle-total-angle", 1);
var aim_9_model    = "Aircraft/JA37/Models/Armament/Weapons/RB-24J/rb-24j-";
var SwSoundOnOff   = AcModel.getNode("armament/rb24/sound-on-off");
var SwSoundVol     = AcModel.getNode("armament/rb24/sound-volume");
var vol_search     = 0.03;
var vol_weak_track = 0.10;
var vol_track      = 0.15;
var update_loop_time = 0.035;

var g_fps        = 9.80665 * M2FT;
var slugs_to_lbs = 32.1740485564;


var AIM9 = {
	#done
	new : func (p) {
		if(AIM9.active[p] != nil) {
			#do not make new missile logic if one exist for this pylon.
			return -1;
		}
		var m = { parents : [AIM9]};
		# Args: p = Pylon.

		m.status            = 0; # -1 = stand-by, 0 = searching, 1 = locked, 2 = fired.
		m.free              = 0; # 0 = status fired with lock, 1 = status fired but having lost lock.
		m.trackWeak         = 1;

		m.prop              = AcModel.getNode("armament/rb24/").getChild("msl", 0 , 1);
		m.PylonIndex        = m.prop.getNode("pylon-index", 1).setValue(p);
		m.ID                = p;
		m.pylon_prop        = props.globals.getNode("controls/armament").getChild("station", p+1);
		m.Tgt               = nil;
		m.TgtValid          = nil;
		m.TgtLon_prop       = nil;
		m.TgtLat_prop       = nil;
		m.TgtAlt_prop       = nil;
		m.TgtHdg_prop       = nil;
		m.update_track_time = 0;
		m.seeker_dev_e      = 0; # Seeker elevation, deg.
		m.seeker_dev_h      = 0; # Seeker horizon, deg.
		m.curr_tgt_e        = 0;
		m.curr_tgt_h        = 0;
		m.init_tgt_e        = 0;
		m.init_tgt_h        = 0;
		m.target_dev_e      = 0; # Target elevation, deg.
		m.target_dev_h      = 0; # Target horizon, deg.
		m.track_signal_e    = 0; # Seeker deviation change to keep constant angle (proportional navigation),
		m.track_signal_h    = 0; #   this is directly used as input signal for the steering command.
		m.t_coord           = geo.Coord.new().set_latlon(0, 0, 0);
		m.last_t_coord      = m.t_coord;
		#m.next_t_coord      = m.t_coord;
		m.direct_dist_m     = nil;

		# AIM-9L specs:
		m.aim9_fov_diam     = getprop("sim/ja37/armament/rb24/fov-deg");
		m.aim9_fov          = m.aim9_fov_diam / 2;
		m.max_detect_rng    = getprop("sim/ja37/armament/rb24/max-detection-rng-nm");
		m.max_seeker_dev    = getprop("sim/ja37/armament/rb24/track-max-deg") / 2;
		m.force_lbs         = getprop("sim/ja37/armament/rb24/thrust-lbs");
		m.thrust_duration   = getprop("sim/ja37/armament/rb24/thrust-duration-sec");
		m.weight_launch_lbs = getprop("sim/ja37/armament/rb24/weight-launch-lbs");
		m.weight_whead_lbs  = getprop("sim/ja37/armament/rb24/weight-warhead-lbs");
		m.cd                = getprop("sim/ja37/armament/rb24/drag-coeff");
		m.eda               = getprop("sim/ja37/armament/rb24/drag-area");
		m.max_g             = getprop("sim/ja37/armament/rb24/max-g");
		m.dt_last           = 0;
		# Find the next index for "models/model" and create property node.
		# Find the next index for "ai/models/aim-9" and create property node.
		# (M. Franz, see Nasal/tanker.nas)
		var n = props.globals.getNode("models", 1);
		var i = 0;
		for (i = 0; 1==1; i += 1) {
			if (n.getChild("model", i, 0) == nil) {
				break;
			}
		}
		m.model = n.getChild("model", i, 1);
		
		n = props.globals.getNode("ai/models", 1);
		for (i = 0; 1==1; i += 1) {
			if (n.getChild("rb-24j", i, 0) == nil) {
				break;
			}
		}
		m.ai = n.getChild("rb-24j", i, 1);

		m.ai.getNode("valid", 1).setBoolValue(1);
		m.ai.getNode("name", 1).setValue("RB-24J");
		m.ai.getNode("sign", 1).setValue("Sidewinder");
		#m.model.getNode("collision", 1).setBoolValue(0);
		#m.model.getNode("impact", 1).setBoolValue(0);
		var id_model = aim_9_model ~ m.ID ~ ".xml";
		m.model.getNode("path", 1).setValue(id_model);
		m.life_time = 0;

		# Create the AI position and orientation properties.
		m.latN   = m.ai.getNode("position/latitude-deg", 1);
		m.lonN   = m.ai.getNode("position/longitude-deg", 1);
		m.altN   = m.ai.getNode("position/altitude-ft", 1);
		m.hdgN   = m.ai.getNode("orientation/true-heading-deg", 1);
		m.pitchN = m.ai.getNode("orientation/pitch-deg", 1);
		m.rollN  = m.ai.getNode("orientation/roll-deg", 1);

		m.ac      = nil;
		m.coord   = geo.Coord.new().set_latlon(0, 0, 0);
		m.s_down  = nil;
		m.s_east  = nil;
		m.s_north = nil;
		m.alt     = nil;
		m.pitch   = nil;
		m.hdg     = nil;

		SwSoundOnOff.setValue(1);

		settimer(func { SwSoundVol.setValue(vol_search); me.trackWeak = 1; m.search() }, 1);
		return AIM9.active[m.ID] = m;

	},
	#done
	del: func {
		#print("deleted");
		me.model.remove();
		me.ai.remove();
		if (me.status == 2) {
			delete(AIM9.flying, me.flyID);
		} else {
			delete(AIM9.active, me.ID);
		}
	},
	#done
	release: func() {
		me.status = 2;
		me.flyID = rand();
		AIM9.flying[me.flyID] = me;
		delete(AIM9.active, me.ID);
		me.animation_flags_props();

		# Get the A/C position and orientation values.
		me.ac = geo.aircraft_position();
		var ac_roll  = getprop("orientation/roll-deg");
		var ac_pitch = getprop("orientation/pitch-deg");
		var ac_hdg   = getprop("orientation/heading-deg");

		# Compute missile initial position relative to A/C center,
		# following Vivian's code in AIModel/submodel.cxx .
		var in = [0,0,0];
		var trans = [[0,0,0],[0,0,0],[0,0,0]];
		var out = [0,0,0];

		in[0] =  me.pylon_prop.getNode("offsets/x-m").getValue() * M2FT;
		in[1] =  me.pylon_prop.getNode("offsets/y-m").getValue() * M2FT;
		in[2] =  me.pylon_prop.getNode("offsets/z-m").getValue() * M2FT;
		# Pre-process trig functions:
		cosRx = math.cos(-ac_roll * D2R);
		sinRx = math.sin(-ac_roll * D2R);
		cosRy = math.cos(-ac_pitch * D2R);
		sinRy = math.sin(-ac_pitch * D2R);
		cosRz = math.cos(ac_hdg * D2R);
		sinRz = math.sin(ac_hdg * D2R);
		# Set up the transform matrix:
		trans[0][0] =  cosRy * cosRz;
		trans[0][1] =  -1 * cosRx * sinRz + sinRx * sinRy * cosRz ;
		trans[0][2] =  sinRx * sinRz + cosRx * sinRy * cosRz;
		trans[1][0] =  cosRy * sinRz;
		trans[1][1] =  cosRx * cosRz + sinRx * sinRy * sinRz;
		trans[1][2] =  -1 * sinRx * cosRx + cosRx * sinRy * sinRz;
		trans[2][0] =  -1 * sinRy;
		trans[2][1] =  sinRx * cosRy;
		trans[2][2] =  cosRx * cosRy;
		# Multiply the input and transform matrices:
		out[0] = in[0] * trans[0][0] + in[1] * trans[0][1] + in[2] * trans[0][2];
		out[1] = in[0] * trans[1][0] + in[1] * trans[1][1] + in[2] * trans[1][2];
		out[2] = in[0] * trans[2][0] + in[1] * trans[2][1] + in[2] * trans[2][2];
		# Convert ft to degrees of latitude:
		out[0] = out[0] / (366468.96 - 3717.12 * math.cos(me.ac.lat() * D2R));
		# Convert ft to degrees of longitude:
		out[1] = out[1] / (365228.16 * math.cos(me.ac.lat() * D2R));
		# Set submodel initial position:
		var alat = me.ac.lat() + out[0];
		var alon = me.ac.lon() + out[1];
		var aalt = (me.ac.alt() * M2FT) + out[2];
		me.latN.setDoubleValue(alat);
		me.lonN.setDoubleValue(alon);
		me.altN.setDoubleValue(aalt);
		me.hdgN.setDoubleValue(ac_hdg);
		me.pitchN.setDoubleValue(ac_pitch);
		me.rollN.setDoubleValue(ac_roll);
		#print("roll "~ac_roll~" on "~me.rollN.getPath());
		me.coord.set_latlon(alat, alon, aalt / M2FT); # was (alat, alon, me.ac.alt())

		me.model.getNode("latitude-deg-prop", 1).setValue(me.latN.getPath());
		me.model.getNode("longitude-deg-prop", 1).setValue(me.lonN.getPath());
		me.model.getNode("elevation-ft-prop", 1).setValue(me.altN.getPath());
		me.model.getNode("heading-deg-prop", 1).setValue(me.hdgN.getPath());
		me.model.getNode("pitch-deg-prop", 1).setValue(me.pitchN.getPath());
		me.model.getNode("roll-deg-prop", 1).setValue(me.rollN.getPath());
		me.model.getNode("load", 1).remove();
		
		# Get initial velocity vector (aircraft):
		me.s_down = getprop("velocities/speed-down-fps");
		me.s_east = getprop("velocities/speed-east-fps");
		me.s_north = getprop("velocities/speed-north-fps");

		me.alt = aalt;
		me.pitch = ac_pitch;
		me.hdg = ac_hdg;

		me.smoke_prop.setBoolValue(1);
		SwSoundVol.setValue(0);
		me.trackWeak = 1;
		#settimer(func { HudReticleDeg.setValue(0) }, 2);
		#interpolate(HudReticleDev, 0, 2);
		me.update();

	},




	# steering missile
	update: func {
		var dt = getprop("sim/time/delta-sec");#TODO: find out more about how this property works
		if (dt == 0) {
			#FG is likely paused
			settimer(func me.update(), 0.01);
			return;
		}
		#dt = update_loop_time;
		var elapsed = systime();
		if (me.dt_last != 0) {
			dt = (elapsed - me.dt_last) * getprop("sim/speed-up");
		}
		me.dt_last = elapsed;

		var init_launch = 0;
		if ( me.life_time > 0.35 ) { #due to chance for hitting the aircraft, the missile will not guide until after its clear of the aircraft.
			init_launch = 1;
		}
		me.life_time += dt;
		# record coords so we can give the latest nearest position for impact.
		me.last_coord = me.coord;


		#### Calculate speed vector before steering corrections.

		# Cut rocket thrust after boost duration.
		var f_lbs = me.force_lbs;
		if (me.life_time > 2) {
			f_lbs = me.force_lbs * 0.3;
		}
		if (me.life_time > me.thrust_duration) {
			#print("lifetime "~me.life_time);
			f_lbs = 0; me.smoke_prop.setBoolValue(0);
		}

		# Kill the AI after a while.
		if (me.life_time > 60) { return me.del(); }

		# Get total speed.
		var d_east_ft  = me.s_east * dt;
		var d_north_ft = me.s_north * dt;
		var d_down_ft  = me.s_down * dt;
		var pitch_deg  = me.pitch;
		var hdg_deg    = me.hdg;
		var dist_h_ft  = math.sqrt((d_east_ft*d_east_ft)+(d_north_ft*d_north_ft));
		var total_s_ft = math.sqrt((dist_h_ft*dist_h_ft)+(d_down_ft*d_down_ft));

		# Get air density and speed of sound (fps):
		var alt_ft = me.altN.getValue();
		var rs = rho_sndspeed(alt_ft);
		var rho = rs[0];
		var sound_fps = rs[1];

		# Adjust Cd by Mach number. The equations are based on curves
		# for a conventional shell/bullet (no boat-tail).
		var cdm = 0;
		var speed_m = (total_s_ft / dt) / sound_fps;
		#print("mach "~speed_m);
		if (speed_m < 0.7)
		 cdm = 0.0125 * speed_m + me.cd;
		elsif (speed_m < 1.2 )
		 cdm = 0.3742 * math.pow(speed_m, 2) - 0.252 * speed_m + 0.0021 + me.cd;
		else
		 cdm = 0.2965 * math.pow(speed_m, -1.1506) + me.cd;

		# Add drag to the total speed using Standard Atmosphere (15C sealevel temperature);
		# rho is adjusted for altitude in environment.rho_sndspeed(altitude),
		# Acceleration = thrust/mass - drag/mass;
		var mass = me.weight_launch_lbs / slugs_to_lbs;
		var old_speed_fps = total_s_ft / dt;
		var acc = f_lbs / mass;

		var drag_acc = (cdm * 0.5 * rho * old_speed_fps * old_speed_fps * me.eda / mass);
		var speed_fps = old_speed_fps - drag_acc + acc;

		# Break down total speed to North, East and Down components.
		var speed_down_fps = math.sin(pitch_deg * D2R) * speed_fps;
		var speed_horizontal_fps = math.cos(pitch_deg * D2R) * speed_fps;
		var speed_north_fps = math.cos(hdg_deg * D2R) * speed_horizontal_fps;
		var speed_east_fps = math.sin(hdg_deg * D2R) * speed_horizontal_fps;

		# Add gravity to the vertical speed (no ground interaction yet).
		speed_down_fps -= 32.1740485564 * dt;
		
		# Calculate altitude and elevation velocity vector (no incidence here).
		var alt_ft = me.altN.getValue() + (speed_down_fps * dt);
		pitch_deg = math.atan2( speed_down_fps, speed_horizontal_fps ) * R2D;
		me.pitch = pitch_deg;
		
		var dist_h_m = speed_horizontal_fps * dt * FT2M;

		#print("alt "~alt_ft);

		#### Guidance.

		if ( me.status == 2 and me.free == 0) {
			me.update_track(dt);
			if (init_launch == 0 ) {
				# Use the rail or a/c pitch for the first frame.
				pitch_deg = getprop("orientation/pitch-deg");
			} else {
				#print("steering");
				pitch_deg += me.track_signal_e;
				hdg_deg += me.track_signal_h;
			}
		}

		

		# Get horizontal distance and set position and orientation.
		var dist_h_m = speed_horizontal_fps * dt * FT2M;
		me.coord.apply_course_distance(hdg_deg, dist_h_m);
		me.latN.setDoubleValue(me.coord.lat());
		me.lonN.setDoubleValue(me.coord.lon());
		me.altN.setDoubleValue(alt_ft);
		me.coord.set_alt(alt_ft*0.3048);
		me.pitchN.setDoubleValue(pitch_deg);
		me.hdgN.setDoubleValue(hdg_deg);

		# set radar properties for use in selection view and HUD tracks.
		var self = geo.aircraft_position();
		me.ai.getNode("radar/bearing-deg", 1).setValue(self.course_to(me.coord));
		var angleInv = me.clamp(self.distance_to(me.coord)/self.direct_distance_to(me.coord), -1, 1);
		me.ai.getNode("radar/elevation-deg", 1).setValue((self.alt()>me.coord.alt()?-1:1)*math.acos(angleInv)*R2D);
		me.ai.getNode("velocities/true-airspeed-kt",1).setValue(speed_fps*0.5924838);

		#### Proximity detection.
		if ( me.status == 2 ) {
			#### check if the missile can keep the lock.
 			if ( me.free == 0 ) {
				var g = steering_speed_G(me.track_signal_e, me.track_signal_h, (total_s_ft / dt), mass, dt);
				if ( g > me.max_g ) {
					#print("lost lock "~g~"G");
					# Target unreachable, fly free.
					me.free = 1;
				}
			}
			var v = me.poximity_detection();
			if ( ! v ) {
				#print("exploded");
				# We exploded, and start the sound propagation towards the plane
				me.sndSpeed = sound_fps;
				me.sndDistance = 0;
				me.dt_last = systime();
				me.sndPropagate();
				return;
			}
			if (alt_ft < -75) {
				#it must have hit ground (tmp fix to not keep it flying for a minute)
				#print("rb24 hit ground");
				me.del();
				return;
			}
		}
		# record the velocities for the next loop.
		me.s_north = speed_north_fps;
		me.s_east = speed_east_fps;
		me.s_down = speed_down_fps;
		me.alt = alt_ft;
		me.pitch = pitch_deg;
		me.hdg = hdg_deg;

		settimer(func me.update(), 0.03, 1);# update_loop_time, 1);
		
	},


	update_track: func(dt) {
		if ( me.Tgt == nil ) {
		 #print("no target");
		 return(1);
		}
		if (me.status == 0) {
			# Status = searching.
			me.reset_seeker();
			SwSoundVol.setValue(vol_search);
			me.trackWeak = 1;
			settimer(func me.search(), 0.1);
			return(1);
		}
		if ( me.status == -1 ) {
			# Status = stand-by.
			me.reset_seeker();
			SwSoundVol.setValue(0);
			me.trackWeak = 1;
			return(1);
		}
		if (!me.Tgt.getChild("valid").getValue()) {
			# Lost of lock due to target disapearing:
			# return to search mode.
			#print("invalid");
			me.status = 0;
			me.reset_seeker();
			SwSoundVol.setValue(vol_search);
			me.trackWeak = 1;
			settimer(func me.search(), 0.1);
			return(1);
		}
		#print("track");
		# Time interval since lock time or last track loop.
		if (dt == nil) {
			var time = props.globals.getNode("/sim/time/elapsed-sec", 1).getValue();
			dt = time - me.update_track_time;
			me.update_track_time = time;
		}
		var last_tgt_e = me.curr_tgt_e;
		var last_tgt_h = me.curr_tgt_h;
		if (me.status == 1) {		
			# Status = locked. Get target position relative to our aircraft.
			me.curr_tgt_e = - deviation_normdeg(OurPitch.getValue(), me.Tgt.getChild("radar").getChild("elevation-deg").getValue());
			me.curr_tgt_h = - deviation_normdeg(OurHdg.getValue(), me.Tgt.getChild("radar").getChild("bearing-deg").getValue());
		} else {
			# Status = launched. Compute target position relative to seeker head.

			# Get target position.
			var t_alt = me.TgtAlt_prop.getValue();
			me.t_coord.set_latlon(me.TgtLat_prop.getValue(), me.TgtLon_prop.getValue(), t_alt * 0.3048);

			# Calculate current target elevation and azimut deviation.
			var t_dist_m = me.coord.distance_to(me.t_coord);
			var t_alt_delta_m = (t_alt - me.alt) * FT2M;
			var t_elev_deg =  math.atan2( t_alt_delta_m, t_dist_m ) * R2D;
			me.curr_tgt_e = t_elev_deg - me.pitch;
			var t_course = me.coord.course_to(me.t_coord);
			me.curr_tgt_h = t_course - me.hdg;

			#print("tgt alt: "~t_alt~" me alt: "~me.alt);

			# Compute gain to reduce target deviation to match an optimum 3 deg
			# This augments steering by an additional 10 deg per second during
			# the trajectory first 2 seconds.
			# Then, keep track of deviations at the end of these two initial 2 seconds.
			var e_gain = 1;
			var h_gain = 1;
			if ( me.life_time < 0.75 ) {
				if (me.curr_tgt_e > 3 or me.curr_tgt_e < - 3) {
					e_gain = 1 + (0.1 * dt);
				}
				if (me.curr_tgt_h > 3 or me.curr_tgt_h < - 3) {
					h_gain = 1 + (0.1 * dt);
				}
				me.init_tgt_e = last_tgt_e;
				me.init_tgt_h = last_tgt_h;			
			}

			# Compute target deviation variation then seeker move to keep this deviation constant.
			me.track_signal_e = (me.curr_tgt_e - me.init_tgt_e) * e_gain;
			me.track_signal_h = (me.curr_tgt_h - me.init_tgt_h) * h_gain;
			
#print ("**** curr_tgt_e = ", me.curr_tgt_e," curr_tgt_h = ", me.curr_tgt_h, " me.track_signal_e = ", me.track_signal_e," me.track_signal_h = ", me.track_signal_h);


		}
		# Compute HUD reticle position.
		if ( 1==0 and me.status == 1 ) {
			var h_rad = (90 - me.curr_tgt_h) * D2R;
			var e_rad = (90 - me.curr_tgt_e) * D2R; 
			var devs = develev_to_devroll(h_rad, e_rad);
			var combined_dev_deg = devs[0];
			var combined_dev_length =  devs[1];
			var clamped = devs[2];
			if ( clamped ) { SW_reticle_Blinker.blink();}
			else { SW_reticle_Blinker.cont();}
			HudReticleDeg.setValue(combined_dev_deg);
			HudReticleDev.setValue(combined_dev_length);
		}
		if ( me.status != 2 and me.status != -1 ) {
			me.check_t_in_fov();
			# We are not launched yet: update_track() loops by itself at 10 Hz.
			SwSoundVol.setValue(vol_track);
			me.trackWeak = 0;
			settimer(func me.update_track(nil), 0.1);
		}
		return(1);
	},



	#done
	poximity_detection: func {
		var cur_dir_dist_m = me.coord.direct_distance_to(me.t_coord);
		# Get current direct distance.
		#print("distance to target_m = ",cur_dir_dist_m," prev_distance to target_m = ",me.direct_dist_m);
		if ( me.direct_dist_m != nil and me.ac.direct_distance_to(me.coord) > 50) {#don't arm before 50m away from plane
			if ( cur_dir_dist_m > me.direct_dist_m and me.direct_dist_m < 65 ) {
				#print("passed target");
				# Distance to target increase, trigger explosion.
				me.explode();
				return(0);
			#} #elsif (cur_dir_dist_m < 20) {
			#	print("proximity fuse activated.");
				#within killing distance, explode 
				#(this might not be how the real thing does, but due to this only being called every frame, might miss otherwise)
			#	me.explode();
			#	return(0);
			} elsif (me.free == 1 and cur_dir_dist_m < 20) {
				#print("Magnetic fuse active.");
				# lost lock, magnetic detector checks if close enough to explode
				me.explode();
				return(0);
			}
		}
		me.last_t_coord = me.t_coord;
		me.direct_dist_m = cur_dir_dist_m;
		return(1);
	},

	explode: func {
		# Get missile relative position to the target at last frame.
		var t_bearing_deg = me.last_t_coord.course_to(me.last_coord);
		var t_delta_alt_m = me.last_coord.alt() - me.last_t_coord.alt();
		var new_t_alt_m = me.t_coord.alt() + t_delta_alt_m;
		var t_dist_m  = math.sqrt(math.abs((me.direct_dist_m * me.direct_dist_m)-(t_delta_alt_m * t_delta_alt_m)));
		# Create impact coords from this previous relative position applied to target current coord.
		me.t_coord.apply_course_distance(t_bearing_deg, t_dist_m);
		me.t_coord.set_alt(new_t_alt_m);		
		var wh_mass = me.weight_whead_lbs / slugs_to_lbs;
		#print("FOX2: me.direct_dist_m = ",  me.direct_dist_m, " time ",getprop("sim/time/elapsed-sec"));
		impact_report(me.t_coord, wh_mass, "missile"); # pos, alt, mass_slug,(speed_mps)

		var ident = nil;
		if(me.Tgt.getChild("callsign").getValue() != "" and me.Tgt.getChild("callsign").getValue() != nil) {
          ident = me.Tgt.getChild("callsign").getValue();
        } elsif (me.Tgt.getChild("name").getValue() != "" and me.Tgt.getChild("name").getValue() != nil) {
          ident = me.Tgt.getChild("name").getValue();
        } elsif (me.Tgt.getChild("sign").getValue() != "" and me.Tgt.getChild("sign").getValue() != nil) {
          ident = me.Tgt.getChild("sign").getValue();
        } else {
          ident = "unknown";
        }

		var phrase = sprintf( "RB-24J exploded %01.0f", me.direct_dist_m) ~ " meters from " ~ ident;
		if (getprop("sim/ja37/armament/msg")) {
			setprop("/sim/multiplay/chat", phrase);
		} else {
			setprop("/sim/messages/atc", phrase);
		}
		me.ai.getNode("valid", 1).setBoolValue(0);
		me.animate_explosion();
		me.Tgt = nil;
	},

	#
	check_t_in_fov: func {
		# Used only when not launched.
		# Compute seeker total angular position clamped to seeker max total angular rotation.
		me.seeker_dev_e += me.track_signal_e;
		me.seeker_dev_e = me.clamp_min_max(me.seeker_dev_e, me.max_seeker_dev);
		me.seeker_dev_h += me.track_signal_h;
		me.seeker_dev_h = me.clamp_min_max(me.seeker_dev_h, me.max_seeker_dev);
		# Check target signal inside seeker FOV.
		var e_d = me.seeker_dev_e - me.aim9_fov;
		var e_u = me.seeker_dev_e + me.aim9_fov;
		var h_l = me.seeker_dev_h - me.aim9_fov;
		var h_r = me.seeker_dev_h + me.aim9_fov;
		if ( me.curr_tgt_e < e_d or me.curr_tgt_e > e_u or me.curr_tgt_h < h_l or me.curr_tgt_h > h_r ) {		
			# Target out of FOV while still not launched, return to search loop.
			me.status = 0;
			settimer(func me.search(), rand()*3.5);
			me.Tgt = nil;
			SwSoundVol.setValue(vol_search);
			me.trackWeak = 1;
			me.reset_seeker();
		}
		return(1);
	},

	# aircraft searching for lock
	search: func {
		if ( me.status == -1 ) {
			# Stand by.
			SwSoundVol.setValue(0);
			me.trackWeak = 1;
			return;
		} elsif ( me.status > 0 ) {
			# Locked or fired.
			return;
		}
		#print("search");
		# search.
		if ( canvas_HUD.diamond_node != nil and canvas_HUD.diamond_node.getChild("valid").getValue() == 1) {
			var tgt = canvas_HUD.diamond_node; # In the radar range and horizontal field.
			var rng = tgt.getChild("radar").getChild("range-nm").getValue();
			var total_elev  = - deviation_normdeg(OurPitch.getValue(), tgt.getChild("radar").getChild("elevation-deg").getValue()); # deg.
			var total_horiz = - deviation_normdeg(OurHdg.getValue(), tgt.getChild("radar").getChild("bearing-deg").getValue());         # deg.
			# Check if in range and in the (square shaped here) seeker FOV.
			var abs_total_elev = math.abs(total_elev);
			var abs_dev_deg = math.abs(total_horiz);
			if (rng < me.max_detect_rng and abs_total_elev < me.aim9_fov_diam and abs_dev_deg < me.aim9_fov_diam ) {
				me.status = 1;
				SwSoundVol.setValue(vol_weak_track);
				me.trackWeak = 1;
				me.Tgt = tgt;
				var t_pos_str = me.Tgt.getChild("position");
				var t_ori_str = me.Tgt.getChild("orientation");
				me.TgtLon_prop       = t_pos_str.getChild("longitude-deg");
				me.TgtLat_prop       = t_pos_str.getChild("latitude-deg");
				me.TgtAlt_prop       = t_pos_str.getChild("altitude-ft");
				me.TgtHdg_prop       = t_ori_str.getChild("true-heading-deg");
				settimer(func me.update_track(nil), rand()*3.5);
				return;
			}
		}
		SwSoundVol.setValue(vol_search);
		me.trackWeak = 1;
		settimer(func me.search(), 0.1);
	},


	#done
	reset_steering: func {
		me.track_signal_e = 0;
		me.track_signal_h = 0;
	},



	reset_seeker: func {
		me.curr_tgt_e     = 0;
		me.curr_tgt_h     = 0;
		me.seeker_dev_e   = 0;
		me.seeker_dev_h   = 0;
		settimer(func { HudReticleDeg.setValue(0) }, 2);
		interpolate(HudReticleDev, 0, 2);
		me.reset_steering()
	},


	#done
	clamp_min_max: func (v, mm) {
		if ( v < -mm ) {
			v = -mm;
		} elsif ( v > mm ) {
			v = mm;
		}
	return(v);
	},

	clamp: func(v, min, max) { v < min ? min : v > max ? max : v },

	animation_flags_props: func {
		# Create animation flags properties.
		var msl_path = "sim/ja37/armament/rb24/flags/msl-id-" ~ me.ID;
		me.msl_prop = props.globals.initNode( msl_path, 1, "BOOL" );
		var smoke_path = "sim/ja37/armament/rb24/flags/smoke-id-" ~ me.ID;
		me.smoke_prop = props.globals.initNode( smoke_path, 0, "BOOL" );
		var explode_path = "sim/ja37/armament/rb24/flags/explode-id-" ~ me.ID;
		me.explode_prop = props.globals.initNode( explode_path, 0, "BOOL" );
		var explode_smoke_path = "sim/ja37/armament/rb24/flags/explode-smoke-id-" ~ me.ID;
		me.explode_smoke_prop = props.globals.initNode( explode_smoke_path, 0, "BOOL" );
		var explode_sound_path = "sim/ja37/armament/rb24/flags/explode-sound-on-" ~ me.ID;;
		me.explode_sound_prop = props.globals.initNode( explode_sound_path, 0, "BOOL" );
		var explode_sound_vol_path = "sim/ja37/armament/rb24/flags/explode-sound-vol-" ~ me.ID;;
		me.explode_sound_vol_prop = props.globals.initNode( explode_sound_vol_path, 0, "DOUBLE" );
	},


	#done
	animate_explosion: func {
		me.msl_prop.setBoolValue(0);
		me.smoke_prop.setBoolValue(0);
		me.explode_prop.setBoolValue(1);
		settimer( func me.explode_prop.setBoolValue(0), 0.5 );
		settimer( func me.explode_smoke_prop.setBoolValue(1), 0.5 );
		settimer( func me.explode_smoke_prop.setBoolValue(0), 3 );
		#var delay = me.Tgt.getNode("radar/range-nm").getValue()*4.689;
		#settimer( func me.explode_sound_prop.setBoolValue(1), delay );
		#settimer( func me.explode_sound_prop.setBoolValue(0), delay+3 );
	},

	sndPropagate: func {
		var dt = getprop("sim/time/delta-sec");
		if (dt == 0) {
			#FG is likely paused
			settimer(func me.sndPropagate(), 0.01);
			return;
		}
		#dt = update_loop_time;
		var elapsed = systime();
		if (me.dt_last != 0) {
			dt = (elapsed - me.dt_last) * getprop("sim/speed-up");
		}
		me.dt_last = elapsed;

		me.ac = geo.aircraft_position();
		var distance = me.coord.direct_distance_to(me.ac);

		me.sndDistance = me.sndDistance + (me.sndSpeed * dt) * 0.3048;
		if(me.sndDistance > distance) {
			var volume = math.pow(2.71828,(-.00025*(distance-1000)));
			#print("explosion heard "~distance~"m vol:"~volume);
			me.explode_sound_vol_prop.setValue(volume);
			me.explode_sound_prop.setBoolValue(1);
			settimer( func me.explode_sound_prop.setBoolValue(0), 3);
			settimer( func me.del(), 4);
			return;
		} elsif (me.sndDistance > 5000) {
			me.del();
		} else {
			settimer(func me.sndPropagate(), 0.05);
			return;
		}
	},

	active: {},
	flying: {},
};


# Create impact report.

#altitde-agl-ft DOUBLE
#impact
#	elevation-m DOUBLE
#	heading-deg DOUBLE
#	latitude-deg DOUBLE
#	longitude-deg DOUBLE
#	pitch-deg DOUBLE
#	roll-deg DOUBLE
#	speed-mps DOUBLE
#	type STRING
#valid "true" BOOL


var impact_report = func(pos, mass_slug, string) {

	# Find the next index for "ai/models/model-impact" and create property node.
	var n = props.globals.getNode("ai/models", 1);
	for (var i = 0; 1; i += 1)
		if (n.getChild(string, i, 0) == nil)
			break;
	var impact = n.getChild(string, i, 1);

	impact.getNode("impact/elevation-m", 1).setValue(pos.alt()*FT2M);
	impact.getNode("impact/latitude-deg", 1).setValue(pos.lat());
	impact.getNode("impact/longitude-deg", 1).setValue(pos.lon());
	impact.getNode("mass-slug", 1).setValue(mass_slug);
	#impact.getNode("speed-mps", 1).setValue(speed_mps);
	impact.getNode("valid", 1).setBoolValue(1);
	impact.getNode("impact/type", 1).setValue("terrain");

	var impact_str = "/ai/models/" ~ string ~ "[" ~ i ~ "]";
	setprop("ai/models/model-impact", impact_str);

}

var steering_speed_G = func(steering_e_deg, steering_h_deg, s_fps, mass, dt) {
	# Get G number from steering (e, h) in deg, speed in ft/s and mass in slugs.
	var steer_deg = math.sqrt((steering_e_deg*steering_e_deg)+(steering_h_deg*steering_h_deg));
	var radius_ft = math.abs(s_fps / math.cos(90 - steer_deg));
	var g = (mass * s_fps * s_fps / radius_ft * dt) / g_fps;
	#print("#### R = ", radius_ft, " G = ", g);
	return(g);
}


# HUD clamped target blinker
SW_reticle_Blinker = aircraft.light.new("sim/ja37/hud/hud-sw-reticle-switch", [0.1, 0.1]);
setprop("sim/ja37/hud/hud-sw-reticle-switch/enabled", 1);





var OurRoll            = props.globals.getNode("orientation/roll-deg");
var eye_hud_m          = 0.6;#pilot: -3.30  hud: -3.9
var hud_radius_m       = 0.100;

#was in hud
var develev_to_devroll = func(dev_rad, elev_rad) {
	var clamped = 0;
	# Deviation length on the HUD (at level flight),
	# 0.6686m = distance eye <-> virtual HUD screen.
	var h_dev = eye_hud_m / ( math.sin(dev_rad) / math.cos(dev_rad) );
	var v_dev = eye_hud_m / ( math.sin(elev_rad) / math.cos(elev_rad) );
	# Angle between HUD center/top <-> HUD center/symbol position.
	# -90° left, 0° up, 90° right, +/- 180° down. 
	var dev_deg =  math.atan2( h_dev, v_dev ) * R2D;
	# Correction with own a/c roll.
	var combined_dev_deg = dev_deg - OurRoll.getValue();
	# Lenght HUD center <-> symbol pos on the HUD:
	var combined_dev_length = math.sqrt((h_dev*h_dev)+(v_dev*v_dev));
	# clamp and squeeze the top of the display area so the symbol follow the egg shaped HUD limits.
	var abs_combined_dev_deg = math.abs( combined_dev_deg );
	var clamp = hud_radius_m;
	if ( abs_combined_dev_deg >= 0 and abs_combined_dev_deg < 90 ) {
		var coef = ( 90 - abs_combined_dev_deg ) * 0.00075;
		if ( coef > 0.050 ) { coef = 0.050 }
		clamp -= coef; 
	}
	if ( combined_dev_length > clamp ) {
		combined_dev_length = clamp;
		clamped = 1;
	}
	var v = [combined_dev_deg, combined_dev_length, clamped];
	return(v);

}

#was in radar
var deviation_normdeg = func(our_heading, target_bearing) {
	var dev_norm = our_heading - target_bearing;
	while (dev_norm < -180) dev_norm += 360;
	while (dev_norm > 180) dev_norm -= 360;
	return(dev_norm);
}

#was environment
var const_e = 2.71828183;

var rho_sndspeed = func(altitude) {
	# Calculate density of air: rho
	# at altitude (ft), using standard atmosphere,
	# standard temperature T and pressure p.

	var T = 0;
	var p = 0;
	if (altitude < 36152) {
		# curve fits for the troposphere
		T = 59 - 0.00356 * altitude;
		p = 2116 * math.pow( ((T + 459.7) / 518.6) , 5.256);
	} elsif ( 36152 < altitude and altitude < 82345 ) {
		# lower stratosphere
		T = -70;
		p = 473.1 * math.pow( const_e , 1.73 - (0.000048 * altitude) );
	} else {
		# upper stratosphere
		T = -205.05 + (0.00164 * altitude);
		p = 51.97 * math.pow( ((T + 459.7) / 389.98) , -11.388);
	}

	var rho = p / (1718 * (T + 459.7));

	# calculate the speed of sound at altitude
	# a = sqrt ( g * R * (T + 459.7))
	# where:
	# snd_speed in feet/s,
	# g = specific heat ratio, which is usually equal to 1.4
	# R = specific gas constant, which equals 1716 ft-lb/slug/R

	var snd_speed = math.sqrt( 1.4 * 1716 * (T + 459.7));
	return [rho, snd_speed];

}

#var AIM9_instance = [nil, nil,nil,nil];#init aim-9