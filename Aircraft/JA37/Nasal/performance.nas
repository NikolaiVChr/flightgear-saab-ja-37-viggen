###############################################################################
# fermormance.nas by Tatsuhiro Nishioka
# - Performance Monitor for developing JSBSim models
# 
# Copyright (C) 2009 Tatsuhiro Nishioka (tat dot fgmacosx at gmail dot com)
# This file is licensed under the GPL version 2 or later.
# 
# How to use:
#  You can use performance Monitor by pressing Ctrl-Shift-M
#  
# Developer's Guide
#  To add a new monitor, you can make a class derived from MonitorBase, 
#  and implement reinit, start, pdate, and properties methods.
#  Then, register an instance of the class to PerformanceMonitor instance.
#
###############################################################################

var printf = func { print(call(sprintf, arg)) }

# setup property nodes
input = {
  speedG:           "velocities/groundspeed-kt",
  running:          "engines/engine/running",
  perfEff:          "/sim/gui/dialogs/performance-monitor/efficiency",
  fuel:             "/consumables/fuel",
  perfRangeTotal:   "/sim/gui/dialogs/performance-monitor/total-range",
  perfRange:        "/sim/gui/dialogs/performance-monitor/range",
  perfTime:         "/sim/gui/dialogs/performance-monitor/time",
  perfDistFt:       "/sim/gui/dialogs/performance-monitor/to-dist-ft",
  perfDistM:        "/sim/gui/dialogs/performance-monitor/to-dist-m",
  perfDistLandFt:   "/sim/gui/dialogs/performance-monitor/land-dist-ft",
  perfDistLandM:    "/sim/gui/dialogs/performance-monitor/land-dist-m",
  perfMach:         "/sim/gui/dialogs/performance-monitor/mach",         
  perfClimb:        "/sim/gui/dialogs/performance-monitor/climb-rate",   
  perfSpeedG:       "/sim/gui/dialogs/performance-monitor/groundspeed",  
  perfTAS:          "/sim/gui/dialogs/performance-monitor/TAS",          
  perfAlpha:        "/sim/gui/dialogs/performance-monitor/angleofattack",
  perfG:            "/sim/gui/dialogs/performance-monitor/gforce",       
  perfRoll:         "/sim/gui/dialogs/performance-monitor/roll-rate",    
  perfTurnRate:     "/sim/gui/dialogs/performance-monitor/turn-rate",    
  perfTurnRad:      "/sim/gui/dialogs/performance-monitor/turn-radius",  
  perfSink:         "/sim/gui/dialogs/performance-monitor/sink-rate",    
  perfWindDir:      "/sim/gui/dialogs/performance-monitor/wind-dir",     
  perfWindKt:       "/sim/gui/dialogs/performance-monitor/wind-kt",      
  perfTemp:         "/sim/gui/dialogs/performance-monitor/temp",         
  perfAlt:          "/sim/gui/dialogs/performance-monitor/alt",          
  perfInhg:         "/sim/gui/dialogs/performance-monitor/inhg",         
  perfRho:          "/sim/gui/dialogs/performance-monitor/density",      
  perfExcess:       "/sim/gui/dialogs/performance-monitor/excess-thrust",
  perfLd:           "/sim/gui/dialogs/performance-monitor/ratio-lift-drag",
  perfTw:           "/sim/gui/dialogs/performance-monitor/ratio-thrust-weight",
  perfLw:           "/sim/gui/dialogs/performance-monitor/ratio-lift-weight",
  perfTd:           "/sim/gui/dialogs/performance-monitor/ratio-thrust-drag",
  perfMargin:       "/sim/gui/dialogs/performance-monitor/static-margin",
  perfStall:        "/sim/gui/dialogs/performance-monitor/stall",
  perfSpin:         "/sim/gui/dialogs/performance-monitor/spin",
  mach:             "/velocities/mach",
  speedV:           "/velocities/vertical-speed-fps",
  speedAir:         "/velocities/airspeed-kt",
  alpha:            "/orientation/alpha-deg",
  G:                "/sim/ja37/accelerations/pilot-G",
  p:                "/fdm/jsbsim/velocities/p-aero-rad_sec",
  psiDot:           "/fdm/jsbsim/velocities/psidot-rad_sec",
  turnRad:          "/fdm/jsbsim/systems/flight/turning-radius-nm",
  speedD:           "/fdm/jsbsim/velocities/v-down-fps",
  windDir:          "/environment/wind-from-heading-deg",
  windKt:           "/environment/wind-speed-kt",
  temp:             "/environment/temperature-degc",
  alt:              "/position/altitude-ft",
  inhg:             "/environment/pressure-inhg",
  slug:             "/environment/density-slugft3",
  lat:              "/position/latitude-deg",
  lon:              "/position/longitude-deg",
  altAgl:           "/position/altitude-agl-ft",
  wow0:             "/gear/gear[0]/wow",
  wow1:             "/gear/gear[1]/wow",
  wow2:             "/gear/gear[2]/wow",
  excess:           "fdm/jsbsim/systems/flight/excess-thrust-lb",
  ld:               "fdm/jsbsim/systems/flight/lift-drag-ratio",
  tw:               "fdm/jsbsim/systems/flight/thrust-weight-ratio",
  lw:               "fdm/jsbsim/systems/flight/lift-weight-ratio",
  td:               "fdm/jsbsim/systems/flight/thrust-drag-ratio",
  rp:               "fdm/jsbsim/metrics/aero-rp-x-in",
  rpShift:          "fdm/jsbsim/metrics/aero-rp-shift-mac",
  cg:               "fdm/jsbsim/inertia/cg-x-in",
  stall:            "fdm/jsbsim/aero/stall-hyst-norm",
  spin:             "fdm/jsbsim/aero/spin-norm",
};
foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}

