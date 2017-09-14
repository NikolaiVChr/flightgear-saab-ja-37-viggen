
var TRUE  = 1;
var FALSE = 0;

var theInit = setlistener("ja37/supported/initialized", func {
    removelistener(theInit);
    if (getprop("ja37/systems/variant") == 0) {
      callInit();
    }
});

var debugAll = TRUE;

var printDA = func (str) {
    if (debugAll) print (str);
}

var signText = nil;

var callInit = func {
  canvasDAP = canvas.new({
        "name": "DAP",
        "size": [256, 64],
        "view": [256, 64],
        "mipmapping": 1
  });
      
  canvasDAP.addPlacement({"node": "DataCanvas", "texture": "digit.png"});
  canvasDAP.setColorBackground(0.00, 0.00, 0.00, 1.00);

  var root = canvasDAP.createGroup();
  #root.show();
  #root.set("font", getprop("/sim/aircraft-dir")~"/Nasal/DSEG7Classic-Regular.ttf");
  root.set("font", "DSEG/DSEG7/Classic/DSEG7Classic-Regular.ttf");
  signText = root.createChild("text")
        .setText("")
        .setFontSize(50, 1.15)
        .setColor(1,0,0, 1)
        .setAlignment("right-baseline")
        .setTranslation(256, 64);

#  var loop_dap = func {

    #var callsign = props.globals.getNode("/sim/multiplay/callsign").getValue();

    signText.setText("------");

 #   settimer(loop_dap, 0.25);
  #}
  #loop_dap();
  loop_main();
}

#
# /sim/ja37/navigation/dp-mode 0-7
# /sim/ja37/navigation/ispos
# /sim/ja37/navigation/inout
#
#

var MINUS = 1;
var PLUS  = 0;

var OUT   = 1;
var IN    = 0;

var KNOB_LOLA = 0;
var KNOB_TILS = 1;
var KNOB_FUEL = 2;
var KNOB_REG  = 3;
var KNOB_TI   = 4;
var KNOB_DATE = 5;
var KNOB_DATA = 6;

var OUTPUT    = 1;
var INPUT     = 0;

var HOLD      = 1;
var RELEASE   = 0;

var inputDefault = "------";# these 2 should really be spaces, but canvas wont render space.
var charDefault  = "-";

var state = OUTPUT;
var cycle = -1;
var cycleMax = 1;
var input = "------";
var digit = 0;
var error = FALSE;
var display = "      ";

var set237 = func (bool) {
  if (bool) {
    state = 237;
  } else {
    state = OUTPUT;
  }
}

var main = func {
  if (getprop("ja37/systems/variant") != 0) return;
  if (getprop("systems/electrical/outputs/dc-voltage") < 23){
    printDA("DAP: offline");
    return;
  }
  
  printDA("");
  printDA("DAP: main called");
  printDA(" selector "~settingKnob);
  printDA(" sign     "~settingSign);
  printDA(" in/out   "~settingDir);
  printDA(" cycle    "~cycle);
  printDA(" cycleMax "~cycleMax);
  printDA(" state    "~state);
  printDA(" digit    "~digit);
  printDA(" input    *"~input~"*");
  printDA(" error    "~error);

  if (error == TRUE) {
    if (isStateChanged()) {
      error = FALSE;
    } else {
      return;
    }
  }
  if (settingKnob != settingPrevKnob) {

  }

  if (state == 237) {
    if(keyPressed == -1 and route.Polygon.polyEdit) {
      # delete route plan
      route.Polygon.deletePlan();
    }
  } elsif (settingDir == OUT) {
    if (ok==HOLD and cycle != -1) {
      cycle += 1;
      if (cycle > cycleMax) {
        cycle = 0;
      }
    }
    if ((settingKnob == KNOB_DATE)
      or (settingKnob == KNOB_LOLA)) {
      if (cycle == -1) {
        cycle = 0;
      }
    } else {
      cycle = -1;
    }
  } else {
    if (settingKnob == KNOB_DATE) {
      if (isStateChanged()) {
        cycle = 0;
        cycleMax = 1;
        digit = 0;
        input = inputDefault;
      } else {
        if (ok==HOLD and digit == 6) {
          if (input == "999999") {
            resetDate();
            digit = 0;
            input = inputDefault;
            cycle = 0;
          } elsif (cycle==0) {
            # set date
            printDA("set date "~input);
            if (setDate()) {
              cycleDisp();
              input = inputDefault;
              digit = 0;
            } else {
              error = TRUE;
              digit = 0;
              input = inputDefault;
            }
          } else {
            # set time
            printDA("set time "~input);
            if (setTime()) {
              cycleDisp();
              input = inputDefault;
              digit = 0;
            } else {
              error = TRUE;
              digit = 0;
              input = inputDefault;
            }
          }
        } elsif (keyPressed == -1) {
          # reset
            input = "";
            digit = 0;
        } elsif (cycle == 0) {
          # date input
          inputFull();
        } elsif (cycle == 1) {
          # date input
          inputFull();
        }
      }
    }
  }
  disp();
  printDA(" display  *"~display~"*");
  keyPressed = nil;
  settingPrevKnob = settingKnob;
  settingPrevSign = settingSign;
  settingPrevDir  = settingDir;
};

