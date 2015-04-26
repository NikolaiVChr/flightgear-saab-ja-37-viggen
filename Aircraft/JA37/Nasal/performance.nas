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
  obj.speedNode = props.globals.getNode("velocities/groundspeed-kt");
  obj.engineRunningNode = props.globals.getNode("engines/engine/running");
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
  var groundSpeed = getprop("/velocities/groundspeed-kt");
  var engineRunning = getprop("/engines/engine/running");
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
  setprop("/sim/gui/dialogs/performance-monitor/efficiency", me.fuelEfficiency);
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
  foreach (var tank; props.globals.getNode("/consumables/fuel").getChildren("tank")) {
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
  setprop("/sim/gui/dialogs/performance-monitor/total-range", total_range);
}

#
# estimateCruiseRange : calculates remaining distance in nm
#
FuelEfficiency.estimateCruiseRange = func {
  me.range = me.fuelEfficiency * me.totalFuel;
  setprop("/sim/gui/dialogs/performance-monitor/range", me.range);
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
  setprop("/sim/gui/dialogs/performance-monitor/time", sprintf("%02d:%02d:%02d", hour, min, sec));
  return 
}

#
# AircraftPosition
# provides aircraft position info by latitude, longitude, and AGL.
#
var AircraftPosition = {};
AircraftPosition.new = func() {
  var obj = { parents : [AircraftPosition] };
  obj.lonNode = props.globals.getNode("/position/longitude-deg", 1);
  obj.latNode = props.globals.getNode("/position/latitude-deg", 1);
  obj.altNode = props.globals.getNode( "/position/altitude-agl-ft", 1 );
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
  setprop("/sim/gui/dialogs/performance-monitor/to-dist-ft", dist_ft);
  setprop("/sim/gui/dialogs/performance-monitor/to-dist-m", dist_m);
}