#
# calculate distance between two position in meter.
# pos is a hash with lat and lon (e.g. { lat : lattitude, lon : longitude })
#
var calcDistance = func(pos1, pos2) {
  var dlat = pos2.lat - pos1.lat;
  var dlon = pos2.lon - pos1.lon;

  var dlat_m = dlat * 111120;
  var dlon_m = dlon * math.cos(pos1.lat / 180 * math.pi) * 111120;
  var dist_m = math.sqrt(dlat_m * dlat_m + dlon_m * dlon_m);
  return dist_m;
}


#
# MonitorBase
# Base class for performance monitors
# You can make a monitor class derived from this
# for some unused methods. All methods are called
# from PerformanceMonitor class.
#
var MonitorBase = {};
MonitorBase.reinit = func() {} # called when /sim/signals/reinit is set
MonitorBase.start = func() {}  # 
MonitorBase.update = func() {}
MonitorBase.properties = func() { return []; }

#
# Fuel Efficiency Monitor
# Shows nm/gal, estimate remaining range, remaining flight time, and total range
#
var FuelEfficiency = {};
FuelEfficiency.new = func(interval) {
  obj = { parents : [FuelEfficiency, MonitorBase ] };
  obj.speedNode = input.speedG;
  obj.engineRunningNode = input.running;
  obj.interval = interval;
  obj.fuelFlow = 0;
  obj.fuelEfficiency = 0;
  obj.range = 0;
  obj.pos = AircraftPosition.new();
  obj.posOrigin = obj.pos.get();

  return obj;
}

#
# properties: returns properties that are used in MonitorDialog
# this method is called from PerformanceMonitor
# properties are given in Hash object that contains property name,
# title(name) on the dialog, format string, unit string, and alignment.
# Properties are stored in /sim/gui/dialogs/performance-monitor/*
#
FuelEfficiency.properties = func() {
  return [
    { property : "efficiency", name : "Fuel Efficiency",       format : "%1.4f", unit : "nm/gal", halign : "right" },
   # { property : "range",      name : "Estinate Remain Dist.", format : "%05d",  unit : "nm",     halign : "right" },
   # { property : "time",       name : "Estimate Remain Time",  format : "%8s",   unit : "time",   halign : "right" },
   # { property : "total-range",name : "Estimate Cruise Range", format : "%05d",  unit : "nm",     halign : "right" },
  ];
}