var cycleDisp = func {
  cycle += 1;
  if (cycle > cycleMax) {
    cycle = 0;
  }
}

var setTime = func {
  var hour   = num(substr(input,0,2));
  var minute = num(substr(input,2,2));
  var second = num(substr(input,4,2));
  if (hour>23 or minute > 60 or second > 60) {
    return FALSE;
  }
  var old_dt = getprop("/sim/time/gmt");
  old_dt = substr(old_dt, 0, 11);
  var new_dt = sprintf("%s%02d:%02d:%02d", old_dt, hour, minute, second);
  printDA(" "~new_dt);
  setprop("/sim/time/gmt", new_dt);
  return TRUE;
}

var setDate = func {
  var year   = num(substr(input,0,2));
  var month = num(substr(input,2,2));
  var day = num(substr(input,4,2));
  if (year < 79) {
    year = year+1900;
  } else {
    year = year+2000;
  }
  if (month>12 or month < 1) {
    return FALSE;
  }
  var maxDay = monthmax[day-1];
  if (day>maxDay or day<1) {
    return FALSE;
  }
  var old_dt = getprop("/sim/time/gmt");
  old_dt = substr(old_dt, 10, 9);
  var new_dt = sprintf("%04d-%02d-%02d%s", year, month, day, old_dt);
  printDA(" "~new_dt);
  setprop("/sim/time/gmt", new_dt);
  return TRUE;
}

var resetDate = func {
  fgcommand("timeofday",props.Node.new({"real":0}));
}

var inputFull = func () {
  if (keyPressed != nil and digit < 6) {
    input = substr(input, 0,digit)~keyPressed~manyChar(charDefault,6-(digit+1));
    digit += 1;
  }
}

var manyChar = func (char, count) {
  var result = "";
  for (var i = 0; i<count;i+=1){
    result = result~char;
  }
  return result;
}

var isStateChanged = func {
  return settingPrevKnob != settingKnob or settingPrevDir != settingDir;
}

var disp = func {
  display = "";

  if (error == TRUE) {
    display = " Error";
  } elsif (state == 237) {
    display = "   237";
  } elsif (settingDir == OUT) {
    if (settingKnob == KNOB_DATE) {
      if (cycle == -1) {
        cycle = 0;
      }
      if (ok == HOLD) {
        if (cycle == 0) {
          display = "----dA";
        } else {
          display = "----CL";
        }
      } else {
        var dtv = getprop("/sim/time/gmt");
        var year = substr(dtv,2,2);
        var month = substr(dtv,5,2);
        var day = substr(dtv,8,2);
        var hour = substr(dtv,11,2);
        var minute = substr(dtv,14,2);
        var second = substr(dtv,17,2);
        if (cycle == 0) {
          display = sprintf("%s%s%s",year,month,day);
        } else {
          display = sprintf("%s%s%s",hour,minute,second);
        }
      }
    } elsif (settingKnob == KNOB_TILS) {
      if (land.ils != 0) {
        display = sprintf("%05d", int(100*land.ils));
      } else {
        display = "------";
      }
    } elsif (settingKnob == KNOB_LOLA) {
      if (cycle == -1) {
        cycle = 0;
      }
      if (ok == HOLD) {
        if (cycle == 0) {
          display = "----LO";
        } else {
          display = "----LA";
        }
      } else {
        if (cycle == 0) {
          var lo = getprop("position/longitude-deg");
          var lon = ja37.convertDegreeToDispStringLon(lo);#not sure what to do when deg has 3 digit and a minus sign. No room on display.
          display = sprintf("%s",lon);
        } else {
          var la = getprop("position/latitude-deg");
          var lat = ja37.convertDegreeToDispStringLat(la);
          display = sprintf("%s",lat);
        }
      }
    }
  } else {
    if (settingKnob == KNOB_DATE) {
      if (digit == 0) {
        if (cycle == 0) {
          display = "----dA";
        } else {
          display = "----CL";
        }
      } else {
        display = input;
      }
    }
  }

  #printDA(" display  *"~display~"*");
  signText.setText(display);
};

