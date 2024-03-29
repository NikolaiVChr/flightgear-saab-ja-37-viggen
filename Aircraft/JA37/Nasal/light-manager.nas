# provides relative vectors from eye-point to aircraft lights
# in east/north/up coordinates the renderer uses
# Thanks to BAWV12 / Thorsten

# 5H1N0B1 201911 :
# Put light stuff in a different object inorder to manage different kind of light
# This need to have work in order to initialize the differents lights with the new object
# Then we need to put a foreach loop in the update loop

# NikolaiVChr:
# made landing and taxi light spot be placed somewhat correct from light beam and be dimmed in sunlight
# Adapted for Viggen 2020-03


var als_on = props.globals.getNode("/sim/rendering/shaders/skydome");
var alt_agl = props.globals.getNode("/position/altitude-agl-ft");
var cur_alt = 0;

var taxiLight = props.globals.getNode("ja37/effect/taxi-light", 1);
var landingLight = props.globals.getNode("ja37/effect/landing-light", 1);
var navLight     = props.globals.getNode("sim/multiplay/generic/short[0]",1);
var noseSteerNorm= props.globals.getNode("sim/multiplay/generic/float[0]",1);

var gearPos = props.globals.getNode("gear/gear[0]/position-norm", 1);
var sceneLight = props.globals.getNode("rendering/scene/diffuse/red", 1);

var light_manager = {

	run: 0,
	
	lat_to_m: 110952.0,
	lon_to_m: 0.0,
	
	
	init: func {
		# define your lights here

		# lights ########
      me.data_light = [
                        #x,y,z,  light_dir,light_size,light_stretch,   light_r,light_g,light_b,  light_is_on,number
        ALS_light_spot.new(-3.78118, 0, -0.76959,      0, 0.125,-2.5, 0.7,0.7,0.7, 0,0),#landing
        ALS_light_spot.new(-3.37668, 0, -1.21053,      0, 0.5,-3,     0.7,0.7,0.7, 0,1),#taxi
        ALS_light_spot.new(5.56226,-4.55875,-0.389571, 0,2,0,         0.5,0,0,     0,2),#left
        ALS_light_spot.new(5.56226, 4.55875,-0.389571, 0,2,0,         0,0.5,0,     0,3),#right
      ];

		
		
		#setprop("sim/rendering/als-secondary-lights/flash-radius", 13);

		me.start();
	},

	start: func {
		setprop("/sim/rendering/als-secondary-lights/num-lightspots", size(me.data_light));
 
 
		me.run = 1;		
		me.update();
	},

	stop: func {
    setprop("/sim/rendering/als-secondary-lights/num-lightspots", 0);
		me.run = 0;
	},

	update: func {
		if (me.run == 0) {
			return;
		}
		
		cur_alt = alt_agl.getValue();
    if(cur_alt != nil){
      if (als_on.getValue() == 1) {
          
          #Condition for lights
          if(gearPos.getValue() > 0.3 and landingLight.getValue() and alt_agl.getValue() < 1700.0){
              me.data_light[0].light_on();    
          } else {
              me.data_light[0].light_off();
          }
          
          if(gearPos.getValue() > 0.3 and taxiLight.getValue() and alt_agl.getValue() < 20.0){
              me.data_light[1].light_on();            
          }else{
              me.data_light[1].light_off();
          }
          
          if(navLight.getValue() > 0 and alt_agl.getValue() < 20.0){
              me.data_light[2].light_on();
              me.data_light[3].light_on();
          }else{
              me.data_light[2].light_off();
              me.data_light[3].light_off();
          }
          
         #Updating each light position 
        for(var i = 0; i < size(me.data_light); i += 1)
        {
          me.data_light[i].position();
        }
      } else {
        me.data_light[0].light_off();
        me.data_light[1].light_off();
        me.data_light[2].light_off();
        me.data_light[3].light_off();
      }
    } else {
      me.data_light[0].light_off();
      me.data_light[1].light_off();
      me.data_light[2].light_off();
      me.data_light[3].light_off();
    }
		
		settimer ( func me.update(), 0.00);
	},
};