FuelEfficiency.reinit = func()
{
  me.range = 0;
  me.posOrigin = me.pos.get();
  me.fuelFlow = 0;
  me.fuelEfficiency = 0;
}

FuelEfficiency.update = func {
  me.updateFuelEfficiency();
  me.calcTotalFuel();
  #me.estimateCruiseRange();
  #me.estimateCruiseTime();
  #me.estimateTotalRange();
}

#
# calculate fuel efficiency (nm/us-gal)
#
FuelEfficiency.updateFuelEfficiency = func {
  var fuelFlow = 0;
  var groundSpeed = input.speedG.getValue();
  var engineRunning = input.running.getValue();
  if (engineRunning == nil) {
    engineRunning = 0;
  } else {
    foreach(var engine; props.globals.getNode("/engines").getChildren("engine")) {
      if (engine.getNode("running").getValue() == 1) {
          fuelFlow += me.getFuelFlow(engine);
      }
    }
  }
  me.fuelFlow = fuelFlow;
  me.fuelEfficiency = (engineRunning * fuelFlow == 0) ? 0 : (groundSpeed / fuelFlow);
  input.perfEff.setValue(me.fuelEfficiency);
}

#
# getFuelFlow : calculates fuel flow in gph
# This method is usable for both JSBSim and Yasim
#
FuelEfficiency.getFuelFlow = func(engine) {
  var flowNode = engine.getNode("fuel-flow-gph");
  var flow = 0;
  if (flowNode != nil)
    flow = flowNode.getValue();
  if (flow == 0 or flowNode == nil) {
    flowNode = engine.getNode("fuel-flow_pph");
    if (flowNode != nil)
      flow = flowNode.getValue() / 5.92;
    else
      flow = 0;
  }
  return flow;
}

#
# calcTotalFuel : calculate total fuel (us-gal)
#
FuelEfficiency.calcTotalFuel = func {
  var totalFuel = 0;
  foreach (var tank; input.fuel.getChildren("tank")) {
    var fuelLevelNode = tank.getNode("level-lb");
    if (fuelLevelNode == nil) {
      fuelLevelNode = tank.getNode("level-lbs");
    }
    if (fuelLevelNode != nil) {
      totalFuel += fuelLevelNode.getValue() / 5.92;
    }
  }
  setprop("/sim/gui/dialogs/performance-monitor/fuel-gal", totalFuel);
  me.totalFuel = totalFuel;
}

# 
# estimateTotalRange : Calculates total range in nm
# total range = distance so far + estimate cruise range
# distance so far is calculated as distance between 
# the origin airport and the current position
# 
FuelEfficiency.estimateTotalRange = func {
  var curPos = me.pos.get();
  var distance_so_far = calcDistance(me.posOrigin, me.pos) / 1000 * 0.5399568 ;
  var total_range = me.range + distance_so_far;
  input.perfRangeTotal.setValue(total_range);
}

#
# estimateCruiseRange : calculates remaining distance in nm
#
FuelEfficiency.estimateCruiseRange = func {
  me.range = me.fuelEfficiency * me.totalFuel;
  input.perfRange.setValue(me.range);
  return me.range;
}

#
# estimateCruiseTime: calculates remaining flight time
#
FuelEfficiency.estimateCruiseTime = func {
  var time = 0;
  if (me.totalFuel > 0) {
    time = me.totalFuel / me.fuelFlow * 60;
  }
  var hour = int(time / 60);
  var min = int(math.mod(time, 60));
  var sec = int(math.mod(time * 60, 60));
  input.perfTime.setValue(sprintf("%02d:%02d:%02d", hour, min, sec));
  return 
}