TakeoffDistance.update = func() {
  if (me.isRunning == 0) {
    return;
  }
  me.curPos = me.position.get();
  me.endPosition = me.position.get();
  me.calcDistance();
  if (getprop("/gear/gear/wow") == 0 and getprop("/gear/gear[1]/wow") == 0 and getprop("/gear/gear[2]/wow") == 0) {
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
  setprop("/sim/gui/dialogs/performance-monitor/land-dist-ft", 0);
  setprop("/sim/gui/dialogs/performance-monitor/land-dist-m", 0);
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
  if ((getprop("/gear/gear/wow") == 1 or getprop("/gear/gear[1]/wow") == 1 or getprop("/gear/gear[2]/wow") == 1) and me.isAvailable == 1) {
    screen.log.write("Measuring landing distance..");
    me.activate();
    return;
  }
}

LandingDistance.autoland = func() {
  var speed = getprop("/velocities/groundspeed-kt");
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
  setprop("/sim/gui/dialogs/performance-monitor/land-dist-ft", dist_ft);
  setprop("/sim/gui/dialogs/performance-monitor/land-dist-m", dist_m);
  if (getprop("/gear/gear[1]/compression-norm") > 0.05) {
    # disengage autopilot locks
    #setprop("/autopilot/locks/altitude", '');
    #setprop("/autopilot/locks/heading", '');
    #setprop("/autopilot/locks/speed", '');
    #setprop("/controls/flight/elevator-pos", 0);
    # auto throttle off
    #setprop("/controls/engines/engine[0]/throttle", 0);
    #setprop("/controls/engines/engine[1]/throttle", 0);
  }
  if (getprop("/gear/gear/compression-norm") > 0.05) {
    # auto brake when front nose is on the ground
    #setprop("/controls/gear/brake-left", 0.4);
    #setprop("/controls/gear/brake-right", 0.4);
  }
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
  setprop("/sim/gui/dialogs/performance-monitor/mach", getprop("/velocities/mach"));
#  setprop("/sim/gui/dialogs/performance-monitor/glideslope", getprop("/velocities/glideslope")*100);
  setprop("/sim/gui/dialogs/performance-monitor/climb-rate", getprop("/velocities/vertical-speed-fps") * 60);
  setprop("/sim/gui/dialogs/performance-monitor/groundspeed", getprop("/velocities/groundspeed-kt"));
  setprop("/sim/gui/dialogs/performance-monitor/TAS", getprop("/velocities/airspeed-kt"));
  setprop("/sim/gui/dialogs/performance-monitor/angleofattack", getprop("/orientation/alpha-deg"));
  setprop("/sim/gui/dialogs/performance-monitor/gforce", getprop("/sim/ja37/accelerations/pilot-G"));
  setprop("/sim/gui/dialogs/performance-monitor/roll-rate", getprop("/fdm/jsbsim/velocities/p-aero-rad_sec")*57.296);
  setprop("/sim/gui/dialogs/performance-monitor/turn-rate", getprop("/fdm/jsbsim/velocities/psidot-rad_sec")*57.296);
  setprop("/sim/gui/dialogs/performance-monitor/turn-radius", getprop("/fdm/jsbsim/systems/flight/turning-radius-nm"));
  setprop("/sim/gui/dialogs/performance-monitor/sink-rate", getprop("/fdm/jsbsim/velocities/v-down-fps") * 0.3048);
  setprop("/sim/gui/dialogs/performance-monitor/wind-dir", getprop("/environment/wind-from-heading-deg"));
  setprop("/sim/gui/dialogs/performance-monitor/wind-kt", getprop("/environment/wind-speed-kt"));
  setprop("/sim/gui/dialogs/performance-monitor/temp", getprop("/environment/temperature-degc"));
  setprop("/sim/gui/dialogs/performance-monitor/alt", getprop("/position/altitude-ft"));
  setprop("/sim/gui/dialogs/performance-monitor/inhg", getprop("/environment/pressure-inhg"));
  setprop("/sim/gui/dialogs/performance-monitor/density", getprop("/environment/density-slugft3"));
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
    { property : "ratio-lift-drag",     name : "Lift/Drag Ratio",     format : "%3.2f", unit : "",    halign : "right", red: 1.0, green: 0.65, blue: 0.65 },
    { property : "ratio-lift-weight",   name : "Lift/Weight Ratio",   format : "%3.2f", unit : "",    halign : "right", red: 1.0, green: 0.65, blue: 0.65 },
    { property : "ratio-thrust-weight", name : "Thrust/weight Ratio", format : "%3.2f", unit : "",    halign : "right", red: 1.0, green: 0.65, blue: 0.65 },
    { property : "ratio-thrust-drag",   name : "Thrust/Drag Ratio",   format : "%3.2f", unit : "",    halign : "right", red: 1.0, green: 0.65, blue: 0.65 },
    { property : "excess-thrust",       name : "Excess Thrust",       format : "%5d",   unit : "lbf", halign : "right", red: 1.0, green: 0.65, blue: 0.65 },
  ]
}

AeroMonitor.update = func()
{
  setprop("/sim/gui/dialogs/performance-monitor/excess-thrust", getprop("fdm/jsbsim/systems/flight/excess-thrust-lb"));
  setprop("/sim/gui/dialogs/performance-monitor/ratio-lift-drag", getprop("fdm/jsbsim/systems/flight/lift-drag-ratio"));
  setprop("/sim/gui/dialogs/performance-monitor/ratio-thrust-weight", getprop("fdm/jsbsim/systems/flight/thrust-weight-ratio"));
  setprop("/sim/gui/dialogs/performance-monitor/ratio-lift-weight", getprop("fdm/jsbsim/systems/flight/lift-weight-ratio"));
  setprop("/sim/gui/dialogs/performance-monitor/ratio-thrust-drag", getprop("fdm/jsbsim/systems/flight/thrust-drag-ratio"));
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