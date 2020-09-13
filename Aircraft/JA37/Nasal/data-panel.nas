
var TRUE  = 1;
var FALSE = 0;

#var theInit = setlistener("ja37/supported/initialized", func {
#    removelistener(theInit);
#    if (getprop("ja37/systems/variant") == 0) {
#      callInit();
#    }
#});

var debugAll = 0;

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
        .setColor([1,0,0])
        .setAlignment("right-baseline")
        .setTranslation(256, 64);

#  var loop_dap = func {

    #var callsign = props.globals.getNode("/sim/multiplay/callsign").getValue();

    signText.setText("------");
    #printDA("Init DAP");

 #   settimer(loop_dap, 0.25);
  #}
  #loop_dap();
  #settimer(func {loop_main()},0.5);#This way we are sure TI.ti has been initialized.
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

var POS   = 1;
var MSDA  = 0;

var KNOB_LOLA = 0;
var KNOB_TILS = 1;
var KNOB_FUEL = 2;
var KNOB_REG  = 3;
var KNOB_TI   = 4;
var KNOB_DATE = 5;
var KNOB_DATA = 6;#FPLDATA

var OUTPUT    = 1;
var INPUT     = 0;

var HOLD      = 1;
var RELEASE   = 0;

var inputDefault  = "------";# these 3 should really be spaces, but canvas wont render space.
var input3Default = "---";
var input2Default = "--";
var charDefault   = "-";

var state = OUTPUT;
#var ti237_min = 0;
var ti237_max = 0;
var ti237_callback = 0;

var cycle = -1;
var cycleMax = 1;
var input = "------";
var digit = 0;
var error = FALSE;
var display = "      ";
var posOutDisplay = "       ";

var testDisplay = "";
var testMinus = 0;
var testMinusLast = 0;

var LV_lock = TRUE;

var set237 = func (enable, digitsMax, callback) {#longitude might need 6 or 7 digits
  if (enable) {
    state = 237;
    #printf("237:%d", digitsMax);
    #ti237_min = digitsMin;
    ti237_max = digitsMax;
    ti237_callback = callback;
  } else {
    state = OUTPUT;
  }
  error = FALSE;
  cycle = -1;
  cycleMax = 1;
  input = manyChar(charDefault, digitsMax);
  digit = 0;
}

var setError = func {
  error = TRUE;
}