#
# AircraftPosition
# provides aircraft position info by latitude, longitude, and AGL.
#
var AircraftPosition = {};
AircraftPosition.new = func() {
  var obj = { parents : [AircraftPosition] };
  obj.lonNode = input.lon;
  obj.latNode = input.lat;
  obj.altNode = input.altAgl;
  return obj;
}

AircraftPosition.update = func() {
  me.lon = me.lonNode.getValue();
  me.lat = me.latNode.getValue();
  me.alt = me.altNode.getValue();
}

#
# get : public interface for acquiring position in Hash.
# you can access each value in Hash using:
#  var pos = AircraftPosition.new();
#  var curPos = pos.get();
#  var lat = curPos.lat;
#  var lon = curPos.lon;
#  var alt = curPos.alt;
#
AircraftPosition.get = func() {
  me.update();
  return {lat : me.lat, lon : me.lon, alt : me.alt };
}

#
# TakeoffDistance : Measures Takeoff Distance (between PosV0 and PosV2)
#
var TakeoffDistance = {};
TakeoffDistance.new = func() {
  var obj = { parents : [TakeoffDistance, MonitorBase] };
  obj.startPosition = {lat : 0.0, lon : 0.0, alt : 0.0};
  obj.endPosition = {lat : 0.0, lon : 0.0, alt : 0.0};
  obj.position = AircraftPosition.new();
  obj.isRunning = 0;
  return obj;
}

TakeoffDistance.properties = func() {
  return [{ property : "to-dist-ft",    name : "Takeoff distance",      format : "%4.1f", unit : "ft",     halign : "right", red: 0.0, green: 1.0, blue: 0.0 },
          { property : "to-dist-m",    name : "Takeoff distance",      format : "%4.1f", unit : "m",     halign : "right", red: 0.0, green: 1.0, blue: 0.0 }]
}

TakeoffDistance.reinit = func()
{
  #me.startPosition = me.position.get();
  #me.endPosition = me.position.get();
  me.isRunning = 0;
  me.startPosition = {lat : 0.0, lon : 0.0, alt : 0.0};
  me.endPosition = {lat : 0.0, lon : 0.0, alt : 0.0};
  me.start();
}

TakeoffDistance.calcDistance = func() {
  var dist_m = calcDistance(me.startPosition, me.endPosition);
  var dist_ft = dist_m * 3.2808399;
  input.perfDistFt.setValue(dist_ft);
  input.perfDistM.setValue(dist_m);
}

TakeoffDistance.update = func() {
  if (me.isRunning == 0) {
    return;
  }
  me.curPos = me.position.get();
  me.endPosition = me.position.get();
  me.calcDistance();
  if (input.wow0.getValue() == 0 and input.wow1.getValue() == 0 and input.wow2.getValue() == 0) {
    me.isRunning = 0;
  }
}

TakeoffDistance.start = func() {
  if (me.isRunning == 0) {
    me.startPosition = me.position.get();
    screen.log.write("start measuring takeoff distance");
    me.isRunning = 1;
    me.update();
  }
}

var LandingDistance = {};
LandingDistance.new = func() {
  var obj = { parents : [ LandingDistance, MonitorBase ]};
  obj.position = AircraftPosition.new();
  obj.startPos = {};
  obj.endPos = {};
  obj.isAvailable = 0;
  me.isRunning = 0;
  return obj;
}

LandingDistance.properties = func() {
  return [{property : "land-dist-ft", name : "Landing distance", format : "%4.1f", unit : "ft", halign : "right", red: 0.0, green: 1.0, blue: 0.0},
          {property : "land-dist-m", name : "Landing distance", format : "%4.1f", unit : "m", halign : "right", red: 0.0, green: 1.0, blue: 0.0}];
}