var ALS_light_spot = {
    new:func (
            light_xpos,
            light_ypos,
            light_zpos,
            light_dir,
            light_size,
            light_stretch,
            light_r,
            light_g,
            light_b,
            light_is_on,
            number
          ){
            var me = { parents : [ALS_light_spot] };
            if(number ==0){
              me.nd_ref_light_x=  props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/eyerel-x-m", 1);
              me.nd_ref_light_y=  props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/eyerel-y-m", 1);
              me.nd_ref_light_z= props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/eyerel-z-m", 1);
              me.nd_ref_light_dir= props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/dir", 1);
              me.nd_ref_light_size= props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/size", 1);
              me.nd_ref_light_stretch= props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/stretch", 1);
              me.nd_ref_light_r=props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/lightspot-r",1);
              me.nd_ref_light_g=props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/lightspot-g",1);
              me.nd_ref_light_b=props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/lightspot-b",1);
            }else{
              me.nd_ref_light_x=  props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/eyerel-x-m["~number~"]", 1);
              me.nd_ref_light_y=  props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/eyerel-y-m["~number~"]", 1);
              me.nd_ref_light_z= props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/eyerel-z-m["~number~"]", 1);
              me.nd_ref_light_dir= props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/dir["~number~"]", 1);
              me.nd_ref_light_size= props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/size["~number~"]", 1);
              me.nd_ref_light_stretch= props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/stretch["~number~"]", 1);
              me.nd_ref_light_r=props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/lightspot-r["~number~"]", 1);
              me.nd_ref_light_g=props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/lightspot-g["~number~"]", 1);
              me.nd_ref_light_b=props.globals.getNode("/sim/rendering/als-secondary-lights/lightspot/lightspot-b["~number~"]", 1);
            }
            
              me.light_xpos = light_xpos;
              me.light_ypos=light_ypos;
              me.light_zpos=light_zpos;
              me.light_dir=light_dir;
              me.light_size=light_size;
              me.light_stretch=light_stretch;
              me.light_r=light_r;
              me.light_g=light_g;
              me.light_b=light_b;
              me.light_is_on=light_is_on;
              me.number = number;
              
              #print("light_stretch:"~light_stretch);
              
              me.lon_to_m  = 0;
              
              me.nd_ref_light_x.setValue(me.light_xpos);
              me.nd_ref_light_y.setValue(me.light_ypos);
              me.nd_ref_light_z.setValue(me.light_zpos);
              me.nd_ref_light_r.setValue(me.light_r);
              me.nd_ref_light_g.setValue(me.light_g);
              me.nd_ref_light_b.setValue(me.light_b);
              me.nd_ref_light_dir.setValue(me.light_dir);
              me.nd_ref_light_size.setValue(me.light_size);
              me.nd_ref_light_stretch.setValue(me.light_stretch);
            
            return me;
    },
    
    lat2m: func (lat) {
      # Nikolai V Chr
      me.lat_to_nm = [59.7052, 59.7453, 59.8554, 60.0062, 60.1577, 60.2690, 60.3098];# 15 deg intervals
      me.indexLat = math.abs(lat)/15;
      if (me.indexLat == 0) {
        me.lat2nm = me.lat_to_nm[0];
      } elsif (me.indexLat == 6) {
        me.lat2nm = me.lat_to_nm[6];
      } else {
        me.lat2nm = me.extrapolate(me.indexLat-int(me.indexLat), 0, 1, me.lat_to_nm[int(me.indexLat)], me.lat_to_nm[int(me.indexLat)+1]);
      }
      return me.lat2nm*NM2M;
    },
    
    extrapolate: func (x, x1, x2, y1, y2) {
      return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
    },
    
    position: func(){
      
      var apos = nil;
			var vpos = geo.viewer_position();

			me.lon_to_m = math.cos(vpos.lat()*D2R) * me.lat2m(0);
			var heading = self.getHeading()*D2R;

      if (me.number == 0) {
        #landing light
        #
        
        #set light source position on aircraft
        landB.setLightPos(me.light_xpos,me.light_ypos,me.light_zpos);
        
        # set light beam pitch
        landB.setBeamPitch(-9.14);#glideslope of -2.86 degs, AoA of 12 degs: -(12-2.86) = -9.14 degs
        
        #calc where beam hits ground
        var test = landB.testForDistance();
        
        if (test != nil) {
          #grab spot position
          apos = test[1];
          
          # light intensity. fade fully out at 500m dist:
          me.light_r = 0.8-0.8*math.clamp(test[0],0,500)/500;
          me.light_g = me.light_r;
          me.light_b = me.light_r;
       
          # calc spot position in relation to view position:
          var delta_x = (apos.lat() - vpos.lat()) * me.lat2m(vpos.lat());
          var delta_y = -(apos.lon() - vpos.lon()) * me.lon_to_m;
          var delta_z = apos.alt() - vpos.alt();
          me.nd_ref_light_x.setValue(delta_x);
          me.nd_ref_light_y.setValue(delta_y);
          me.nd_ref_light_z.setValue(delta_z);
          
          me.nd_ref_light_dir.setValue(heading);# used to determine spot stretch direction
          me.nd_ref_light_size.setValue(me.light_size*test[0]);#spot radius grows linear with distance
        } else {
          me.light_is_on = 0;
        }
      } elsif (me.number == 2 or me.number == 3) {
        #red/green nav light
        #
        
        #set light source position on aircraft (same as spot location in this case, spots are 3D spheres)
        me.lightGPS = aircraftToCart({x:-me.light_xpos, y:me.light_ypos, z: -me.light_zpos});# sadly this C++ method has inaccuracies up to about 1 meter.
        apos = geo.Coord.new().set_xyz(me.lightGPS.x,me.lightGPS.y,me.lightGPS.z);
        
        # calc spot position in relation to view position:
        var delta_x = (apos.lat() - vpos.lat()) * me.lat2m(vpos.lat());
        var delta_y = -(apos.lon() - vpos.lon()) * me.lon_to_m;
        var delta_z = apos.alt() - vpos.alt();
        me.nd_ref_light_x.setValue(delta_x);
        me.nd_ref_light_y.setValue(delta_y);
        me.nd_ref_light_z.setValue(delta_z);
        
        
        me.nd_ref_light_size.setValue(me.light_size*navLight.getValue()*0.01);#spot radius is fixed, depends only on light strength setting.
      } else {
        #taxi light
        #
        
        #set light source position on aircraft
        taxiB.setLightPos(me.light_xpos,me.light_ypos,me.light_zpos);
        
        # set light beam pitch and relative heading
        taxiB.setBeam(-3,noseSteerNorm.getValue()*30);#-0.5 degs down, relative heading
        
        #calc where beam hits ground
        var test = taxiB.testForDistance();
        
        if (test != nil) {
          #grab spot position
          apos = test[1];
        
          # calc spot position in relation to view position:
          var delta_x = (apos.lat() - vpos.lat()) * me.lat2m(vpos.lat());
          var delta_y = -(apos.lon() - vpos.lon()) * me.lon_to_m;
          var delta_z = apos.alt() - vpos.alt();          
          me.nd_ref_light_x.setValue(delta_x);
          me.nd_ref_light_y.setValue(delta_y);
          me.nd_ref_light_z.setValue(delta_z);
          
          # set absolute heading of stretch
          me.nd_ref_light_dir.setValue(heading+noseSteerNorm.getValue()*30*D2R);
          
          #spot radius grows linear with distance
          me.nd_ref_light_size.setValue(me.light_size*test[0]);
        } else {
          me.light_is_on = 0;
        }
      }
      if (me.light_is_on) {
        # scene red invrted will dim the light so it dont compete with sun
        var red = 1-sceneLight.getValue();
        me.nd_ref_light_r.setValue(red*me.light_r);
        me.nd_ref_light_g.setValue(red*me.light_g);
        me.nd_ref_light_b.setValue(red*me.light_b);
      } else {
        me.nd_ref_light_r.setValue(0);
        me.nd_ref_light_g.setValue(0);
        me.nd_ref_light_b.setValue(0);
      }
    },
    light_on : func {
        me.light_is_on = 1;
      },
  
    light_off : func {
        me.light_is_on = 0;
      },
  
};