var main = func {
  if (getprop("ja37/systems/variant") != 0 or testDisplay != "") return;
  if (!power.prop.acMainBool.getValue()) {
    printDA("DAP: offline");
    return;
  }
  
  printDA("");
  printDA("DAP: main called");
  printDA(" selector "~settingKnob);
  printDA(" sign     "~settingSign);
  printDA(" in/out   "~settingDir);
  printDA(" pos/msda "~settingPos);
  printDA(" cycle    "~cycle);
  printDA(" cycleMax "~cycleMax);
  printDA(" state    "~state);
  printDA(" digit    "~digit);
  printDA(" input    *"~input~"*");
  printDA(" error    "~error);

  if (error == TRUE) {
    resetSign();
    if (isStateChanged()) {
      error = FALSE;
    } else {
      return;
    }
  }
  TI.ti.displayFTime = FALSE;
  if (settingKnob != settingPrevKnob) {
    resetSign();
  }

  if (state == 237) {

    if (x==HOLD) {
        # clear TI value
        printDA("set 237: clear");
        ti237_callback(nil, settingSign, TI.ti);
        input = inputDefault;
        digit = 0;
        resetSign();
    } elsif (ok==HOLD and digit == ti237_max) {
        # set TI value
        printDA("set 237: "~input);
        ti237_callback(input, settingSign, TI.ti);
        input = inputDefault;
        digit = 0;
        resetSign();
    } elsif (keyPressed == -1) {
      # TODO: not sure
    } elsif (back == HOLD) {
      # reset
        inputBackKey(ti237_max);
    } else {
      # TI input
      inputKey(ti237_max);
    }

  } elsif (settingPos == POS) {
    # POS IN/OUT
      if (settingKnob==KNOB_TI and keyPressed == -1 and route.Polygon.editing != nil) {
        # delete route plan
        route.Polygon.deletePlan();
      }
      
  } elsif (settingDir == OUT) {
    # MSDA/OUT
    if (isStateChanged()) {
      updateCycleMax();
    }
    if (ok==HOLD and cycle != -1) {
      cycleDisp();
    }
    if (settingKnob == KNOB_TI) {
      TI.ti.displayFTime = TRUE;
    }
  } else {
    # MSDA/IN
    if (isStateChanged()) {
      updateCycleMax();
    }
    if (settingKnob == KNOB_TI) {
      # to clear the points type in 654321 and click RENSA that will clear the lock
      # then 013124 typed in means clear from 13 to 124.
      # by twisting knob the lock is in place again.
      #
      # TODO: LOLA should only be 4 digits and LO or LA displayed to the right of those?
      if (isStateChanged()) {
        digit = 0;
        input = inputDefault;
        LV_lock = TRUE;
        resetSign();
        printDA("DAP TI addresses locked.");
      } else {
        if (keyPressed == -1 and digit == 6) {
          if (input == "654321" and settingSign == 1) {
            LV_lock = FALSE; 
            cycle = 0;
            printDA("DAP TI addresses unlocked.");
          }
          input = inputDefault;
          digit = 0;
          resetSign();
        } elsif ((ok==HOLD or l==HOLD or g==HOLD) and digit == 3 and cycle == 0) {
          var address = num(left(input,3));
          if (address != nil and address >= 1 and address < 190 and settingSign == 1) {
            digit = 0;
            input = manyChar(charDefault, 7);
            cycleDisp();
            lv_temp = lv["p"~sprintf("%03d", address)];
            if (lv_temp == nil) {
              var ptype = 0; # LV
              var pcolor = 0;# red
              var radius = 8;# km
              
              if (address >= 1 and address <= 39) {
                radius = 5;
              } elsif (address >= 100 and address <= 109) {
                radius = -1;
                ptype = 1;
                pcolor = 2;
              } elsif (address >= 110 and address <= 178) {
                radius = 15;
              } elsif (address >= 180 and address <= 189) {
                radius = 40;
              } elsif (address == 179) {
                ptype = 3;
                pcolor = 2;
                radius = -1;
              }
              if (l == HOLD and !(address >= 100 and address <= 109)) {
                pcolor = 1;#yellow
              } elsif (g == HOLD and !(address >= 100 and address <= 109)) {
                pcolor = 3;#green
              }
              lv_temp = {address: address, color: pcolor, radius: radius, type: ptype};
            }
            printDA("DAP request for LV/FF point.");
          } elsif (input == "179---" and settingSign == 1) {
            digit = 0;
            input = manyChar(charDefault, 7);
            cycleDisp();
            printDA("DAP request for Bulls-eye..");
          } else {
            error = TRUE;
            digit = 0;
            input = inputDefault;
          }
          resetSign();
        } elsif (ok==HOLD and digit == 6 and cycle == 0) {
          var low = num(substr(input,0,3));
          var high = num(substr(input,3,3));
          printDA("DAP: Request to delete TI address "~low~" to "~high);
          if (LV_lock == FALSE and low <= high and high < 200 and low > 000) {
            digit = 0;
            input = inputDefault;
            if (179 >= low and 179 <= high) {
              setprop("ja37/navigation/bulls-eye-defined", FALSE);
              printDA("DAP: Bulls-eye deleted.");
            }
            foreach(key; keys(lv)) {
              if (lv[key].address >= low and lv[key].address <= high) {
                printDA("DAP: deleting point "~lv[key].address);
                delete(lv,key);
              }
            }
            checkLVSave();
          } else {
            error = TRUE;
            digit = 0;
            input = inputDefault;
          }
          resetSign();
        } elsif (ok==HOLD and digit == 7 and cycle == 1) {
            # set lon
            var sign = settingSign<0?"-":"";
            printDA("set B_E/LV/FF lon "~sign~input);
            var deg = ja37.stringToLon(sign~input);
            if (deg != nil) {
              if (lv_temp.address == 179) {
                setprop("ja37/navigation/bulls-eye-lon", deg);
                printDA("DAP TI bulls-eye longitude edited.");
              } else {
                lv_temp.lon = deg;
                printDA("DAP TI point longitude edited.");
              }
              cycleDisp();
              input = inputDefault;
              digit = 0;              
            } else {
              error = TRUE;
              digit = 0;
              input = inputDefault;
            }
            resetSign();
        } elsif (ok==HOLD and digit == 6 and cycle == 2) {
            # set lat
            var sign = settingSign<0?"-":"";
            printDA("set B_E/FF/LV lat "~sign~input);
            var deg = ja37.stringToLat(sign~input);
            if (deg != nil) {
              if (lv_temp.address == 179) {
                setprop("ja37/navigation/bulls-eye-lat", deg);
                setprop("ja37/navigation/bulls-eye-defined", TRUE);
                printDA("DAP TI bulls-eye latitude edited. Bulls-eye enabled.");
                checkLVSave();
              } else {
                lv_temp.lat = deg;
                lv["p"~sprintf("%03d", lv_temp.address)] = lv_temp;
                printDA("DAP TI point latitude edited. "~(lv_temp.color==0?"Red":(lv_temp.color==1?"Yellow":(lv_temp.color==2?"Tyrk":"Green")))~" point "~sprintf("%03d",lv_temp.address)~" activated at "~ja37.convertDegreeToStringLat(lv_temp.lat)~" "~ja37.convertDegreeToStringLon(lv_temp.lon));
                #debug.dump(lv);
                checkLVSave();
              }
              cycleDisp();
              input = inputDefault;
              digit = 0;
            } else {
              error = TRUE;
              digit = 0;
              input = inputDefault;
            }
            resetSign();
        } elsif (keyPressed == -1) {
          # TODO: not sure
        } elsif (x == HOLD) {
          # clear field
          input = cycle==1?manyChar(charDefault, 7):inputDefault;
          digit = 0;
          resetSign();
        } elsif (cycle == 0) {
          # punkt no. input
          if (back == HOLD) {
            inputBackKey(6);
          } else {
            inputKey(6);
          }
        } elsif (cycle == 1) {
          # lon input
          if (back == HOLD) {
            inputBackKey(7);
          } else {
            inputKey(7);
          }
        } elsif (cycle == 2) {
          # lat input
          if (back == HOLD) {
            inputBackKey(6);
          } else {
            inputKey(6);
          }
        }
      }
    } elsif (settingKnob == KNOB_DATE) {
      if (isStateChanged()) {
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
          # TODO: not sure
        } elsif (x == HOLD) {
          # clear field
            input = "";
            digit = 0;
        } elsif (cycle == 0) {
          # date input
          if (back == HOLD) {
            inputBackKey(6);
          } else {
            inputKey(6);
          }
        } elsif (cycle == 1) {
          # date input
          if (back == HOLD) {
            inputBackKey(6);
          } else {
            inputKey(6);
          }
        }
      }
      resetSign();
    } elsif (settingKnob == KNOB_FUEL) {
      if (isStateChanged()) {
          digit = 0;
          input = input2Default;
          resetSign();
      } else {
        if (ok==HOLD and digit == 2) {
            # set fuel warn
            printDA("set extra fuel warning "~input~"%");
            setprop("ja37/systems/fuel-warning-extra-percent", num(input));
            input = input2Default;
            digit = 0;
            resetSign();
        } elsif (keyPressed == -1) {
          # TODO: not sure
        } elsif (x == HOLD) {
          # clear field
            input = input2Default;
            digit = 0;
            resetSign();
        } else {
          # fuel input
          if (back == HOLD) {
            inputBackKey(2);
          } else {
            inputKey(2);
          }
        }
      }
    } elsif (settingKnob == KNOB_DATA) {
      if (isStateChanged()) {
          digit = 0;
          input = inputDefault;
          resetSign();
      } else {
        var address = num(left(input,2));
        if (ok==HOLD and digit == 6 and address != nil and address==15) {
            # set interoperability
            var io = num(substr(input,3,1));
            printDA("set interoperability "~io~" ");
            if (io == 0 or io == 1) {
              setprop("ja37/hud/units-metric", !io);
            } else {
              error = TRUE;
            }
            input = inputDefault;
            digit = 0;
            resetSign();
        } elsif (ok==HOLD and digit == 6 and address != nil and address==30) {
            # set GPS Installed
            var io = num(substr(input,2,1));
            printDA("set GPS installed "~io~" ");
            if (io == 0 or io == 1) {
              setprop("ja37/navigation/gps-installed", io);
              if (io == 0) {
                FailureMgr._failmgr.logbuf.push("Main CPU: Detection of GPS unit mismatch!\n         Remove physical unit or correct ACDATA.");
                TI.ti.newFails = 1;
              }
            } else {
              error = TRUE;
            }
            input = inputDefault;
            digit = 0;
            resetSign();
        } elsif (ok==HOLD and digit == 6) {
            printDA("set unknown address "~input);
            input = inputDefault;
            digit = 0;
            resetSign();
        } elsif (keyPressed == -1) {
          # TODO: not sure
        } elsif (x == HOLD) {
          # clear field
            input = inputDefault;
            digit = 0;
            resetSign();
        } else {
          # input
          if (back == HOLD) {
            inputBackKey(6);
          } else {
            inputKey(6);
          }
        }
      }
    } elsif (settingKnob == KNOB_REG) {
      if (isStateChanged()) {
          digit = 0;
          input = inputDefault;
          resetSign();
      } else {
        if (ok==HOLD and digit == 6 and num(left(input,2))==0) {
            # set max alpha
            var alpha = num(substr(input,2,2));
            if (alpha == 0) {
              alpha = getprop("fdm/jsbsim/fcs/max-alpha-default-deg");
            }
            printDA("set max alpha "~alpha~" deg");
            setprop("fdm/jsbsim/fcs/max-alpha-deg", alpha);
            input = inputDefault;
            digit = 0;
            resetSign();
        } elsif (ok==HOLD and digit == 6 and num(left(input,2))==19) {
            # set floor warn
            var floor = metric?num(right(input,4))*M2FT:num(right(input,4));
            if (floor == 0) {
              floor = -10000;
            }
            printDA("set floor warning "~floor~" ft");
            setprop("ja37/sound/floor-ft", floor);
            input = inputDefault;
            digit = 0;
            resetSign();
        } elsif (ok==HOLD and digit == 6 and num(left(input,2))==52) {
            # set max loadfactor percent
            var percent = num(substr(input,2,3));
            if (percent < 75) {
              percent = 75;
            } elsif (percent > 110) {
              percent = 110;
            }
            printDA("set loadfactor percent "~percent~"%");
            setprop("ja37/sound/loadfactor-percent", percent);
            input = inputDefault;
            digit = 0;
            resetSign();
        } elsif (ok==HOLD and digit == 6) {
            printDA("set unknown address "~input);
            input = inputDefault;
            digit = 0;
            resetSign();
        } elsif (keyPressed == -1) {
          # TODO: not sure
        } elsif (x == HOLD) {
          # clear field
            input = inputDefault;
            digit = 0;
            resetSign();
        } else {
          # floor/alpha input
          if (back == HOLD) {
            inputBackKey(6);
          } else {
            inputKey(6);
          }
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
  settingPrevPos  = settingPos;
  back = RELEASE;
  x    = RELEASE;
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
  if (hour>23 or minute > 59 or second > 59) {
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
  if (year > 79) {
    year = year+1900;
  } else {
    year = year+2000;
  }
  if (month>12 or month < 1) {
    return FALSE;
  }
  var maxDay = monthmax[month-1];
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

var inputKey = func (digs) {
  if (keyPressed != nil and digit < digs) {
    input = substr(input, 0,digit)~keyPressed~manyChar(charDefault,digs-(digit+1));
    digit += 1;
  }
}

var inputBackKey = func (digs) {
  digit -= 1;
  input = substr(input, 0,digit)~manyChar(charDefault,digs-digit);
  if (digit == -1) {
    digit = 0;
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
  return settingPrevKnob != settingKnob or settingPrevDir != settingDir or settingPrevPos != settingPos;
}

var updateCycleMax = func {
  if (settingKnob == KNOB_TI) {
    cycleMax = 2;
  } elsif (settingKnob == KNOB_LOLA or settingKnob == KNOB_DATE) {
    cycleMax = 1;
  } else {
    cycleMax = -1;
  }
  if (cycleMax == -1) {
    cycle = -1;
  } else {
    cycle = 0;
  }
}

var disp = func {
  display = "";

  if (testDisplay != "") {
    var minus = " ";
    if (testMinus == 1) {
      testMinusLast = !testMinusLast;
      if (testMinusLast == 1) {
        minus = "-";
      }
    }
    display = minus~testDisplay;
  } elsif (error == TRUE) {
    display = metric?"   FEL":" Error";
  } elsif (state == 237) {
    if (digit == 0) {
      display = "   237";
    } else {
      var sign = settingSign<0?"-":" ";
      #printf("disp:%s_%s_%d", sign, input, ti237_max);
      #if (ti237_max>6) {
      #  display = input;
      #} else {
        display = sign~input;#not elegant, fix later
      #}
    }
  } elsif (settingDir == OUT and settingPos == POS) {
    display = posOutDisplay;
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
        display = "000000";
      }
    } elsif (settingKnob == KNOB_TI) {
      var address = num(left(input,3));
      if (cycle == -1) {
        cycle = 0;
      }
      if (ok == HOLD) {
        if (cycle == 0) {
          display = "-----P";
        } elsif (cycle == 1) {
          display = "----LO";
        } else {
          display = "----LA"
        }
      } else {
        if (address != nil and address == 179) {
          #bulls-eye
          if (cycle == 0) {
            display = "179"
          } elsif (cycle == 1) {
            var lo = getprop("ja37/navigation/bulls-eye-lon");
            var lon = ja37.convertDegreeToDispStringLon(lo);
            display = sprintf("%s",lon);
          } else {
            var la = getprop("ja37/navigation/bulls-eye-lat");
            var lat = ja37.convertDegreeToDispStringLat(la);
            display = sprintf("%s",lat);
          }
        } elsif (address != nil and address >= 1 and address < 190) {
          if (cycle == 0) {
            display = sprintf("%03d", address);
          } elsif (cycle == 1) {
            var point = lv["p"~sprintf("%03d", address)];
            if (point != nil) {
              var lo = point.lon;
              var lon = ja37.convertDegreeToDispStringLon(lo);
              display = sprintf("%s",lon);
            } else {
              display = "------";
            }
          } else {
            var point = lv["p"~sprintf("%03d", address)];
            if (point != nil) {
              var la = point.lat;
              var lat = ja37.convertDegreeToDispStringLat(la);
              display = sprintf("%s",lat);
            } else {
              display = "------";
            }
          }
        }
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
          var lon = ja37.convertDegreeToDispStringLon(lo);
          display = sprintf("%s",lon);
        } else {
          var la = getprop("position/latitude-deg");
          var lat = ja37.convertDegreeToDispStringLat(la);
          display = sprintf("%s",lat);
        }
      }
    } elsif (settingKnob == KNOB_FUEL) {
      var warn = getprop("ja37/systems/fuel-warning-extra-percent");
      if (warn != -1) {
        display = ""~warn;
      } else {
        display = "00";
      }
    } elsif (settingKnob == KNOB_REG) {
      var address = num(left(input,2));
      #printDA("reg adr to display out: "~(address==nil?"nil":""~address));
      if (address == nil or address==0) {
          # max alpha
          #printDA("displaying alpha");
          display = sprintf("00%02d00", getprop("fdm/jsbsim/fcs/max-alpha-deg"));
      } elsif (address != nil and address==52) {
          # loadfactor percent warn
          display = sprintf("52%03d0", getprop("ja37/sound/loadfactor-percent"));
      } elsif (address != nil and address==19) {
          # floor warn
          if (getprop("ja37/sound/floor-ft") < 0) {
            display = "190000";
          } else {
            display = sprintf("19%04d", getprop("ja37/sound/floor-ft")*(metric?FT2M:1));
          }
      } else {
        display = "000000";
      }
    } elsif (settingKnob == KNOB_DATA) {
      var address = num(left(input,2));
      if (address != nil and address==15) {
          # interoperability
          display = sprintf("150%01d00", !getprop("ja37/hud/units-metric"));
      } elsif (address != nil and address==30) {
          # GPS Installed
          display = sprintf("30%01d000", getprop("ja37/navigation/gps-installed"));
      } else {
        display = "000000";
      }
    }
  } else {# input
    if (settingKnob == KNOB_DATA) {
      display = input;
    } elsif (settingKnob == KNOB_REG) {
      display = input;
    } elsif (settingKnob == KNOB_TI) {
      var sign = settingSign<0?"-":" ";
      display = sign~input;
    } elsif (settingKnob == KNOB_FUEL) {
      display = input;
    } elsif (settingKnob == KNOB_DATE) {
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
  if (!power.prop.acMainBool.getValue()) {
    # hack
    signText.setText("-888888");
    return;
  }
  #printDA(" display  *"~display~"*");
  if (size(display)==8) {
    #make room for the unauthentic 8th digit, for longitudes outside Sweden
    signText.setFontSize(50, 1.25);
  } else {
    signText.setFontSize(50, 1.125);
  }
  signText.setText(display);
};
var metric = 0;
var loop_main = func {
  if (getprop("ja37/systems/variant") != 0) return;
  metric = getprop("ja37/hud/units-metric");
  disp();
  #settimer(loop_main,1);
}



var monthmax = [31,28,31,30,31,30,31,31,30,31,30,31];
#var new_dt=sprintf("%04d-%02d-%02dT%02d:%02d:%02d",getprop("/sim/time/demand-year"),month,getprop("/sim/time/demand-day"),hour,minute,second*1);
#setprop("/sim/time/gmt",new_dt);

# input
#
# REG/STR UD IN
# 19xxxx  training floor in meters
# 23-bcd  Cannon burst number of shots in OP mode.
# 52xxxd  Load-factor nominal warning in percent. (not correct address, but dont know the real address)
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
# interoperability:  15a1cd, swedish: 15a0cd.
# TI backlit intensity of frame buttons: 06xxxd
# GPS-reciever installed: 301bcd (yes), 300bcd (no)

# output UD UT
#
# TILS/BANA
# [ILSFREQ]
#
# REG/STR
# 01axxx  xxx=delta exceeded outlet temperature
# 02xxxx  xxxx=highest measured outlet temp
# 03abcd  a=1:too high force Ny detected for vert tail, b=1:ejector termal too high detected, cd=delta too high normal Nz detected (c,d)
# 04axxx  xxx=highest normal detected (xx.x)
# 05abxx  xx=highest alpha detected
# 06abcd  engine wear value
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
# address  rad  col typ
# 1-39     5km  ryg LV
# 40-99    8km  ryg LV
# 100-109 3.5mm  t  FF 
# 110-178 15km  ryg LV
# 179            t  BE
# 180-189 40km  ryg LV
# 190-199 15km   r STRIL LV number always on
# 
# TI/MSDA=number
# FF number is right and north
# LV number is middle and north
# max 10 LV shown at once, closest to point 22km in front of plane
# G=green L=yellow OK=red at address input

var lv = {
  # address, color (0=red 1=yellow 2=tyrk 3=green), radius(KM) (-1= 3.5mm), type (0=LV, 1=FF, 2=STRIL, 3=bullseye), lon, lat
  # note address 179 is stores as properties, not in this struct.
  #p20: {address: 020, color: 1, radius: 5, type: 0, lon: -115.784, lat: 37.218},#example
  #p105: {address: 105, color: 2, radius: -1, type: 1, lon: -115.784, lat: 37.218},#example
  #p3: {address: 3, color: 3, radius: 8, type: 0, lon: -115.41, lat: 36.35},
};

var lv_temp = nil;# temp storage of LV point when its being edited.

var savePoints = func (path) {
    var text = serialize(lv);
    var opn = nil;
    call(func{opn = io.open(path,"w");},nil, var err = []);
    if (size(err) or opn == nil) {
      print("error open file for writing points");
      gui.showDialog("savefail");
      return 0;
    }
    call(func{var text = io.write(opn,text);},nil, var err = []);
    if (size(err)) {
      print("error write file with points");
      gui.showDialog("savefail");
      io.close(opn);
      return 0;
    } else {
      lv = unserialize(text);
      io.close(opn);
      return 1;
    }
}

var loadPoints = func (path,clear=1) {
    var text = nil;
    call(func{text=io.readfile(path);},nil, var err = []);
    if (size(err)) {
      print("Loading LV/FF/BE failed.");
      if (clear) {
        lv = {};
        setprop("ja37/navigation/bulls-eye-defined",0);
      }
    } elsif (text != nil) {
      lv = unserialize(text);
    }
    checkLVSave();
}

var checkLVSave = func {
  return;
  if (size(keys(lv)) or getprop("ja37/navigation/bulls-eye-defined") or getprop("autopilot/plan-manager/destination/airport-1")!="" or getprop("autopilot/plan-manager/destination/airport-2")!="" or getprop("autopilot/plan-manager/destination/airport-3")!="" or getprop("autopilot/plan-manager/destination/airport-4")!="") {
    setprop("autopilot/plan-manager/points/save",1);
  } else {
    setprop("autopilot/plan-manager/points/save",0);
  }
}

checkLVSave();

var serialize = func(m) {
  var ret = "";
  foreach(key;keys(m)) {
    ret = ret~sprintf("TI,%d,%d,%d,%d,%.6f,%.6f|",m[key].address,m[key].color,m[key].radius,m[key].type,m[key].lon,m[key].lat);
  }
  if (getprop("ja37/navigation/bulls-eye-defined")) {
    var beLaLo = [getprop("ja37/navigation/bulls-eye-lat"), getprop("ja37/navigation/bulls-eye-lon")];
    ret = ret~sprintf("TI,179,%.6f,%.6f|",beLaLo[1],beLaLo[0]);
  }
  ret = ret~sprintf("L,%s,%s,%s,%s|",getprop("autopilot/plan-manager/destination/airport-1"),getprop("autopilot/plan-manager/destination/airport-2"),getprop("autopilot/plan-manager/destination/airport-3"),getprop("autopilot/plan-manager/destination/airport-4"));
  ret = ret~sprintf("FPLDATA,%d,%d|",getprop("ja37/hud/units-metric"),getprop("ja37/navigation/gps-installed"));
  ret = ret~sprintf("REG,%d,%d,%d|",getprop("ja37/sound/floor-ft"),getprop("fdm/jsbsim/fcs/max-alpha-deg"),getprop("ja37/sound/loadfactor-percent"));
  ret = ret~sprintf("FUEL,%d|",getprop("ja37/systems/fuel-warning-extra-percent"));
  ret = ret~sprintf("EP12,%d,%d,%d,%d,%d,%d,%d,%d,%d|",TI.ti.SVYactive,TI.ti.SVYscale,TI.ti.SVYrmax,TI.ti.SVYhmax,TI.ti.SVYsize,TI.ti.SVYinclude,TI.ti.ECMon,TI.ti.lnk99,TI.ti.displayFlight);
  return ret;
}

var unserialize = func(m) {
  var ret = {};
  var points = split("|",m);
  foreach(point;points) {
    if (size(point)>4) {
      var items = split(",", point);
      var key = items[0];
      if (key == "L") {
        setprop("autopilot/plan-manager/destination/airport-1", items[1]);
        setprop("autopilot/plan-manager/destination/airport-2", items[2]);
        setprop("autopilot/plan-manager/destination/airport-3", items[3]);
        setprop("autopilot/plan-manager/destination/airport-4", items[4]);
      } elsif (key == "TI") {
        if (num(items[1])==179) {
          setprop("ja37/navigation/bulls-eye-defined",1);
          setprop("ja37/navigation/bulls-eye-lon",num(items[2]));
          setprop("ja37/navigation/bulls-eye-lat",num(items[3]));
        } else {
          ret["p"~items[1]] = {address: num(items[1]),color: num(items[2]),radius: num(items[3]),type: num(items[4]),lon: num(items[5]),lat: num(items[6])};
        }
      } elsif (key == "FPLDATA") {
        setprop("ja37/hud/units-metric", num(items[1]));
        setprop("ja37/navigation/gps-installed", num(items[2]));
      } elsif (key == "EP12") {
        # TI237 and MI settings:
        TI.ti.SVYactive     = num(items[1]);
        TI.ti.SVYscale      = num(items[2]);
        TI.ti.SVYrmax       = num(items[3]);
        TI.ti.SVYhmax       = num(items[4]);
        TI.ti.SVYsize       = num(items[5]);
        TI.ti.SVYinclude    = num(items[6]);
        TI.ti.ECMon         = num(items[7]);
        TI.ti.lnk99         = num(items[8]);
        TI.ti.displayFlight = num(items[9]);# consider not loading this back in
      } elsif (key == "REG") {
        setprop("ja37/sound/floor-ft", num(items[1]));
        setprop("fdm/jsbsim/fcs/max-alpha-deg", num(items[2]));
        if (size(items) >= 4) {
          setprop("ja37/sound/loadfactor-percent", num(items[3]));
        }
      } elsif (key == "FUEL") {
        setprop("ja37/systems/fuel-warning-extra-percent", num(items[1]));
      }
    }
  }
  return ret;
}

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
var l           = RELEASE;
var g           = RELEASE;
var x           = RELEASE;
var back        = RELEASE;
var keyPressed  = nil;
var settingKnob = getprop("ja37/navigation/dp-mode");
var settingSign = getprop("ja37/navigation/ispos")==MINUS?-1:1;
var settingDir  = getprop("ja37/navigation/inout");
var settingPos  = POS;
var settingPrevKnob = getprop("ja37/navigation/dp-mode");
var settingPrevSign = getprop("ja37/navigation/ispos")==MINUS?-1:1;
var settingPrevDir  = getprop("ja37/navigation/inout");
var settingPrevPos  = POS;

var resetSign = func {
  settingSign = 1;
  setprop("ja37/navigation/ispos", settingSign>0?PLUS:MINUS);
}

var toggleInOut = func {
  if (getprop("ja37/systems/variant") != 0) return;
  settingDir = !settingDir;
  updateProps();
  main();
}

var togglePosMsda = func {
  if (getprop("ja37/systems/variant") != 0) return;
  settingPos = !settingPos;
  updateProps();
  main();
}

var togglePN = func {
  if (getprop("ja37/systems/variant") != 0) return;
  if (settingSign<0) {
    settingSign = 1;
  } else {
    settingSign = -1;
  }
  updateProps();
  main();
}

var test = func {
  if (getprop("ja37/systems/variant") != 0) return;
}

var syst = func {
  # called from TI
  if(getprop("fdm/jsbsim/gear/unit[0]/WOW") == FALSE) {
    settingDir  = OUT;
    settingPos  = POS;
    updateProps();
  }
}

var wow = func {
  if(getprop("fdm/jsbsim/gear/unit[0]/WOW") == FALSE) {
    settingDir  = OUT;
    settingPos  = POS;
    updateProps();
  }
}

var updateProps = func {
  setprop("ja37/navigation/inout", settingDir);
  setprop("ja37/navigation/ispos", settingSign>0?PLUS:MINUS);
  setprop("ja37/dap/pos", settingPos);
  setprop("ja37/dap/msda", !settingPos);
  setprop("ja37/dap/in", !settingDir);
  setprop("ja37/dap/out", settingDir);
}
updateProps();

var switch = func {
  if (getprop("ja37/systems/variant") != 0) return;
  settingKnob = getprop("ja37/navigation/dp-mode");
  settingSign = getprop("ja37/navigation/ispos")?-1:1;
  settingDir  = getprop("ja37/navigation/inout");
  main();
}

var keyPress = func (key) {
  if (getprop("ja37/systems/variant") != 0) return;
  if (!power.prop.acMainBool.getValue()){
    printDA("DAP: offline");
    return;
  }
  if (settingDir != IN or settingPos != MSDA) {
    settingDir = IN;
    settingPos = MSDA;
    updateProps();
    main();
  }
  keyPressed = key;
  printDA("DAP: key "~key);
  main();
}

var okPress = func {
  if (getprop("ja37/systems/variant") != 0) return;
  if (!power.prop.acMainBool.getValue()){
    printDA("NAV: offline");
    return;
  }
  ok = HOLD;
  main();
}

var okRelease = func {
  if (getprop("ja37/systems/variant") != 0) return;
  if (!power.prop.acMainBool.getValue()){
    printDA("NAV: offline");
    return;
  }
  ok = RELEASE;
  main();
}

var lPress = func {
  if (getprop("ja37/systems/variant") != 0) return;
  if (!power.prop.acMainBool.getValue()){
    printDA("NAV: offline");
    return;
  }
  l = HOLD;
  main();
}

var lRelease = func {
  if (getprop("ja37/systems/variant") != 0) return;
  if (!power.prop.acMainBool.getValue()){
    printDA("NAV: offline");
    return;
  }
  l = RELEASE;
  main();
}

var gPress = func {
  if (getprop("ja37/systems/variant") != 0) return;
  if (!power.prop.acMainBool.getValue()){
    printDA("NAV: offline");
    return;
  }
  g = HOLD;
  main();
}

var gRelease = func {
  if (getprop("ja37/systems/variant") != 0) return;
  if (!power.prop.acMainBool.getValue()){
    printDA("NAV: offline");
    return;
  }
  g = RELEASE;
  main();
}

var xPress = func {
  if (getprop("ja37/systems/variant") != 0) return;
  if (!power.prop.acMainBool.getValue()){
    printDA("NAV: offline");
    return;
  }
  x = HOLD;
  if (!route.Polygon.deleteSteerpoint()) {
    main();
  } else {
    x = RELEASE;
  }
}

var xRelease = func {
  if (getprop("ja37/systems/variant") != 0) return;
  if (!power.prop.acMainBool.getValue()){
    printDA("NAV: offline");
    return;
  }
  x = RELEASE;
  main();
}

var backPress = func {
  if (getprop("ja37/systems/variant") != 0) return;
  if (!power.prop.acMainBool.getValue()){
    printDA("NAV: offline");
    return;
  }
  back = HOLD;
  main();
}

setlistener("ja37/navigation/dp-mode", switch);
setlistener("fdm/jsbsim/gear/unit[0]/WOW", wow);
#setlistener("ja37/navigation/ispos", switch);
#setlistener("ja37/navigation/inout", switch);