var loop_main = func {
  if (getprop("ja37/systems/variant") != 0) return;
  disp();
  settimer(loop_main,1);
}



var monthmax = [31,28,31,30,31,30,31,31,30,31,30,31];
#var new_dt=sprintf("%04d-%02d-%02dT%02d:%02d:%02d",getprop("/sim/time/demand-year"),month,getprop("/sim/time/demand-day"),hour,minute,second*1);
#setprop("/sim/time/gmt",new_dt);

# input
#
# REG/STR UD IN
# 19xxxx  training floor in meters
#
# TI UD IN
# xxx--P  TI mappoints (square: 100-109) then OK
#  1531LO OK
#  6025LA OK
# 00xxxx enter date 0525 = may 25th
# 004xxx version (utgåva) goes for all points
# 
# TI
# 654321 then click RENSA
#  xxx-yyy clear mappoint xxx to yyy
#
# CL/DAT UD IN
# [----CL]
# hhmmss
# [----dA]
# yymmdd sets date and time (GPS needs it)
# 999999 reset time and date
#
# FPLDATA
# interoperability

# output UD UT
#
# TILS/BANA
# [ILSFREQ]
#
# CL/DAT
# [----CL] when holding OK
# time when letting go
# [----dA] when holding OK
# date when letting go
# repeat
#
# TI
# enter mappoint (UD IN set auto)
# choose UD UT
# use OK to display:
# P/LO/LA
# for LV points 1 yellow, 8 red then black, then P
# 

# normal mode POS UT
#
# takeoff switches to this, so does menu SYST on TI
#
# [nbaaau] n= 0 steer 1 base b=1-5 aaa=dist in km u=km uncertainty

# possave POS IN
#
# show frozen position
# LO/LA shown at holding any button on nav. panel, release shows it. Toggling.

# UD = mission data
# POS= position
# IN = input
# UT = output

var ok          = RELEASE;
var keyPressed  = nil;
var settingKnob = getprop("ja37/navigation/dp-mode");
var settingSign = getprop("ja37/navigation/ispos");
var settingDir  = getprop("ja37/navigation/inout");
var settingPrevKnob = getprop("ja37/navigation/dp-mode");
var settingPrevSign = getprop("ja37/navigation/ispos");
var settingPrevDir  = getprop("ja37/navigation/inout");

var switch = func {
  if (getprop("ja37/systems/variant") != 0) return;
  settingKnob = getprop("ja37/navigation/dp-mode");
  settingSign = getprop("ja37/navigation/ispos");
  settingDir  = getprop("ja37/navigation/inout");
  main();
}

var keyPress = func (key) {
  if (getprop("ja37/systems/variant") != 0) return;
  if (getprop("systems/electrical/outputs/dc-voltage") < 23){
    printDA("DAP: offline");
    return;
  }
  keyPressed = key;
  printDA("DAP: key "~key);
  main();
}

var okPress = func {
  if (getprop("ja37/systems/variant") != 0) return;
  if (getprop("systems/electrical/outputs/dc-voltage") < 23){
    printDA("NAV: offline");
    return;
  }
  ok = HOLD;
  main();
}

var okRelease = func {
  if (getprop("ja37/systems/variant") != 0) return;
  if (getprop("systems/electrical/outputs/dc-voltage") < 23){
    printDA("NAV: offline");
    return;
  }
  ok = RELEASE;
  main();
}

setlistener("ja37/navigation/dp-mode", switch);
setlistener("ja37/navigation/ispos", switch);
setlistener("ja37/navigation/inout", switch);