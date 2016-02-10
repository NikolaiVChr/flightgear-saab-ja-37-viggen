var AcModel        = props.globals.getNode("sim/ja37");
var OurHdg         = props.globals.getNode("orientation/heading-deg");
var OurRoll        = props.globals.getNode("orientation/roll-deg");
var OurPitch       = props.globals.getNode("orientation/pitch-deg");
var HudReticleDev  = props.globals.getNode("sim/ja37/hud/reticle-total-deviation", 1);#polar coords
var HudReticleDeg  = props.globals.getNode("sim/ja37/hud/reticle-total-angle", 1);
var vol_weak_track = 0.10;
var vol_track      = 0.15;
var update_loop_time = 0.000;

var FRAME_TIME = 1;
var REAL_TIME = 0;

var TRUE = 1;
var FALSE = 0;

var MISSILE_STANDBY = -1;
var MISSILE_SEARCH = 0;
var MISSILE_LOCK = 1;
var MISSILE_FLYING = 2;

var g_fps        = 9.80665 * M2FT;
var slugs_to_lbs = 32.1740485564;


var AIM = {
	#done
	new : func (p, type = "RB-24J", sign = "sidewinder") {
		if(AIM.active[p] != nil) {
			#do not make new missile logic if one exist for this pylon.
			return -1;
		}
		var m = { parents : [AIM]};
		# Args: p = Pylon.

		m.type_lc = string.lc(type);
		m.type = type;

		m.status            = 0; # -1 = stand-by, 0 = searching, 1 = locked, 2 = fired.
		m.free              = 0; # 0 = status fired with lock, 1 = status fired but having lost lock.
		m.trackWeak         = 1;

		m.prop              = AcModel.getNode("armament/"~m.type_lc~"/").getChild("msl", 0 , 1);
		m.SwSoundOnOff      = AcModel.getNode("armament/"~m.type_lc~"/sound-on-off");
        m.SwSoundVol        = AcModel.getNode("armament/"~m.type_lc~"/sound-volume");
		m.PylonIndex        = m.prop.getNode("pylon-index", 1).setValue(p);
		m.ID                = p;
		m.pylon_prop        = props.globals.getNode("controls/armament").getChild("station", p+1);
		m.Tgt               = nil;
		m.callsign          = "Unknown";
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
		m.before_last_t_coord = nil;
		#m.next_t_coord     = m.t_coord;
		m.direct_dist_m     = nil;
		m.speed_m           = 0;

		# AIM specs:
		m.aim9_fov_diam         = getprop("sim/ja37/armament/"~m.type_lc~"/fov-deg");
		m.aim9_fov              = m.aim9_fov_diam / 2;
		m.max_detect_rng        = getprop("sim/ja37/armament/"~m.type_lc~"/max-detection-rng-nm");
		m.max_seeker_dev        = getprop("sim/ja37/armament/"~m.type_lc~"/track-max-deg") / 2;
		m.force_lbs_1           = getprop("sim/ja37/armament/"~m.type_lc~"/thrust-lbs-stage-1");
		m.force_lbs_2           = getprop("sim/ja37/armament/"~m.type_lc~"/thrust-lbs-stage-2");
		m.stage_1_duration      = getprop("sim/ja37/armament/"~m.type_lc~"/stage-1-duration-sec");
		m.stage_2_duration      = getprop("sim/ja37/armament/"~m.type_lc~"/stage-2-duration-sec");
		m.weight_launch_lbs     = getprop("sim/ja37/armament/"~m.type_lc~"/weight-launch-lbs");
		m.weight_whead_lbs      = getprop("sim/ja37/armament/"~m.type_lc~"/weight-warhead-lbs");
		m.cd                    = getprop("sim/ja37/armament/"~m.type_lc~"/drag-coeff");
		m.eda                   = getprop("sim/ja37/armament/"~m.type_lc~"/drag-area");
		m.max_g                 = getprop("sim/ja37/armament/"~m.type_lc~"/max-g");
		m.searcher_beam_width   = getprop("sim/ja37/armament/"~m.type_lc~"/searcher-beam-width");
		m.arming_time           = getprop("sim/ja37/armament/"~m.type_lc~"/arming-time-sec");
		m.min_speed_for_guiding = getprop("sim/ja37/armament/"~m.type_lc~"/min-speed-for-guiding-mach");
		m.selfdestruct_time     = getprop("sim/ja37/armament/"~m.type_lc~"/self-destruct-time-sec");
		m.guidance              = getprop("sim/ja37/armament/"~m.type_lc~"/guidance");
		m.all_aspect            = getprop("sim/ja37/armament/"~m.type_lc~"/all-aspect");
		m.vol_search            = getprop("sim/ja37/armament/"~m.type_lc~"/vol-search");
		m.aim_9_model           = "Aircraft/JA37/Models/Armament/Weapons/"~type~"/"~m.type_lc~"-";
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
			if (n.getChild(m.type_lc, i, 0) == nil) {
				break;
			}
		}
		m.ai = n.getChild(m.type_lc, i, 1);

		m.ai.getNode("valid", 1).setBoolValue(1);
		m.ai.getNode("name", 1).setValue(type);
		m.ai.getNode("sign", 1).setValue(sign);
		#m.model.getNode("collision", 1).setBoolValue(0);
		#m.model.getNode("impact", 1).setBoolValue(0);
		var id_model = m.aim_9_model ~ m.ID ~ ".xml";
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
		m.last_coord = nil;
		m.before_last_coord = nil;
		m.s_down  = nil;
		m.s_east  = nil;
		m.s_north = nil;
		m.alt     = nil;
		m.pitch   = nil;
		m.hdg     = nil;

		m.lastFlare = 0;

		m.SwSoundOnOff.setValue(1);

		settimer(func { m.SwSoundVol.setValue(m.vol_search); me.trackWeak = 1; m.search() }, 1);
		return AIM.active[m.ID] = m;

	},
	#done
	del: func {
		#print("deleted");
		me.model.remove();
		me.ai.remove();
		if (me.status == MISSILE_FLYING) {
			delete(AIM.flying, me.flyID);
		} else {
			delete(AIM.active, me.ID);
		}
	},
	#done
	release: func() {
		me.status = MISSILE_FLYING;
		me.flyID = rand();
		AIM.flying[me.flyID] = me;
		delete(AIM.active, me.ID);
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
		me.coord.set_latlon(alat, alon, aalt * FT2M);

		me.model.getNode("latitude-deg-prop", 1).setValue(me.latN.getPath());
		me.model.getNode("longitude-deg-prop", 1).setValue(me.lonN.getPath());
		me.model.getNode("elevation-ft-prop", 1).setValue(me.altN.getPath());
		me.model.getNode("heading-deg-prop", 1).setValue(me.hdgN.getPath());
		me.model.getNode("pitch-deg-prop", 1).setValue(me.pitchN.getPath());
		me.model.getNode("roll-deg-prop", 1).setValue(me.rollN.getPath());
		var loadNode = me.model.getNode("load", 1);
		
		# Get initial velocity vector (aircraft):
		me.s_down = getprop("velocities/speed-down-fps");
		me.s_east = getprop("velocities/speed-east-fps");
		me.s_north = getprop("velocities/speed-north-fps");

		me.alt = aalt;
		me.pitch = ac_pitch;
		me.hdg = ac_hdg;

		me.smoke_prop.setBoolValue(1);
		me.SwSoundVol.setValue(0);
		me.trackWeak = 1;
		#settimer(func { HudReticleDeg.setValue(0) }, 2);
		#interpolate(HudReticleDev, 0, 2);
		#loadNode.remove();
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
			if(dt <= 0) {
				# to prevent pow floating point error in line:cdm = 0.2965 * math.pow(me.speed_m, -1.1506) + me.cd;
				# could happen if the OS adjusts the clock backwards
				dt = 0.00001;
			}
		}
		me.dt_last = elapsed;

		var init_launch = 0;
		if ( me.life_time > 0 ) { 
			init_launch = 1;
		}
		me.life_time += dt;
		# record coords so we can give the latest nearest position for impact.
		me.before_last_coord = geo.Coord.new(me.last_coord);
		me.last_coord = geo.Coord.new(me.coord);
		#print(dt);

		#### Calculate speed vector before steering corrections.

		# Cut rocket thrust after boost duration.
		var f_lbs = me.force_lbs_1;
		if (me.life_time > me.stage_1_duration) {
			f_lbs = me.force_lbs_2;
		}
		if (me.life_time > (me.stage_1_duration + me.stage_2_duration)) {
			#print("lifetime "~me.life_time);
			f_lbs = 0;
		}
		if (f_lbs < 1) {
			me.smoke_prop.setBoolValue(0);
		}

		# Kill the AI after a while.
		#if (me.life_time > 60) { return me.del(); }

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
		me.speed_m = (total_s_ft / dt) / sound_fps;
		if (me.speed_m < 0.7)
		 cdm = 0.0125 * me.speed_m + me.cd;
		elsif (me.speed_m < 1.2 )
		 cdm = 0.3742 * math.pow(me.speed_m, 2) - 0.252 * me.speed_m + 0.0021 + me.cd;
		else
		 cdm = 0.2965 * math.pow(me.speed_m, -1.1506) + me.cd;

		# Add drag to the total speed using Standard Atmosphere (15C sealevel temperature);
		# rho is adjusted for altitude in environment.rho_sndspeed(altitude),
		# Acceleration = thrust/mass - drag/mass;
		var mass = me.weight_launch_lbs / slugs_to_lbs;
		var old_speed_fps = total_s_ft / dt;
		var acc = f_lbs / mass;

		var q = 0.5 * rho * old_speed_fps * old_speed_fps;# dynamic pressure
		var drag_acc = (cdm * q * me.eda) / mass;
		var speed_fps = old_speed_fps - drag_acc + acc;

		if (speed_fps < 0) {
			# drag can theoretically make the speed less than 0, this will prevent that from happening.
			speed_fps = 0;
		}

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

		if ( me.status == MISSILE_FLYING and me.free == 0) {
			me.update_track(dt);
			if (init_launch == 0 ) {
				# Use the rail or a/c pitch for the first frame.
				pitch_deg = getprop("orientation/pitch-deg");
			} else {
				#print("steering");
				#Here will be set the max angle of pitch and the max angle of heading to avoid G overload
                var myG = steering_speed_G(me.track_signal_e, me.track_signal_h, (total_s_ft / dt), dt);
                if(me.max_g < myG)
                {
                    var MyCoef = max_G_Rotation(me.track_signal_e, me.track_signal_h, (total_s_ft / dt), dt, me.max_g);
                    me.track_signal_e =  me.track_signal_e * MyCoef;
                    me.track_signal_h =  me.track_signal_h * MyCoef;
                    #print(sprintf("G1 %.2f", myG));
                    myG = steering_speed_G(me.track_signal_e, me.track_signal_h, (total_s_ft / dt), dt);
                    #print(sprintf("G2 %.2f", myG)~sprintf(" - Coeff %.2f", MyCoef));
                }
                #print(sprintf("G %.1f", myG));
                if (me.all_aspect == 1 or me.rear_aspect() == 1) {
                	pitch_deg += me.track_signal_e;
                	hdg_deg += me.track_signal_h;
                }

                #print("Still Tracking : Elevation ",me.track_signal_e,"Heading ",me.track_signal_h," Gload : ", myG );
			}
		}

		

		# Get horizontal distance and set position and orientation.
		var dist_h_m = speed_horizontal_fps * dt * FT2M;
		me.coord.apply_course_distance(hdg_deg, dist_h_m);
		me.latN.setDoubleValue(me.coord.lat());
		me.lonN.setDoubleValue(me.coord.lon());
		me.altN.setDoubleValue(alt_ft);
		me.coord.set_alt(alt_ft * FT2M);
		me.pitchN.setDoubleValue(pitch_deg);
		me.hdgN.setDoubleValue(hdg_deg);

		# set radar properties for use in selection view and HUD tracks.
		var self = geo.aircraft_position();
		me.ai.getNode("radar/bearing-deg", 1).setValue(self.course_to(me.coord));
		var angleInv = me.clamp(self.distance_to(me.coord)/self.direct_distance_to(me.coord), -1, 1);
		me.ai.getNode("radar/elevation-deg", 1).setValue((self.alt()>me.coord.alt()?-1:1)*math.acos(angleInv)*R2D);
		me.ai.getNode("velocities/true-airspeed-kt",1).setValue(speed_fps * FPS2KT);

		#### Proximity detection.
		if ( me.status == MISSILE_FLYING ) {
			#### check if the missile can keep the lock.
 			if ( me.free == 0 ) {
				var g = steering_speed_G(me.track_signal_e, me.track_signal_h, (total_s_ft / dt), dt);

# Uncomment this line to check stats while flying:
#
#print(sprintf("Mach %02.1f", me.speed_m)~sprintf(" , time %03.1f", me.life_time)~sprintf(" , thrust %03.1f", f_lbs)~sprintf(" , G-force %02.2f", g));

				if ( g > me.max_g ) {
					#print("lost lock "~g~"G");
					# Target unreachable, fly free.
					me.free = 1;
				}
				if (me.guidance == "heat") {
					var flareNode = me.Tgt.getNode("sim/multiplay/generic/string[10]");
					if (flareNode != nil) {
						var flareString = flareNode.getValue();
						if (flareString != nil) {
							var flareVector = split(":", flareString);
							if (flareVector != nil and size(flareVector) == 2 and flareVector[1] == "flare") {
								var flareNumber = num(flareVector[0]);
								if (flareNumber != nil and flareNumber != me.lastFlare) {
									# target has released a new flare, lets check if it fools us
									me.lastFlare = flareNumber;
									var aspect = me.aspect() / 180;
									var fooled = rand() < (0.2 + 0.1 * aspect);
									# 20% chance to be fooled, extra up till 10% chance added if front aspect
									if (fooled) {
										# fooled by the flare
										print("Fooled by flare");
										me.free = 1;
									} else {
										print("Flare ignored");
									}
								}
							}
						}
					}
				}
			}
			var v = me.poximity_detection();
			
			if ( ! v) {
				#print("exploded");
				# We exploded, and start the sound propagation towards the plane
				me.sndSpeed = sound_fps;
				me.sndDistance = 0;
				me.dt_last = systime();
				me.sndPropagate();
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

		settimer(func me.update(), update_loop_time, REAL_TIME);
		
	},

	# If is heat-seeking rear-aspect-only missile, check if it has good view on engine(s) and can keep lock.
	rear_aspect: func () {

		var offset = me.aspect();

		if (offset < 45) {
			# clear view of engine heat, keep the lock
			rearAspect = 1;
		} else {
			# the greater angle away from clear engine view the greater chance of losing lock.
			var offset_away = offset - 45;
			var probability = offset_away/135;
			rearAspect = rand() > probability;
		}

		#print ("RB-24J deviation from full rear-aspect: "~sprintf("%01.1f", offset)~" deg, keep IR lock on engine: "~rearAspect);

		return rearAspect;# 1: keep lock, 0: lose lock
	},

	aspect: func () {
		var rearAspect = 0;

		var t_dist_m = me.coord.distance_to(me.t_coord);
		var alt_delta_m = me.coord.alt() - me.t_coord.alt();
		var elev_deg =  math.atan2( alt_delta_m, t_dist_m ) * R2D;
		var elevation_offset = elev_deg - me.Tgt.getNode("orientation/pitch-deg").getValue();

		var course = me.t_coord.course_to(me.coord);
		var heading_offset = course - me.Tgt.getNode("orientation/true-heading-deg").getValue();

		#
		while (heading_offset < -180) {
			heading_offset += 360;
		}
		while (heading_offset > 180) {
			heading_offset -= 360;
		}
		while (elevation_offset < -180) {
			elevation_offset += 360;
		}
		while (elevation_offset > 180) {
			elevation_offset -= 360;
		}
		elevation_offset = math.abs(elevation_offset);
		heading_offset = 180 - math.abs(heading_offset);

		var offset = math.max(elevation_offset, heading_offset);

		return offset;		
	},


	update_track: func(dt) {
		if ( me.Tgt == nil ) {
		 #print("no target");
		 return(1);
		}
		if (me.status == MISSILE_SEARCH) {
			# Status = searching.
			me.reset_seeker();
			me.SwSoundVol.setValue(me.vol_search);
			me.trackWeak = 1;
			settimer(func me.search(), 0.1);
			return(1);
		}
		if ( me.status == MISSILE_STANDBY ) {
			# Status = stand-by.
			me.reset_seeker();
			me.SwSoundVol.setValue(0);
			me.trackWeak = 1;
			return(1);
		}
		if (!me.Tgt.getChild("valid").getValue()) {
			# Lost of lock due to target disapearing:
			# return to search mode.
			#print("invalid");
			me.status = MISSILE_SEARCH;
			me.reset_seeker();
			me.SwSoundVol.setValue(me.vol_search);
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
		if (me.status == MISSILE_LOCK) {		
			# Status = locked. Get target position relative to our aircraft.
			me.curr_tgt_e = - deviation_normdeg(OurPitch.getValue(), me.Tgt.getChild("radar").getChild("elevation-deg").getValue());
			me.curr_tgt_h = - deviation_normdeg(OurHdg.getValue(), me.Tgt.getChild("radar").getChild("bearing-deg").getValue());
		} else {
			# Status = launched. Compute target position relative to seeker head.

			# Get target position.
			var t_alt = me.TgtAlt_prop.getValue();
			me.t_coord.set_latlon(me.TgtLat_prop.getValue(), me.TgtLon_prop.getValue(), t_alt * FT2M);

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
			# the trajectory stage 1 seconds.
			# Then, keep track of deviations at the end of these two initial 2 seconds.
			var e_gain = 1;
			var h_gain = 1;
			if ( me.life_time < me.stage_1_duration ) {
				if (me.curr_tgt_e > me.searcher_beam_width or me.curr_tgt_e < (-1 * me.searcher_beam_width)) {
					#e_gain = 1 + (0.1 * dt);
				}
				if (me.curr_tgt_h > me.searcher_beam_width or me.curr_tgt_h < (-1 * me.searcher_beam_width)) {
					#h_gain = 1 + (0.1 * dt);
				}
				me.init_tgt_e = last_tgt_e;
				me.init_tgt_h = last_tgt_h;
			}

			if(me.speed_m < me.min_speed_for_guiding or (me.guidance == "semi-radar" and me.is_painted(me.Tgt) == FALSE)) {
				# it doesn't guide at lower speeds
				# or if its semi-radar guided and the target is no longer painted
				e_gain = 0;
				h_gain = 0;
			} elsif (me.curr_tgt_e > me.max_seeker_dev or me.curr_tgt_e < (-1 * me.max_seeker_dev)
				  or me.curr_tgt_h > me.max_seeker_dev or me.curr_tgt_h < (-1 * me.max_seeker_dev)) {
				# target is not in missile seeker view anymore
				e_gain = 0;
				h_gain = 0;
			}

			# Compute target deviation variation then seeker move to keep this deviation constant.
			me.track_signal_e = (me.curr_tgt_e - me.init_tgt_e) * e_gain;
			me.track_signal_h = (me.curr_tgt_h - me.init_tgt_h) * h_gain;
			
#print ("**** curr_tgt_e = ", me.curr_tgt_e," curr_tgt_h = ", me.curr_tgt_h, " me.track_signal_e = ", me.track_signal_e," me.track_signal_h = ", me.track_signal_h);


		}
		# Compute HUD reticle position.
		if ( 1==0 and me.status == MISSILE_LOCK ) {
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
		if ( me.status != MISSILE_FLYING and me.status != MISSILE_STANDBY ) {
			me.check_t_in_fov();
			# We are not launched yet: update_track() loops by itself at 10 Hz.
			me.SwSoundVol.setValue(vol_track);
			me.trackWeak = 0;
			settimer(func me.update_track(nil), 0.1);
		}
		return(1);
	},



	#done
	poximity_detection: func {
		var cur_dir_dist_m = me.coord.direct_distance_to(me.t_coord);
		# Get current direct distance.
		if ( me.direct_dist_m != nil and me.life_time > me.arming_time) {
			#print("distance to target_m = "~cur_dir_dist_m~" prev_distance to target_m = "~me.direct_dist_m);
			if ( cur_dir_dist_m > me.direct_dist_m and me.direct_dist_m < 65 ) {
				#print("passed target");
				# Distance to target increase, trigger explosion.
				me.explode();
				return(0);
			#} #elsif (cur_dir_dist_m < 15) {
			#	print("proximity fuse activated.");
				#within killing distance, explode 
				#(this might not be how the real thing does, but due to this only being called every frame, might miss otherwise)
			#	me.explode();
			#	return(0);
			} elsif (me.free == 1 and cur_dir_dist_m < 15) {
				#print("Magnetic fuse active.");
				# lost lock, magnetic detector checks if close enough to explode
				me.explode();
				return(0);
			}
		}
		if (me.life_time > me.selfdestruct_time) {
			me.explode();
		    return(0);
		}
		####Ground interaction
        var ground = geo.elevation(me.coord.lat(), me.coord.lon());
        #print("Ground :",ground);
        if(ground != nil)
        {
            if(ground > me.coord.alt()) {
                #print("Ground");
                me.explode();
                return 0;
            }
        }
		me.before_last_t_coord = geo.Coord.new(me.last_t_coord);
		me.last_t_coord = geo.Coord.new(me.t_coord);
		me.direct_dist_m = cur_dir_dist_m;
		return(1);
	},

	explode: func {
		# Get missile relative position to the target at last frame.
		var t_bearing_deg = me.last_t_coord.course_to(me.last_coord);
		var t_delta_alt_m = me.last_coord.alt() - me.last_t_coord.alt();
		var new_t_alt_m = me.t_coord.alt() + t_delta_alt_m;
		var t_dist_m  = me.direct_dist_m;
		
		var min_distance = me.direct_dist_m;
		var explosion_coord = me.last_coord;
		#print("min1 "~min_distance);
		#print("last_t to t    : "~me.last_t_coord.direct_distance_to(me.t_coord));
		#print("last to current: "~me.last_coord.direct_distance_to(me.coord));
		for (var i = 0.1; i < 1; i += 0.1) {
			var t_coord = me.interpolate(me.last_t_coord, me.t_coord, i);
			var coord = me.interpolate(me.last_coord, me.coord, i);
			var dist = coord.direct_distance_to(t_coord);
			if (dist < min_distance) {
				min_distance = dist;
				explosion_coord = coord;
			}
		}
		#print("min2 "~min_distance);
		if (me.before_last_coord != nil and me.before_last_t_coord != nil) {
			for (var i = 0.1; i < 1; i += 0.1) {
				var t_coord = me.interpolate(me.before_last_t_coord, me.last_t_coord, i);
				var coord = me.interpolate(me.before_last_coord, me.last_coord, i);
				var dist = coord.direct_distance_to(t_coord);
				if (dist < min_distance) {
					min_distance = dist;
					explosion_coord = coord;
				}
			}
		}
		#print("min3 "~min_distance);

		# Create impact coords from this previous relative position applied to target current coord.
		me.t_coord.apply_course_distance(t_bearing_deg, t_dist_m);
		me.t_coord.set_alt(new_t_alt_m);		
		var wh_mass = me.weight_whead_lbs / slugs_to_lbs;
		#print("FOX2: me.direct_dist_m = ",  me.direct_dist_m, " time ",getprop("sim/time/elapsed-sec"));
		impact_report(me.t_coord, wh_mass, "missile"); # pos, alt, mass_slug,(speed_mps)

		var phrase = sprintf( me.type~" exploded: %01.1f", min_distance) ~ " meters from: " ~ me.callsign;
		if (min_distance < 65) {
			if (getprop("sim/ja37/armament/msg")) {
				setprop("/sim/multiplay/chat", phrase);
			} else {
				setprop("/sim/messages/atc", phrase);
			}
		}
		print(phrase);
		me.ai.getNode("valid", 1).setBoolValue(0);
		me.animate_explosion();
		me.Tgt = nil;
	},

	interpolate: func (start, end, fraction) {
		var x = (start.x()*(1-fraction)+end.x()*fraction);
		var y = (start.y()*(1-fraction)+end.y()*fraction);
		var z = (start.z()*(1-fraction)+end.z()*fraction);

		var c = geo.Coord.new();
		c.set_xyz(x,y,z);

		return c;
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
			me.status = MISSILE_SEARCH;
			settimer(func me.search(), rand()*3.5);
			me.Tgt = nil;
			me.SwSoundVol.setValue(me.vol_search);
			me.trackWeak = 1;
			me.reset_seeker();
		}
		return(1);
	},

	# aircraft searching for lock
	search: func {
		if ( me.status == MISSILE_STANDBY ) {
			# Stand by.
			me.SwSoundVol.setValue(0);
			me.trackWeak = 1;
			return;
		} elsif ( me.status > MISSILE_SEARCH ) {
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
			if ((me.guidance != "semi-radar" or me.is_painted(tgt) == TRUE) and rng < me.max_detect_rng and abs_total_elev < me.aim9_fov_diam and abs_dev_deg < me.aim9_fov_diam ) {
				me.status = MISSILE_LOCK;
				me.SwSoundVol.setValue(vol_weak_track);
				me.trackWeak = 1;
				me.Tgt = tgt;

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
		        me.callsign = ident;

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
		me.SwSoundVol.setValue(me.vol_search);
		me.trackWeak = 1;
		settimer(func me.search(), 0.1);
	},


	#done
	reset_steering: func {
		me.track_signal_e = 0;
		me.track_signal_h = 0;
	},

	is_painted: func (target) {
		if(target != nil and target.getChild("painted") != nil and target.getChild("painted").getValue() == TRUE) {
			return TRUE;
		}
		return FALSE;
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
		var msl_path = "sim/ja37/armament/"~me.type_lc~"/flags/msl-id-" ~ me.ID;
		me.msl_prop = props.globals.initNode( msl_path, 1, "BOOL", 1);
		var smoke_path = "sim/ja37/armament/"~me.type_lc~"/flags/smoke-id-" ~ me.ID;
		me.smoke_prop = props.globals.initNode( smoke_path, 0, "BOOL", 1);
		var explode_path = "sim/ja37/armament/"~me.type_lc~"/flags/explode-id-" ~ me.ID;
		me.explode_prop = props.globals.initNode( explode_path, 0, "BOOL", 1);
		var explode_smoke_path = "sim/ja37/armament/"~me.type_lc~"/flags/explode-smoke-id-" ~ me.ID;
		me.explode_smoke_prop = props.globals.initNode( explode_smoke_path, 0, "BOOL", 1);
		var explode_sound_path = "sim/ja37/armament/flags/explode-sound-on-" ~ me.ID;;
		me.explode_sound_prop = props.globals.initNode( explode_sound_path, 0, "BOOL", 1);
		var explode_sound_vol_path = "sim/ja37/armament/flags/explode-sound-vol-" ~ me.ID;;
		me.explode_sound_vol_prop = props.globals.initNode( explode_sound_vol_path, 0, "DOUBLE", 1);
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

		me.sndDistance = me.sndDistance + (me.sndSpeed * dt) * FT2M;
		if(me.sndDistance > distance) {
			var volume = math.pow(2.71828,(-.00025*(distance-1000)));
			#print("explosion heard "~distance~"m vol:"~volume);
			me.explode_sound_vol_prop.setValue(volume);
			me.explode_sound_prop.setBoolValue(1);
			settimer( func me.explode_sound_prop.setBoolValue(0), 3);
			settimer( func me.del(), 4);
			return;
		} elsif (me.sndDistance > 5000) {
			settimer(func { me.del(); }, 4 );
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

	impact.getNode("impact/elevation-m", 1).setValue(pos.alt());
	impact.getNode("impact/latitude-deg", 1).setValue(pos.lat());
	impact.getNode("impact/longitude-deg", 1).setValue(pos.lon());
	impact.getNode("mass-slug", 1).setValue(mass_slug);
	#impact.getNode("speed-mps", 1).setValue(speed_mps);
	impact.getNode("valid", 1).setBoolValue(1);
	impact.getNode("impact/type", 1).setValue("terrain");

	var impact_str = "/ai/models/" ~ string ~ "[" ~ i ~ "]";
	setprop("ai/models/model-impact", impact_str);

}

var steering_speed_G = func(steering_e_deg, steering_h_deg, s_fps, dt) {
	# Get G number from steering (e, h) in deg, speed in ft/s.
	var steer_deg = math.sqrt((steering_e_deg*steering_e_deg) + (steering_h_deg*steering_h_deg));
	var radius_ft = math.abs(s_fps / math.cos((90 - steer_deg)*D2R));
	var g = ( (s_fps * s_fps) / radius_ft ) / g_fps;
	#print("#### R = ", radius_ft, " G = ", g); ##########################################################
	return g;
}

var max_G_Rotation = func(steering_e_deg, steering_h_deg, s_fps, dt,gMax) {
        # Get G number from steering (e, h) in deg, speed in ft/s.
        #This function is for calculate the maximum angle without overload G

        var steer_deg = math.sqrt((steering_e_deg*steering_e_deg) + (steering_h_deg*steering_h_deg));
        var radius_ft = math.abs(s_fps / math.cos((90 - steer_deg)*D2R));
        var g = ( (s_fps * s_fps) / radius_ft ) / g_fps;

         #Isolation of Radius
        if (s_fps < 1) {
        	s_fps = 1;
        }
        var radius_ft2 = ( s_fps * s_fps) / (gMax * 0.95 * g_fps);
        if (math.abs(s_fps / radius_ft2) < 1) {
                var steer_rad_theoric = math.acos(math.abs(s_fps/radius_ft2));
                var steer_deg_theoric = 90 - (steer_rad_theoric * R2D);
        } else {
                var steer_rad_theoric = 1;
                var steer_deg_theoric = 1;
        }

        var radius_ft_th = math.abs(s_fps / math.cos((90 -steer_deg_theoric)*D2R));
        var g_th = ( (s_fps * s_fps) / radius_ft_th ) / g_fps;

        #print ("Max G ", gMax , " Actual G " , g, " steer_deg_theoric ", steer_deg_theoric, " G theoretic=", g_th);
        
        return (steer_deg_theoric / steer_deg);
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

#var AIM_instance = [nil, nil,nil,nil];#init aim-9