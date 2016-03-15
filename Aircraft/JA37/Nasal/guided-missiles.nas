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
		m.TgtSpeed_prop     = nil;
		m.TgtPitch_prop     = nil;
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
		m.force_lbs_1           = getprop("sim/ja37/armament/"~m.type_lc~"/thrust-lbf-stage-1");
		m.force_lbs_2           = getprop("sim/ja37/armament/"~m.type_lc~"/thrust-lbf-stage-2");
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
		m.angular_speed         = getprop("sim/ja37/armament/"~m.type_lc~"/seeker-angular-speed-dps");
        m.loft_alt              = getprop("sim/ja37/armament/"~m.type_lc~"/loft-altitude");
        m.min_dist              = getprop("sim/ja37/armament/"~m.type_lc~"/min-rng-nm");
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

		m.density_alt_diff = 0;
		m.max_g_current = m.max_g;
		m.last_deviation_e = nil;
		m.last_deviation_h = nil;
		m.last_track_e = 0;
		m.last_track_h = 0;
		m.update_count = -1;
		m.paused = 0;
		m.last_tgt_h = nil;
		m.last_tgt_e = nil;
		m.old_speed_horz_fps = nil;
		m.t_alt_delta_last_m = nil;

		m.dist_last = nil;
		m.dist_direct_last = nil;
		m.last_t_course = nil;
		m.last_t_elev_deg = nil;
		m.last_cruise_or_loft = 0;
		m.old_speed_fps	= 0;
		m.last_t_norm_speed = nil;
		m.last_t_elev_norm_speed = nil;

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
		var alpha = getprop("orientation/alpha-deg");
		alpha = alpha > 0?alpha:0;# not using alpha if its negative to avoid missile flying through aircraft.
		alpha = alpha * math.cos(getprop("orientation/roll-deg")*D2R) + getprop("orientation/side-slip-deg")*math.sin(getprop("orientation/roll-deg")*D2R);
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
		ac_pitch = ac_pitch - alpha;
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
		loadNode.setBoolValue(1);

		# Get initial velocity vector (aircraft):
		me.s_down = getprop("velocities/speed-down-fps");
		me.s_east = getprop("velocities/speed-east-fps");
		me.s_north = getprop("velocities/speed-north-fps");
		#print("release speed down: "~me.s_down);

		me.alt = aalt;
		me.pitch = ac_pitch;
		me.hdg = ac_hdg;

		#print("p1 "~ac_pitch);

		me.density_alt_diff = getprop("fdm/jsbsim/atmosphere/density-altitude") - aalt;

		#print("air density diff alt = "~me.density_alt_diff);
		#print("missile alt = "~aalt);

		#me.smoke_prop.setBoolValue(1);
		me.SwSoundVol.setValue(0);
		me.trackWeak = 1;
		#settimer(func { HudReticleDeg.setValue(0) }, 2);
		#interpolate(HudReticleDev, 0, 2);
		#loadNode.remove();
		me.flight();
		loadNode.remove();
	},

	flight: func {
		var dt = getprop("sim/time/delta-sec");#TODO: find out more about how this property works (most likely time since last time nasal timers were called)
		if (dt == 0) {
			#FG is likely paused
			me.paused = 1;
			settimer(func me.flight(), 0.00);
			return;
		}
		#if just called from release() then dt is almost 0 (cannot be zero as we use it to divide with)
		# It can also not be too small, then the missile will lag behind aircraft and seem to be fired from behind the aircraft.
		#dt = dt/2;
		var elapsed = systime();
		if (me.paused == 1) {
			# sim has been unpaused lets make sure dt becomes very small to let elapsed time catch up.
			me.paused = 0;
			me.dt_last = elapsed-0.02;
		}
		var init_launch = 0;
		if (me.dt_last != 0) {
			#if (getprop("sim/speed-up") == 1) {
				dt = (elapsed - me.dt_last)*getprop("sim/speed-up");
			#} else {
			#	dt = getprop("sim/time/delta-sec")*getprop("sim/speed-up");
			#}
			init_launch = 1;
			if(dt <= 0) {
				# to prevent pow floating point error in line:cdm = 0.2965 * math.pow(me.speed_m, -1.1506) + me.cd;
				# could happen if the OS adjusts the clock backwards
				dt = 0.00001;
			}
		}
		me.dt_last = elapsed;

		
		me.life_time += dt;
		# record coords so we can give the latest nearest position for impact.
		me.before_last_coord = geo.Coord.new(me.last_coord);
		me.last_coord = geo.Coord.new(me.coord);
		#print(dt);

		#### Calculate speed vector before steering corrections.

		# Cut rocket thrust after boost duration.
		var f_lbs = me.force_lbs_1;# pounds force (lbf)
		if (me.life_time > me.stage_1_duration) {
			f_lbs = me.force_lbs_2;
		}
		if (me.life_time > (me.stage_1_duration + me.stage_2_duration)) {
			#print("lifetime "~me.life_time);
			f_lbs = 0;
		}
		if (f_lbs < 1) {
			me.smoke_prop.setBoolValue(0);
		} else {
			me.smoke_prop.setBoolValue(1);
		}

		# Kill the AI after a while.
		#if (me.life_time > 60) { return me.del(); }

		# Get total old speed.
		var d_east_ft  = me.s_east * dt;
		var d_north_ft = me.s_north * dt;
		var d_down_ft  = me.s_down * dt;
		var dist_h_ft  = math.sqrt((d_east_ft*d_east_ft)+(d_north_ft*d_north_ft));
		var total_s_ft = math.sqrt((dist_h_ft*dist_h_ft)+(d_down_ft*d_down_ft));

		# get old attitude
		var pitch_deg  = me.pitch;
		var hdg_deg    = me.hdg;


		# Get air density and speed of sound (fps):
		#var alt_ft = me.altN.getValue(); don't declare this twice
		var rs = rho_sndspeed(me.altN.getValue() + me.density_alt_diff);
		var rho = rs[0];
		var sound_fps = rs[1];

		# density for 0ft and 50kft:
		#print("0:"~rho_sndspeed(0)[0]);       = 0.0023769
		#print("50k:"~rho_sndspeed(50000)[0]); = 0.00036159
		#
		# a aim-9j can do 22G at sealevel, 13G at 50Kft
		# 13G = 22G * 0.5909
		#
		# extra/inter-polation:
		# f(x) = y1 + ((x - x1) / (x2 - x1)) * (y2 - y1)
		# calculate its performance at current air density:
		me.max_g_current = me.max_g+((rho-0.0023769)/(0.00036159-0.0023769))*(me.max_g*0.5909-me.max_g);
		#print("Max G = "~me.max_g_current~" Rho = "~rho);

		# Adjust Cd by Mach number. The equations are based on curves
		# for a conventional shell/bullet (no boat-tail).
		var cdm = 0;

		var old_speed_fps = total_s_ft / dt;
		#print("aim "~old_speed_fps);
		#print("ac  "~(getprop("velocities/groundspeed-3D-kt")*KT2FPS));
		me.old_speed_horz_fps = dist_h_ft / dt;
		me.old_speed_fps = old_speed_fps;

		me.speed_m = old_speed_fps / sound_fps;
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
		
		var acc = f_lbs / mass;

		var q = 0.5 * rho * old_speed_fps * old_speed_fps;# dynamic pressure
		var drag_acc = (cdm * q * me.eda) / mass;

		# get total new speed (minus gravity)
		var speed_change_fps = acc*dt - drag_acc*dt;

		


		#print("alt "~alt_ft);

		#### Guidance.

		if ( me.status == MISSILE_FLYING and me.free == 0) {
			if (me.life_time > 0.5) {
				var success = me.guide(dt);
				if (success == FALSE) {
					return;
				}
			}
				#print("steering");
				#Here will be set the max angle of pitch and the max angle of heading to avoid G overload
                var myG = steering_speed_G(me.track_signal_e, me.track_signal_h, old_speed_fps, dt);
                if(me.max_g_current < myG)
                {
                    var MyCoef = max_G_Rotation(me.track_signal_e, me.track_signal_h, old_speed_fps, dt, me.max_g_current);
                    me.track_signal_e =  me.track_signal_e * MyCoef;
                    me.track_signal_h =  me.track_signal_h * MyCoef;
                    #print(sprintf("G1 %.2f", myG));
                    var myG2 = steering_speed_G(me.track_signal_e, me.track_signal_h, old_speed_fps, dt);
                    #print(sprintf("G2 %.2f", myG)~sprintf(" - Coeff %.2f", MyCoef));
                    print(sprintf("Missile pulling almost max G: %.1f G", myG2));
                }
                #print(sprintf("G %.1f", myG));
                if (me.all_aspect == 1 or me.rear_aspect() == 1) {
                	pitch_deg += me.track_signal_e;
                	hdg_deg += me.track_signal_h;
                	me.last_track_e = me.track_signal_e;
					me.last_track_h = me.track_signal_h;
                } else {
                	me.last_track_e = 0;
                	me.last_track_h = 0;
                	print("Heat seeking missile lost lock, attempting to reaquire..");
                }
                #print(sprintf("%.1f deg elev command done", me.last_track_e));
                #print(sprintf("%.1f deg bear command done", me.last_track_h));

                #print("Still Tracking : Elevation ",me.track_signal_e,"Heading ",me.track_signal_h," Gload : ", myG );
			
		}

		# If we add gravity while the missile is guiding, the gravity speed will be added to total speed,
		# which next update will be added in the direction the missile points, which we do not want.
		#
		
		#print("p "~pitch_deg);
		# Break speed change down total speed to North, East and Down components.
		var speed_down_fps       = - math.sin(pitch_deg * D2R) * (speed_change_fps + old_speed_fps);
		var speed_horizontal_fps = math.cos(pitch_deg * D2R) * (speed_change_fps + old_speed_fps);
		var speed_north_fps      = math.cos(hdg_deg * D2R) * speed_horizontal_fps;
		var speed_east_fps       = math.sin(hdg_deg * D2R) * speed_horizontal_fps;

		#var speed_down_fps         =  speed_down_change_fps;# + me.s_down
		#var speed_north_fps        =  speed_north_change_fps;# + me.s_north
		#var speed_east_fps         =  speed_east_change_fps;# + me.s_east

		#var speed_horizontal_fps = math.sqrt(speed_north_fps*speed_north_fps+speed_east_fps*speed_east_fps);
		var new_speed_fps        = math.sqrt(speed_horizontal_fps*speed_horizontal_fps+speed_down_fps*speed_down_fps);


#print("change: down="~speed_down_change_fps~" north="~speed_north_change_fps~" east="~speed_east_change_fps);
#print("new: down="~speed_down_fps~" north="~speed_north_fps~" east="~speed_east_fps);
#print("speed horz: "~speed_horizontal_fps~" (old: "~(dist_h_ft/dt)~")");
#print("speed: new="~new_speed_fps~" old="~old_speed_fps);

		#if (new_speed_fps < 0) {
			# drag can theoretically make the speed less than 0, this will prevent that from happening.
		#	new_speed_fps = 0;
		#}

		# Calculate altitude and elevation velocity vector (no incidence here).
		
		#pitch_deg = math.atan2( speed_down_fps, speed_horizontal_fps ) * R2D;

		# this is commented, cause the missile just falls due to gravity, it doesn't pitch
		# a real missile would pitch ofc. but then have to calc how fuel affects CoG and its inertia/momentum
		# 
		#me.pitch = pitch_deg;
		#pitch_deg = me.pitch;
		
		var dist_h_m = speed_horizontal_fps * dt * FT2M;
		var alt_ft = me.altN.getValue() - ((speed_down_fps + g_fps) * dt);

#print(".");

#print(me.s_down);
#print(speed_down_fps);
#print(me.altN.getValue());
#print(alt_ft);

		me.coord.apply_course_distance(hdg_deg, dist_h_m);
		me.coord.set_alt(alt_ft * FT2M);
		me.latN.setDoubleValue(me.coord.lat());
		me.lonN.setDoubleValue(me.coord.lon());
		me.altN.setDoubleValue(alt_ft);
		me.pitchN.setDoubleValue(pitch_deg);
		me.hdgN.setDoubleValue(hdg_deg);

		# log missiles to csv
		#setprop("missile/latitude-deg", me.coord.lat());
		#setprop("missile/longitude-deg", me.coord.lon());
		#setprop("missile/altitude-ft", alt_ft);
		#setprop("missile/t-latitude-deg", me.t_coord.lat());
		#setprop("missile/t-longitude-deg", me.t_coord.lon());
		#setprop("missile/t-altitude-ft", me.t_coord.alt()*M2FT);

		# set radar properties for use in selection view and HUD tracks.
		var self = geo.aircraft_position();
		me.ai.getNode("radar/bearing-deg", 1).setValue(self.course_to(me.coord));
		var angleInv = me.clamp(self.distance_to(me.coord)/self.direct_distance_to(me.coord), -1, 1);
		me.ai.getNode("radar/elevation-deg", 1).setValue((self.alt()>me.coord.alt()?-1:1)*math.acos(angleInv)*R2D);
		me.ai.getNode("velocities/true-airspeed-kt",1).setValue(new_speed_fps * FPS2KT);

		#### Proximity detection.
		if ( me.status == MISSILE_FLYING ) {
			#### check if the missile can keep the lock.
 			if ( me.free == 0 ) {
				var g = steering_speed_G(me.track_signal_e, me.track_signal_h, old_speed_fps, dt);

# Uncomment this line to check stats while flying:
#
#print(sprintf("Mach %02.1f", me.speed_m)~sprintf(" , time %03.1f s", me.life_time)~sprintf(" , thrust %03.1f lbf", f_lbs)~sprintf(" , G-force %02.2f", g));

				if ( g > me.max_g_current and init_launch != 0) {
					#print("lost lock "~g~"G");
					# Target unreachable, fly free.
					me.free = 1;
					print("Missile attempted to pull too many G, it broke.");
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
										print("Missile fooled by flare");
										me.free = 1;
									} else {
										print("Missile ignored flare");
									}
								}
							}
						}
					}
				}
			}
			var v = me.poximity_detection();
			
			if (v == FALSE) {
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

		settimer(func me.flight(), update_loop_time, REAL_TIME);
		
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

	# navigation and guidance
	guide: func(dt) {
		if (!me.Tgt.getChild("valid").getValue()) {
			# Lost of lock due to target disapearing:
			# destroy missile
			#print("invalid");
			me.del();
			return FALSE;
		}
		#print("track");
		# Time interval since lock time or last track loop.
		
		var last_tgt_e = me.curr_tgt_e;
		var last_tgt_h = me.curr_tgt_h;
		if (dt != nil) {
			# Status = launched. Compute target position relative to seeker head.

			# Get target position.
			var t_alt = me.TgtAlt_prop.getValue();
			me.t_coord.set_latlon(me.TgtLat_prop.getValue(), me.TgtLon_prop.getValue(), t_alt * FT2M);
			
			# Calculate current target elevation and azimut deviation.
			var t_dist_m = me.coord.distance_to(me.t_coord);
			var t_alt_delta_m = (t_alt - me.alt) * FT2M;
			var t_elev_deg =  math.atan2( t_alt_delta_m, t_dist_m ) * R2D;
			me.curr_tgt_e = t_elev_deg - me.pitch;
			var (t_course, dst) = courseAndDistance(me.coord, me.t_coord);
			#var t_course = me.coord.course_to(me.t_coord);
			me.curr_tgt_h = t_course - me.hdg;
			#print();
			#print(sprintf("Altitude above launch platform = %.1f ft", M2FT * (me.coord.alt()-me.ac.alt())));

			#print("tgt alt: "~t_alt~" me alt: "~me.alt);

			# Compute gain to reduce target deviation to match an optimum 3 deg
			# This augments steering by an additional 10 deg per second during
			# the trajectory stage 1 seconds.
			# Then, keep track of deviations at the end of these two initial 2 seconds.
			var e_gain = 1;
			var h_gain = 1;

			if(me.curr_tgt_h < -180) {
				me.curr_tgt_h += 360;
			}
			if(me.curr_tgt_h > 180) {
				me.curr_tgt_h -= 360;
			}

			if(me.speed_m < me.min_speed_for_guiding) {
				# it doesn't guide at lower speeds
				e_gain = 0;
				h_gain = 0;
				me.update_count = -1;
				print("Not guiding (too low speed)");
			} elsif (me.guidance == "semi-radar" and me.is_painted(me.Tgt) == FALSE) {
				# if its semi-radar guided and the target is no longer painted
				e_gain = 0;
				h_gain = 0;
				me.update_count = -1;
				print("Not guiding (lost radar reflection, trying to require)");
			} elsif (me.curr_tgt_e > me.max_seeker_dev or me.curr_tgt_e < (-1 * me.max_seeker_dev)
				  or me.curr_tgt_h > me.max_seeker_dev or me.curr_tgt_h < (-1 * me.max_seeker_dev)) {
				# target is not in missile seeker view anymore
				print("Target is not in missile seeker view anymore");
				me.free = 1;
				e_gain = 0;
				h_gain = 0;
			}
			

			var dev_e = me.curr_tgt_e;#
			var dev_h = me.curr_tgt_h;#

			#print(sprintf("curr: elev=%.1f", dev_e)~sprintf(" head=%.1f", dev_h));
			if (me.last_deviation_e != nil) {
				# its not our first seeker head move
				me.update_count += 1;
				# calculate if the seeker can keep up with the angular change of the target

				# missile own movement is subtracted from this change due to seeker being on gyroscope
				
				var dve_dist = dev_e - me.last_deviation_e + me.last_track_e;
				var dvh_dist = dev_h - me.last_deviation_h + me.last_track_h;
				var deviation_per_sec = math.sqrt(dve_dist*dve_dist+dvh_dist*dvh_dist)/dt;

				if (deviation_per_sec > me.angular_speed) {
					#print(sprintf("last-elev=%.1f", me.last_deviation_e)~sprintf(" last-elev-adj=%.1f", me.last_track_e));
					#print(sprintf("last-head=%.1f", me.last_deviation_h)~sprintf(" last-head-adj=%.1f", me.last_track_h));
					# lost lock due to angular speed limit
					print(sprintf("%.1f deg/s too big angular change for seeker head.", deviation_per_sec));
					#print(dt);
					me.free = 1;
					e_gain = 0;
					h_gain = 0;
				}
			} else {
				me.update_count = 0;
			}

			me.last_deviation_e = dev_e;
			me.last_deviation_h = dev_h;

			var loft_angle = 15;
			var loft_minimum = 10;# miles
			var cruise_minimum = 7.5;# miles
			var cruise_or_loft = 0;
			if ( me.life_time < me.stage_1_duration and t_dist_m * M2NM > loft_minimum
				 and me.coord.alt() * M2FT < me.loft_alt
				 and t_elev_deg < loft_angle and t_elev_deg > -7.5) {
				# stage 1 lofting: due to target is more than 10 miles out and we havent reached 
				# our desired cruising alt, and the elevation to target is less than lofting angle.
				# The -10 limit, is so the seeker don't lose track of target when lofting.
				dev_e = -me.pitch + loft_angle;
				#print(sprintf("Lofting %.1f degs, dev is %.1f", loft_angle, dev_e));
				cruise_or_loft = 1;
			} elsif (t_elev_deg < 0 and me.life_time < me.stage_1_duration+me.stage_2_duration and t_dist_m * M2NM > cruise_minimum) {
				# stage 1/2 cruising: keeping altitude since target is below and more than 5 miles out
				dev_e = -me.pitch;
				#print("Cruising");
				cruise_or_loft = 1;
			}
			

			# proportional navigation
			var dist_curr = me.coord.distance_to(me.t_coord);
			var dist_curr_direct = me.coord.direct_distance_to(me.t_coord);
			if (h_gain != 0 and me.dist_last != nil and me.last_tgt_h != nil) {
					# augmented proportional navigation for heading
					var horz_closing_rate_fps = (me.dist_last - dist_curr)*M2FT/dt;
					var proportionality_constant = 3;#ja37.clamp(me.map(me.speed_m, 2, 5, 5, 3), 3, 5);#
					#setprop("sim/ja37/armament/factor-pro2", proportionality_constant);
					var c_dv = t_course-me.last_t_course;
					if(c_dv < -180) {
						c_dv += 360;
					}
					if(c_dv > 180) {
						c_dv -= 360;
					}
					var line_of_sight_rate_rps = D2R*c_dv/dt;


					# calculate target acc as normal to LOS line:
					var t_heading        = me.TgtHdg_prop.getValue();
					var t_pitch          = me.TgtPitch_prop.getValue();
					var t_speed          = me.TgtSpeed_prop.getValue()*KT2FPS;#true airspeed
					var t_horz_speed     = t_speed - math.abs(math.sin(t_pitch*D2R)*t_speed);
					var t_LOS_norm_head  = t_course + 90;
					var t_LOS_norm_speed = math.cos((t_LOS_norm_head - t_heading)*D2R)*t_horz_speed;

					if (me.last_t_norm_speed == nil) {
						me.last_t_norm_speed = t_LOS_norm_speed;
					}

					var t_LOS_norm_acc   = (t_LOS_norm_speed - me.last_t_norm_speed)/dt;

					me.last_t_norm_speed = t_LOS_norm_speed;

					# acceleration perpendicular to instantaneous line of sight in feet/sec^2
					var acc_sideways_ftps2 = proportionality_constant*line_of_sight_rate_rps*horz_closing_rate_fps+proportionality_constant*t_LOS_norm_acc/2;

					# now translate that sideways acc to an angle:
					var velocity_vector_length_fps = me.old_speed_horz_fps;
					var commanded_sideways_vector_length_fps = acc_sideways_ftps2*dt;
					dev_h = math.atan2(commanded_sideways_vector_length_fps, velocity_vector_length_fps)*R2D;

					#print(sprintf("LOS-rate=%.2f rad/s - closing-rate=%.1f ft/s",line_of_sight_rate_rps,closing_rate_fps));
					#print(sprintf("commanded-perpendicular-acceleration=%.1f ft/s^2", acc_sideways_ftps2));
					#print(sprintf("horz leading by %.1f deg, commanding %.1f deg", me.curr_tgt_h, dev_h));

					if (cruise_or_loft == 0 and me.last_cruise_or_loft == 0) {
						# augmented proportional navigation for elevation
						var vert_closing_rate_fps = (me.dist_direct_last - dist_curr_direct)*M2FT/dt;
						var line_of_sight_rate_up_rps = D2R*(t_elev_deg-me.last_t_elev_deg)/dt;

						# calculate target acc as normal to LOS line: (up acc is positive)
						var t_approach_bearing             = t_course + 180;
						var t_horz_speed_away_from_missile = -math.cos((t_approach_bearing - t_heading)*D2R)* t_horz_speed;
						var t_horz_comp_speed              = math.cos((90+t_elev_deg)*D2R)*t_horz_speed_away_from_missile;
						var t_vert_comp_speed              = math.sin(t_pitch*D2R)*t_speed*math.cos(t_elev_deg*D2R);
						var t_LOS_elev_norm_speed          = t_horz_comp_speed + t_vert_comp_speed;

						if (me.last_t_elev_norm_speed == nil) {
							me.last_t_elev_norm_speed = t_LOS_elev_norm_speed;
						}

						var t_LOS_elev_norm_acc            = (t_LOS_elev_norm_speed - me.last_t_elev_norm_speed)/dt;
						me.last_t_elev_norm_speed          = t_LOS_elev_norm_speed;

						var acc_upwards_ftps2 = proportionality_constant*line_of_sight_rate_up_rps*vert_closing_rate_fps+proportionality_constant*t_LOS_elev_norm_acc/2;
						var commanded_upwards_vector_length_fps = acc_upwards_ftps2*dt;
						dev_e = math.atan2(commanded_upwards_vector_length_fps, velocity_vector_length_fps)*R2D;
						#print(sprintf("vert leading by %.1f deg", me.curr_tgt_e));
					}
			}
			me.dist_last = dist_curr;
			me.dist_direct_last = dist_curr_direct;
			me.t_alt_delta_last_m = t_alt_delta_m;
			me.last_tgt_h = me.curr_tgt_h;
			me.last_tgt_e = me.curr_tgt_e;

			me.track_signal_e = dev_e * e_gain;
			me.track_signal_h = dev_h * h_gain;

			#print(sprintf("%.1f deg elevate command", me.track_signal_e));
			#print(sprintf("%.1f deg bearing command, %.1f deg lead", me.track_signal_h, me.h_add));			

			me.last_t_course = t_course;
			me.last_t_elev_deg = t_elev_deg;
			me.last_cruise_or_loft = cruise_or_loft;
			
#print ("**** curr_tgt_e = ", me.curr_tgt_e," curr_tgt_h = ", me.curr_tgt_h, " me.track_signal_e = ", me.track_signal_e," me.track_signal_h = ", me.track_signal_h);


		}

		return TRUE;
	},

	map: func (value, leftMin, leftMax, rightMin, rightMax) {
	    # Figure out how 'wide' each range is
	    var leftSpan = leftMax - leftMin;
	    var rightSpan = rightMax - rightMin;

	    # Convert the left range into a 0-1 range (float)
	    var valueScaled = (value - leftMin) / leftSpan;

	    # Convert the 0-1 range into a value in the right range.
	    return rightMin + (valueScaled * rightSpan);
	},

	poximity_detection: func {
		var cur_dir_dist_m = me.coord.direct_distance_to(me.t_coord);
		# Get current direct distance.
		if ( me.direct_dist_m != nil and me.life_time > me.arming_time) {
			#print("distance to target_m = "~cur_dir_dist_m~" prev_distance to target_m = "~me.direct_dist_m);
			if ( cur_dir_dist_m > me.direct_dist_m and cur_dir_dist_m < 250) {
				#print("passed target");
				# Distance to target increase, trigger explosion.
				me.explode("Passed target.");
				return FALSE;
			#} #elsif (cur_dir_dist_m < 15) {
			#	print("proximity fuse activated.");
				#within killing distance, explode 
				#(this might not be how the real thing does, but due to this only being called every frame, might miss otherwise)
			#	me.explode();
			#	return(0);
			}# elsif (me.free == 1 and cur_dir_dist_m < m.prox_dist) {
				#print("Magnetic fuse active.");
				# lost lock, magnetic detector checks if close enough to explode
				#me.explode();
				#return(0);
			#}
		}
		if (me.life_time > me.selfdestruct_time) {
			me.explode("Selfdestructed.");
		    return FALSE;
		}
		####Ground interaction
        var ground = geo.elevation(me.coord.lat(), me.coord.lon());
        #print("Ground :",ground);
        if(ground != nil)
        {
            if(ground > me.coord.alt()) {
                me.explode("Hit terrain.");
                return FALSE;
            }
        }
		me.before_last_t_coord = geo.Coord.new(me.last_t_coord);
		me.last_t_coord = geo.Coord.new(me.t_coord);
		me.direct_dist_m = cur_dir_dist_m;
		return TRUE;
	},

	explode: func (reason) {
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
		for (var i = 0.05; i < 1; i += 0.05) {
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
			for (var i = 0.05; i < 1; i += 0.05) {
				var t_coord = me.interpolate(me.before_last_t_coord, me.last_t_coord, i);
				var coord = me.interpolate(me.before_last_coord, me.last_coord, i);
				var dist = coord.direct_distance_to(t_coord);
				if (dist < min_distance) {
					min_distance = dist;
					explosion_coord = coord;
				}
			}
		}
		me.coord = explosion_coord;
		#print("min3 "~min_distance);

		# Create impact coords from this previous relative position applied to target current coord.
		me.t_coord.apply_course_distance(t_bearing_deg, t_dist_m);
		me.t_coord.set_alt(new_t_alt_m);		
		var wh_mass = me.weight_whead_lbs / slugs_to_lbs;
		#print("FOX2: me.direct_dist_m = ",  me.direct_dist_m, " time ",getprop("sim/time/elapsed-sec"));
		impact_report(me.t_coord, wh_mass, "missile"); # pos, alt, mass_slug,(speed_mps)

		var phrase = sprintf( me.type~" exploded: %01.1f", min_distance) ~ " meters from: " ~ me.callsign;
		print(phrase~"  Reason: "~reason);
		if (min_distance < 65) {
			if (getprop("sim/ja37/armament/msg")) {
				setprop("/sim/multiplay/chat", armament.defeatSpamFilter(phrase));
			} else {
				setprop("/sim/messages/atc", phrase);
			}
		}
		
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

	# aircraft searching for lock
	search: func {
		if ( me.status == MISSILE_FLYING ) {
			me.SwSoundVol.setValue(0);
			return;
		} elsif ( me.status == MISSILE_STANDBY ) {
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
		if (1==1 or canvas_HUD.diamond_node != me.Tgt) {
			#print("search2");
			if (canvas_HUD.diamond_node != nil and canvas_HUD.diamond_node.getChild("valid").getValue() == TRUE) {
				#print("search3");
				var tgt = canvas_HUD.diamond_node; # In the radar range and horizontal field.
				var rng = tgt.getChild("radar").getChild("range-nm").getValue();
				var total_elev  = deviation_normdeg(OurPitch.getValue(), tgt.getChild("radar").getChild("elevation-deg").getValue()); # deg.
				var total_horiz = deviation_normdeg(OurHdg.getValue(), tgt.getChild("radar").getChild("bearing-deg").getValue());         # deg.
				# Check if in range and in the (square shaped here) seeker FOV.
				var abs_total_elev = math.abs(total_elev);
				var abs_dev_deg = math.abs(total_horiz);
				if ((me.guidance != "semi-radar" or me.is_painted(tgt) == TRUE) and rng < me.max_detect_rng and abs_total_elev < me.aim9_fov and abs_dev_deg < me.aim9_fov ) {
					#print("search4");
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
					var t_vel_str = me.Tgt.getChild("velocities");
					me.TgtLon_prop       = t_pos_str.getChild("longitude-deg");
					me.TgtLat_prop       = t_pos_str.getChild("latitude-deg");
					me.TgtAlt_prop       = t_pos_str.getChild("altitude-ft");
					me.TgtHdg_prop       = t_ori_str.getChild("true-heading-deg");
					me.TgtPitch_prop     = t_ori_str.getChild("pitch-deg");
					me.TgtSpeed_prop     = t_vel_str.getChild("true-airspeed-kt");

					var time = props.globals.getNode("/sim/time/elapsed-sec", 1).getValue();
					me.update_track_time = time;

					settimer(func me.update_lock(), 0.5);
					return;
				} else {
					me.Tgt = nil;
				}
			} else {
				me.Tgt = nil;
			}
		}
		me.SwSoundVol.setValue(me.vol_search);
		me.trackWeak = 1;
		settimer(func me.search(), 0.1);
	},

	# Missile locked on target
	update_lock: func() {
		if ( me.Tgt == nil or me.status == MISSILE_FLYING) {
			return TRUE;
		}
		if (me.status == MISSILE_SEARCH) {
			# Status = searching.
			me.return_to_search();
			return TRUE;
		} elsif ( me.status == MISSILE_STANDBY ) {
			# Status = stand-by.
			me.reset_seeker();
			me.SwSoundVol.setValue(0);
			me.trackWeak = 1;
			return TRUE;
		} elsif (!me.Tgt.getChild("valid").getValue()) {
			# Lost of lock due to target disapearing:
			# return to search mode.
			#print("invalid");
			me.return_to_search();
			return TRUE;
		}
		#print("lock");
		# Time interval since lock time or last track loop.
		
		var last_tgt_e = me.curr_tgt_e;
		var last_tgt_h = me.curr_tgt_h;
		if (me.status == MISSILE_LOCK) {		
			# Status = locked. Get target position relative to our aircraft.
			me.curr_tgt_e = - deviation_normdeg(OurPitch.getValue(), me.Tgt.getChild("radar").getChild("elevation-deg").getValue());
			me.curr_tgt_h = - deviation_normdeg(OurHdg.getValue(), me.Tgt.getChild("radar").getChild("bearing-deg").getValue());
		}

		var time = props.globals.getNode("/sim/time/elapsed-sec", 1).getValue();

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
		if (me.status != MISSILE_STANDBY ) {
			var in_view = me.check_t_in_fov();
			if (in_view == FALSE) {
				#print("out of view");
				me.return_to_search();
				return TRUE;
			}
			# We are not launched yet: update_track() loops by itself at 10 Hz.
			var dist = geo.aircraft_position().direct_distance_to(geo.Coord.new().set_latlon(
				me.TgtLat_prop.getValue(),
				me.TgtLon_prop.getValue(),
				me.TgtAlt_prop.getValue()*FT2M));
			if (time - me.update_track_time > 1 and dist != nil and dist > (me.min_dist * NM2M)) {
				# after 1 second we get solid track if target is further than minimum distance.
				me.SwSoundVol.setValue(vol_track);
				me.trackWeak = 0;
			} else {
				me.SwSoundVol.setValue(vol_weak_track);
				me.trackWeak = 1;
			}
			if (canvas_HUD.diamond_node == nil or (canvas_HUD.diamond_node.getNode("unique") != nil and me.Tgt.getNode("unique") != nil and canvas_HUD.diamond_node.getNode("unique").getValue() != me.Tgt.getNode("unique").getValue())) {
				#print("oops "~me.Tgt.getPath());
				me.return_to_search();
				return TRUE;
			}
			settimer(func me.update_lock(), 0.1);
		}
		return TRUE;
	},

	return_to_search: func {
		me.status = MISSILE_SEARCH;
		me.Tgt = nil;
		me.SwSoundVol.setValue(me.vol_search);
		me.trackWeak = 1;
		me.reset_seeker();
		#print("return");
		settimer(func me.search(), 0.1);
	},

		#
	check_t_in_fov: func {

		var total_elev  = deviation_normdeg(OurPitch.getValue(), me.Tgt.getChild("radar").getChild("elevation-deg").getValue()); # deg.
		var total_horiz = deviation_normdeg(OurHdg.getValue(), me.Tgt.getChild("radar").getChild("bearing-deg").getValue());         # deg.
		# Check if in range and in the (square shaped here) seeker FOV.
		var abs_total_elev = math.abs(total_elev);
		var abs_dev_deg = math.abs(total_horiz);
		if (abs_total_elev < me.aim9_fov and abs_dev_deg < me.aim9_fov ) {
			return TRUE;
		}
		return FALSE;


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
		if (me.status != MISSILE_FLYING and (me.curr_tgt_e < e_d or me.curr_tgt_e > e_u or me.curr_tgt_h < h_l or me.curr_tgt_h > h_r) ) {		
			# Target out of FOV while still not launched, return to search loop.
			return FALSE;
		}
		return TRUE;
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
		# a last position update to where the explosion happened:
		me.latN.setDoubleValue(me.coord.lat());
		me.lonN.setDoubleValue(me.coord.lon());
		me.altN.setDoubleValue(me.coord.alt()*M2FT);

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

	# next speed vector
	var vector_next_x = math.cos(steer_deg*D2R)*s_fps;
	var vector_next_y = math.sin(steer_deg*D2R)*s_fps;
	
	# present speed vector
	var vector_now_x = s_fps;
	var vector_now_y = 0;

	# subtract the vectors from each other
	var dv = math.sqrt((vector_now_x - vector_next_x)*(vector_now_x - vector_next_x)+(vector_now_y - vector_next_y)*(vector_now_y - vector_next_y));

	# calculate g-force
	# dv/dt=a
	var g = (dv/dt) / g_fps;

	# old calc with circle:
	#var radius_ft = math.abs(s_fps / math.sin(steer_deg*D2R));
	#var g = ( (s_fps * s_fps) / radius_ft ) / g_fps;
	#print("#### R = ", radius_ft, " G = ", g); ##########################################################
	return g;
}

var semi_old_max_G_Rotation = func(steering_e_deg, steering_h_deg, s_fps, dt, gMax) {
	for(var i = 1; i >= 0; i-=0.005) {
		var new_g = steering_speed_G(steering_e_deg*i, steering_h_deg*i, s_fps, dt);
		if (new_g < gMax) {
			return i;
		}
	}
	return 0;
}

var max_G_Rotation = func(steering_e_deg, steering_h_deg, s_fps, dt, gMax) {
	var guess = 1;
	var coef = 1;
	var lastgoodguess = 1;

	for(var i=1;i<25;i+=1){
		coef = coef/2;
		var new_g = steering_speed_G(steering_e_deg*guess, steering_h_deg*guess, s_fps, dt);
		if (new_g < gMax) {
			lastgoodguess = guess;
			guess = guess + coef;
		} else {
			guess = guess - coef;
		}
	}
	return lastgoodguess;
}

var old_max_G_Rotation = func(steering_e_deg, steering_h_deg, s_fps, dt,gMax) {
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