SelfContact = {
# Ownship info
#
# Author: Nikolai V. Chr.
  new: func {
    var c = {parents: [SelfContact]};

    c.init();

      return c;
  },

  init: func {
    # read all properties and store them for fast lookup.
      me.acHeading  = props.globals.getNode("orientation/heading-deg");
      me.acPitch    = props.globals.getNode("orientation/pitch-deg");
      me.acRoll     = props.globals.getNode("orientation/roll-deg");
      me.acalt      = props.globals.getNode("position/altitude-ft");
      me.aclat      = props.globals.getNode("position/latitude-deg");
      me.aclon      = props.globals.getNode("position/longitude-deg");
      me.acgns      = props.globals.getNode("velocities/groundspeed-kt");
      me.acdns      = props.globals.getNode("velocities/speed-down-fps");
      me.aceas      = props.globals.getNode("velocities/speed-east-fps");
      me.acnos      = props.globals.getNode("velocities/speed-north-fps");
  },
  
  getCoord: func {
    me.accoord = geo.Coord.new().set_latlon(me.aclat.getValue(), me.aclon.getValue(), me.acalt.getValue()*FT2M);
      return me.accoord;
  },
  
  getAttitude: func {
    return [me.acHeading.getValue(),me.acPitch.getValue(),me.acRoll.getValue()];
  },
  
  getSpeedVector: func {
    me.speed_down_mps  = me.acdns.getValue()*FT2M;
        me.speed_east_mps  = me.aceas.getValue()*FT2M;
        me.speed_north_mps = me.acnos.getValue()*FT2M;
        return [me.speed_north_mps,-me.speed_east_mps,-me.speed_down_mps];
  },
  
  getHeading: func {
    return me.acHeading.getValue();
  },
  
  getPitch: func {
    return me.acPitch.getValue();
  },
  
  getRoll: func {
    return me.acRoll.getValue();
  },
  
  getSpeed: func {
    return me.acgns.getValue();
  },
};