LandingDistance.reinit = func() {
  me.isAvailable = 0;
  me.isRunning = 0;
  input.perfDistLandFt.setValue(0);
  input.perfDistLandM.setValue(0);
}

LandingDistance.activate = func() {
  if (me.isAvailable == 0) {
    return;
  }
  me.startPos = me.position.get();
  me.isRunning = 1;
}

LandingDistance.update = func() {
  if (me.isRunning == 1) {
    me.autoland();
    return;
  }
  var pos = me.position.get();
  if (pos.alt > 400 and me.isAvailable == 0) {
    me.isAvailable = 1;
    screen.log.write("Landing Distance Monitor is available");
  }
  if ((input.wow0.getValue() == 1 or input.wow1.getValue() == 1 or input.wow2.getValue() == 1) and me.isAvailable == 1) {
    screen.log.write("Measuring landing distance..");
    me.activate();
    return;
  }
}

LandingDistance.autoland = func() {
  var speed = input.speedG.getValue();
  if (speed < 0.1) {
    screen.log.write("Landed.");
    #setprop("/controls/gear/brake-left", 0.0);
    #setprop("/controls/gear/brake-right", 0.0);
    me.isRunning = 0;
    me.isAvailable = 0;
    return;
  }
  me.endPos = me.position.get();
  var dist_m = calcDistance(me.startPos, me.endPos);
  var dist_ft = dist_m * 3.2808399;
  input.perfDistLandFt.setValue(dist_ft);
  input.perfDistLandM.setValue(dist_m);
  #if (getprop("/gear/gear[1]/compression-norm") > 0.05) {
    # disengage autopilot locks
    #setprop("/autopilot/locks/altitude", '');
    #setprop("/autopilot/locks/heading", '');
    #setprop("/autopilot/locks/speed", '');
    #setprop("/controls/flight/elevator-pos", 0);
    # auto throttle off
    #setprop("/controls/engines/engine[0]/throttle", 0);
    #setprop("/controls/engines/engine[1]/throttle", 0);
  #}
  #if (getprop("/gear/gear/compression-norm") > 0.05) {
    # auto brake when front nose is on the ground
    #setprop("/controls/gear/brake-left", 0.4);
    #setprop("/controls/gear/brake-right", 0.4);
  #}
}

#
# MiscMonitor
# This shows some useful info during test
#
var MiscMonitor= {};
MiscMonitor.new = func()
{
  var obj = { parents : [ MiscMonitor, MonitorBase ]};
  return obj;
}

MiscMonitor.properties = func() {
  return [
 #   { property : "glideslope", name : "Glide slope",           format : "%3.1f", unit : "%",      halign : "right" },
    { property : "mach",         name : "Mach number",           format : "%1.3f", unit : "M",      halign : "right" },
    { property : "groundspeed",  name : "Ground speed",          format : "%3.1f", unit : "kt",     halign : "right" },
    { property : "TAS",          name : "True air speed",        format : "%3.1f", unit : "kt",     halign : "right" },
    { property : "angleofattack",name : "Angle of attack",       format : "%3.1f", unit : "deg",    halign : "right" },
    { property : "gforce",       name : "Pilot G-force",         format : "%3.1f", unit : "G",      halign : "right" },
    { property : "climb-rate",   name : "Rate of climb",         format : "%4.1f", unit : "ft/min", halign : "right", red: 0.75, green: 0.75, blue: 1.0 },
    { property : "roll-rate",    name : "Roll rate",             format : "%3.1f", unit : "deg/s",  halign : "right", red: 0.75, green: 0.75, blue: 1.0 },
    { property : "turn-rate",    name : "Turn rate",             format : "%3.1f", unit : "deg/s",  halign : "right", red: 0.75, green: 0.75, blue: 1.0 },
    { property : "turn-radius",  name : "Turn radius",           format : "%3.1f", unit : "nm",     halign : "right", red: 0.75, green: 0.75, blue: 1.0 },
    { property : "sink-rate",    name : "Sink rate",             format : "%3.1f", unit : "m/s",    halign : "right", red: 0.75, green: 0.75, blue: 1.0 },
    { property : "wind-dir",     name : "Wind direction",        format : "%3.1f", unit : "deg",    halign : "right", red: 0.0, green: 1.0, blue: 0.0 },
    { property : "wind-kt",      name : "Wind speed",            format : "%3.1f", unit : "kt",     halign : "right", red: 0.0, green: 1.0, blue: 0.0 },
    { property : "temp",         name : "Ambient temperature",   format : "%3.1f", unit : "deg C",  halign : "right", red: 0.0, green: 1.0, blue: 0.0 },
    { property : "alt",          name : "Altitude above sealvl", format : "%3.1f", unit : "ft",     halign : "right", red: 0.0, green: 1.0, blue: 0.0 },
    { property : "inhg",         name : "Static pressure",       format : "%3.2f", unit : "inhg",   halign : "right", red: 0.0, green: 1.0, blue: 0.0 },
    { property : "density",      name : "Density",               format : "%1.4f", unit : "slugs/ft3",halign : "right", red: 0.0, green: 1.0, blue: 0.0 },
  ]
}

