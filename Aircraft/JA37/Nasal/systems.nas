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
    { property : "rpm",          name : "RPM",                   format : "%5.1f", unit : "r/min",  halign : "right" },
    { property : "temp",         name : "Cockpit temperature",   format : "%2.1f", unit : "dec C",  halign : "right" },
    { property : "outlet",       name : "Exhaust gas temp.",     format : "%3.1f", unit : "deg C",  halign : "right" },
    { property : "fuelT",        name : "Fuel temperature",      format : "%3.1f", unit : "deg C",  halign : "right" },
    { property : "oxygen",       name : "Oxygen pressure (mask) ",format : "%1.4f", unit : "psi",    halign : "right" },
    { property : "psi1",         name : "Hydraulics 1",          format : "%4.1f", unit : "psi",    halign : "right" },
    { property : "psi2",         name : "Hydraulics 2",          format : "%4.1f", unit : "psi",    halign : "right" },
    { property : "psiR",         name : "Hydraulics Reserve",    format : "%4.1f", unit : "psi",    halign : "right" },
    { property : "oil",          name : "Oil pressure",          format : "%5.1f", unit : "psi",    halign : "right" },
    { property : "flaps",        name : "Flaps",                 format : "%2.1f", unit : "deg",    halign : "right" },    

    { property : "AC-major",     name : "Main AC",               format : "%2.1f", unit : "volt",   halign : "right" },
    { property : "AC-minor",     name : "Instrument AC",         format : "%2.1f", unit : "volt",   halign : "right" },
    { property : "DC",           name : "Main DC",               format : "%2.1f", unit : "volt",   halign : "right" },
    { property : "Battery",      name : "Battery",               format : "%2.1f", unit : "volt",   halign : "right" },
    { property : "Battery-charge",name : "Battery charge",       format : "%3d",   unit : "%",      halign : "right" },
    { property : "fuel-ratio",   name : "Fuel quantity",         format : "%3d",   unit : "%",      halign : "right" },
  ]
}

MiscMonitor.update = func()
{
  setprop("/sim/gui/dialogs/systems-monitor/rpm", getprop("fdm/jsbsim/propulsion/engine/rpm_r-min"));
  setprop("/sim/gui/dialogs/systems-monitor/temp", getprop("environment/aircraft-effects/temperature-inside-degC"));
  setprop("/sim/gui/dialogs/systems-monitor/outlet", (getprop("engines/engine/egt-degf") -32 )/1.8 );#getprop("fdm/jsbsim/propulsion/engine/outlet-temperature-degc"));
  setprop("/sim/gui/dialogs/systems-monitor/psi1", getprop("fdm/jsbsim/systems/hydraulics/system1/main/psi"));
  setprop("/sim/gui/dialogs/systems-monitor/psi2", getprop("fdm/jsbsim/systems/hydraulics/system2/main/psi"));
  setprop("/sim/gui/dialogs/systems-monitor/psiR", getprop("fdm/jsbsim/systems/hydraulics/system2/reserve/psi"));
  setprop("/sim/gui/dialogs/systems-monitor/flaps", getprop("fdm/jsbsim/fcs/flap-pos-deg"));
  setprop("/sim/gui/dialogs/systems-monitor/oil", getprop("engines/engine/oil-pressure-psi"));
  var temp = nil;
  if (getprop("sim/ja37/supported/fuel-temp") == 1) {
    temp = getprop("consumables/fuel/tank[0]/temperature_degC");
  } else {
    temp = 15;
  }
  if (temp == nil) {
    temp = 15;
  }
  setprop("/sim/gui/dialogs/systems-monitor/fuelT", temp);

  setprop("/sim/gui/dialogs/systems-monitor/Battery", getprop("fdm/jsbsim/systems/electrical/battery-producing-dc"));
  setprop("/sim/gui/dialogs/systems-monitor/AC-minor", getprop("systems/electrical/outputs/ac-instr-voltage"));
  setprop("/sim/gui/dialogs/systems-monitor/DC", getprop("systems/electrical/outputs/dc-voltage"));
  setprop("/sim/gui/dialogs/systems-monitor/AC-major", getprop("systems/electrical/outputs/ac-main-voltage"));
  setprop("/sim/gui/dialogs/systems-monitor/Battery-charge", getprop("fdm/jsbsim/systems/electrical/battery-charge-norm")*100);
  setprop("/sim/gui/dialogs/systems-monitor/oxygen", getprop("fdm/jsbsim/systems/flight/oxygen-pressure-kPa")*0.0098692);
  setprop("/sim/gui/dialogs/systems-monitor/fuel-ratio", getprop("/instrumentation/fuel/ratio")*100);
}

MiscMonitor.reinit = func() {

}


var miscMonitor = nil;

#
# PerformanceMonitor
# A framework for monitoring aircraft performance
#
var SystemsMonitor = { _instance : nil };

#
# The singleton Instance for PerformanceMonitor
# You can call PerformanceMonitor.instance() to 
# obtain the only instance for this class.
#
SystemsMonitor.instance = func()
{
  if (SystemsMonitor._instance == nil) {
    SystemsMonitor._instance = { parents : [ SystemsMonitor ] };
    SystemsMonitor._instance.monitors = [];
  }
  return SystemsMonitor._instance;
}

#
# register: for registering a new monitor instance.
# this class will take care of monitoring and showing properties
# or calculated values on the dialog by regisering a monitor instance.
#
SystemsMonitor.register = func(monitor)
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
SystemsMonitor.update = func() {
  foreach (var monitor; me.monitors) {
    monitor.update();
  } 
  settimer(func { SystemsMonitor.instance().update(); }, 0.1);
}

#
# reinit : calls reinit method of each monitor
#   when /sim/signals/reinit is set
#
SystemsMonitor.reinit = func() {
  foreach (var monitor; me.monitors) {
    monitor.reinit();
  }
}

#
# start: calls start method of each monitor
#   when Ctrl-Shift-M is pressed.
#
SystemsMonitor.start = func() {
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
  setprop("/sim/gui/dialogs/systems-monitor/init", 1);
  #var keyHandler = KeyHandler.new();
  var monitor = SystemsMonitor.instance();
  #monitor.register(TakeoffDistance.new());
  #monitor.register(LandingDistance.new());
  monitor.register(MiscMonitor.new());
  #monitor.register(FuelEfficiency.new(1));
  #monitor.register(AeroMonitor.new());
  # Ctrl-Shift-M to activate Performance Monitor
  #keyHandler.add(13, KeyHandler.CTRL + KeyHandler.SHIFT, func { PerformanceMonitor.instance().start(); });
  # Ctrl-Shift-C to reinit Performance Monitor
  #keyHandler.add(3, KeyHandler.CTRL + KeyHandler.SHIFT, func { PerformanceMonitor.instance().reinit(); });
  #screen.log.write("Performance Monitor is available.");
  #screen.log.write("Press Ctrl-Shift-M to activate.");
}

setlistener("/sim/signals/fdm-initialized", func { settimer(initialize, 1); }, 0, 0);
setlistener("/sim/signals/reinit", func { SystemsMonitor.instance().reinit(); }, 0, 0);