var self = SelfContact.new();


Radar = {
# master radar class
#
# Attributes:
#   on/off
#   limitedContactVector of RadarContacts
  enabled: 1,
};


var FixedBeamRadar = {
# inherits from Radar
#
# adapted for use in light beam calculations
#
# Author: Nikolai V. Chr.
  new: func () {
    var fb = {parents: [FixedBeamRadar, Radar]};
    
    fb.beam_pitch_deg = 0;
    
    return fb;
  },
  
  setBeamPitch: func (pitch_deg) {
    me.beam_pitch_deg = pitch_deg;
  },
  
  setLightPos: func (x,y,z) {
    me.x = x;
    me.y = y;
    me.z = z;
  },
  
  getLightCoord: func {
      me.light = aircraftToCart({x:-me.x, y:me.y, z: -me.z});# sadly this C++ method has inaccuracies up to about 1 meter.
      me.accoord = geo.Coord.new().set_xyz(me.light.x,me.light.y,me.light.z);
      return me.accoord;
  },
  
  computeBeamVector: func {
    me.beamVector = [math.cos(me.beam_pitch_deg*D2R), 0, math.sin(me.beam_pitch_deg*D2R)];
    me.beamVectorFix = vector.Math.rollPitchYawVector(self.getRoll(), self.getPitch(), -self.getHeading(), me.beamVector);
    me.geoVector = vector.Math.vectorToGeoVector(vector.Math.normalize(me.beamVectorFix), me.getLightCoord());
    return me.geoVector;
  },
  
  testForDistance: func {
    if (me.enabled) {
      me.selfPos = me.getLightCoord();
      me.pick = get_cart_ground_intersection({"x":me.selfPos.x(), "y":me.selfPos.y(), "z":me.selfPos.z()}, me.computeBeamVector());
          if (me.pick != nil) {
          me.terrain = geo.Coord.new();
        me.terrain.set_latlon(me.pick.lat, me.pick.lon, me.pick.elevation);
        me.terrainDist_m = me.selfPos.direct_distance_to(me.terrain);
        
        return [me.terrainDist_m, me.terrain];
        }
      }
      return nil;
  },
};

var SteerBeamRadar = {
# inherits from Radar
#
# adapted for use in light beam calculations
#
# Author: Nikolai V. Chr.
  new: func () {
    var fb = {parents: [SteerBeamRadar, Radar]};
    
    fb.beam_pitch_deg = 0;
    fb.beam_yaw_deg   = 0;
    
    return fb;
  },
  
  setLightPos: func (x,y,z) {
    me.x = x;
    me.y = y;
    me.z = z;
  },
  
  getLightCoord: func {
    # this is much faster than calling geo.aircraft_position().
      me.light = aircraftToCart({x:-me.x, y:me.y, z: -me.z});# sadly this C++ method has inaccuracies up to about 1 meter.
      me.accoord = geo.Coord.new().set_xyz(me.light.x,me.light.y,me.light.z);
      return me.accoord;
  },
  
  setBeam: func (pitch_deg, yaw_deg) {
    me.beam_pitch_deg = pitch_deg;
    me.beam_yaw_deg = yaw_deg;
  },
  
  computeBeamVector: func {
    me.beamVector = [math.cos(me.beam_pitch_deg*D2R)*math.cos(me.beam_yaw_deg*D2R), -math.sin(me.beam_yaw_deg*D2R), math.sin(me.beam_pitch_deg*D2R)*math.cos(me.beam_yaw_deg*D2R)];
    me.beamVectorFix = vector.Math.rollPitchYawVector(self.getRoll(), self.getPitch(), -self.getHeading(), me.beamVector);
    me.geoVector = vector.Math.vectorToGeoVector(me.beamVectorFix, me.getLightCoord());
    return me.geoVector;
  },
  
  testForDistance: func {
    if (me.enabled) {
      me.selfPos = me.getLightCoord();
      me.pick = get_cart_ground_intersection({"x":me.selfPos.x(), "y":me.selfPos.y(), "z":me.selfPos.z()}, me.computeBeamVector());
          if (me.pick != nil) {
          me.terrain = geo.Coord.new();
        me.terrain.set_latlon(me.pick.lat, me.pick.lon, me.pick.elevation);
        me.terrainDist_m = me.selfPos.direct_distance_to(me.terrain);
        return [me.terrainDist_m, me.terrain];
        }
      }
      return nil;
  },
};

var landB = FixedBeamRadar.new();
var taxiB = SteerBeamRadar.new();