MiscMonitor.update = func()
{
  #  setprop("/sim/gui/dialogs/performance-monitor/glideslope", getprop("/velocities/glideslope")*100);
  input.perfMach.setValue(input.mach.getValue());
  input.perfClimb.setValue(input.speedV.getValue()*60);
  input.perfSpeedG.setValue(input.speedG.getValue());
  input.perfTAS.setValue(input.speedAir.getValue());
  input.perfAlpha.setValue(input.alpha.getValue());
  input.perfG.setValue(input.G.getValue());
  input.perfRoll.setValue(input.p.getValue()*57.296);
  input.perfTurnRate.setValue(input.psiDot.getValue()*57.296);
  input.perfTurnRad.setValue(input.turnRad.getValue());
  input.perfSink.setValue(input.speedD.getValue()* 0.3048);
  input.perfWindDir.setValue(input.windDir.getValue());
  input.perfWindKt.setValue(input.windKt.getValue());
  input.perfTemp.setValue(input.temp.getValue());
  input.perfAlt.setValue(input.alt.getValue());
  input.perfInhg.setValue(input.inhg.getValue());
  input.perfRho.setValue(input.slug.getValue());
}

MiscMonitor.reinit = func() {

}

#
# MiscMonitor
# This shows some useful info during test
#
var AeroMonitor= {};
AeroMonitor.new = func()
{
  var obj = { parents : [ AeroMonitor, MonitorBase ]};
  return obj;
}

AeroMonitor.properties = func() {
  return [
    { property : "ratio-lift-drag",     name : "Lift/Drag Ratio",     format : "%3.2f", unit : "",      halign : "right", red: 1.0, green: 0.65, blue: 0.65 },
    { property : "ratio-lift-weight",   name : "Lift/Weight Ratio",   format : "%3.2f", unit : "",      halign : "right", red: 1.0, green: 0.65, blue: 0.65 },
    { property : "ratio-thrust-weight", name : "Thrust/weight Ratio", format : "%3.2f", unit : "",      halign : "right", red: 1.0, green: 0.65, blue: 0.65 },
    { property : "ratio-thrust-drag",   name : "Thrust/Drag Ratio",   format : "%3.2f", unit : "",      halign : "right", red: 1.0, green: 0.65, blue: 0.65 },
    { property : "excess-thrust",       name : "Excess Thrust",       format : "%5d",   unit : "lbf",   halign : "right", red: 1.0, green: 0.65, blue: 0.65 },
    { property : "static-margin",       name : "Static Margin",       format : "%1.2f", unit : "meter", halign : "right", red: 1.0, green: 0.65, blue: 0.65 },
    { property : "stall",               name : "Stall",               format : "%s",    unit : "",      halign : "right", red: 1.0, green: 0.65, blue: 0.65 },
    { property : "spin",                name : "Spin",                format : "%s",    unit : "",      halign : "right", red: 1.0, green: 0.65, blue: 0.65 },
  ]
}

AeroMonitor.update = func()
{
  input.perfExcess.setValue(input.excess.getValue());
  input.perfLd.setValue(input.ld.getValue());
  input.perfTw.setValue(input.tw.getValue());
  input.perfLw.setValue(input.lw.getValue());
  input.perfTd.setValue(input.td.getValue());
  input.perfMargin.setValue((input.rp.getValue()+input.rpShift.getValue()*291.338-input.cg.getValue())*0.0254);

  var stall = input.stall.getValue();
  var stallText = stall == 1?"True":"False";
  input.perfStall.setValue(stallText);

  var spin = input.spin.getValue();
  var spinText = spin == 1?"True":"False";
  input.perfSpin.setValue(spinText);
}

AeroMonitor.reinit = func() {

}

var efficiency = nil;
var takeoffDist = nil;
var landingDist = nil;
var miscMonitor = nil;

#
# PerformanceMonitor
# A framework for monitoring aircraft performance
#
var PerformanceMonitor = { _instance : nil };

#
# The singleton Instance for PerformanceMonitor
# You can call PerformanceMonitor.instance() to 
# obtain the only instance for this class.
#
PerformanceMonitor.instance = func()
{
  if (PerformanceMonitor._instance == nil) {
    PerformanceMonitor._instance = { parents : [ PerformanceMonitor ] };
    PerformanceMonitor._instance.monitors = [];
  }
  return PerformanceMonitor._instance;
}

#
# register: for registering a new monitor instance.
# this class will take care of monitoring and showing properties
# or calculated values on the dialog by regisering a monitor instance.
#
PerformanceMonitor.register = func(monitor)
{
  append(me.monitors, monitor);
  foreach (var property; monitor.properties()) {
    MonitorDialog.instance().addProperty(property);
  }
}

#
# update: calls update method of each monitor
#   this method is called 10 times a second.
#
PerformanceMonitor.update = func() {
  foreach (var monitor; me.monitors) {
    monitor.update();
  } 
  settimer(func { PerformanceMonitor.instance().update(); }, 0.1);
}

#
# reinit : calls reinit method of each monitor
#   when /sim/signals/reinit is set
#
PerformanceMonitor.reinit = func() {
  foreach (var monitor; me.monitors) {
    monitor.reinit();
  }
}

#
# start: calls start method of each monitor
#   when Ctrl-Shift-M is pressed.
#
PerformanceMonitor.start = func() {
  foreach (var monitor; me.monitors) {
    monitor.start();
  }
  MonitorDialog.instance().show();
  me.update();
}

#
# initialize: creates and registers instances of monitor classes
#
var initialize = func() {
  #var keyHandler = KeyHandler.new();
  var monitor = PerformanceMonitor.instance();
  monitor.register(TakeoffDistance.new());
  monitor.register(LandingDistance.new());
  monitor.register(MiscMonitor.new());
  monitor.register(FuelEfficiency.new(1));
  monitor.register(AeroMonitor.new());
  # Ctrl-Shift-M to activate Performance Monitor
  #keyHandler.add(13, KeyHandler.CTRL + KeyHandler.SHIFT, func { PerformanceMonitor.instance().start(); });
  # Ctrl-Shift-C to reinit Performance Monitor
  #keyHandler.add(3, KeyHandler.CTRL + KeyHandler.SHIFT, func { PerformanceMonitor.instance().reinit(); });
  #screen.log.write("Performance Monitor is available.");
  #screen.log.write("Press Ctrl-Shift-M to activate.");
}

setlistener("/sim/signals/fdm-initialized", func { settimer(initialize, 1); }, 0, 0);
setlistener("/sim/signals/reinit", func { PerformanceMonitor.instance().reinit(); }, 0, 0);