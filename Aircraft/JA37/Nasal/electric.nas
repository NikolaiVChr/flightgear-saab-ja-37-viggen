# Potemkin system

# Connections
#dep: depends on this property true/1 often a powersource
#in: input property eg. orientation/pitch-deg or number constant. 
#    Use . to copy dep value to out. Use ! to copy 1-dep value to out
#out output property eg.instruments/ai/pitch-deg
#off: value if not dep true, can be a property to be read
#ramp: max change per second of out, 0 no limit

var connection = { dep: "", in: "", out: "", off: "", ramp: 0};

var new_connection = func(cv) {
  var c = {parents:[connection] };
  c.dep=cv[0];
  c.in=cv[1];
  c.out=cv[2];
  c.off=cv[3];
  c.ramp=num(cv[4]);
  return c;
}

var connections = [];
var verb = 2;
var running=0;
var dt=0;
var oldtime=0;

var read_connections = func {
  if (verb > 0) print("Reading connections");
  var fh = io.open(getprop("/sim/aircraft-dir")~"/connections.txt", "r");
  var line="";
  while (line != nil) {
    line = io.readln(fh);
    if (line != nil) {
      var c_arr=split(",", line);
      if (size(c_arr) == 5) {
        append(connections, new_connection(c_arr));
        if (verb > 1) print("Adding: "~line);
      } else if (verb > 1) print("Skipping: "~line);
    }
  }
  io.close(fh); 
  if (verb > 0) print("Read connections");
}

var change_value = func(prop, value, ramp) {
  if (ramp == 0) setprop(prop, value);
  else {
    ov=num(getprop(prop));
    if (ov<value and value-ov > ramp*dt) setprop(prop, ov+ramp*dt);
    else if (ov>value and ov-value > ramp*dt) setprop(prop, ov-ramp*dt);
    else setprop(prop, value);
  }
}

var update_state = func {
  if (!running) return;
  var time=getprop("/sim/time/elapsed-sec");
  dt= time-oldtime;
  foreach (con; connections) {
    dp=getprop(con.dep);
    if (dp != nil) {
      if (con.in == ".") setprop(con.out, dp); #copy dep value to out
      else if (con.in == "!") setprop(con.out, 1-dp); #copy !dep to out 
      else if (dp == 0) {
          if (num(con.off) != nil) change_value(con.out, num(con.off), con.ramp);
          else change_value(con.out, getprop(con.off), con.ramp);
      } else {
        if (num(con.in) != nil) change_value(con.out, num(con.in), con.ramp);
        else change_value(con.out, getprop(con.in), con.ramp);
      }
    }
  }
  oldtime=time;
  settimer(update_state, 0.05);    
}

var init_electric = func {
  read_connections();
  foreach (con; connections) {
    if (num(con.off) != nil) setprop(con.out, num(con.off));
    else setprop(con.out, getprop(con.off));
  }
  running=1;
  oldtime= getprop("/sim/time/elapsed-sec");
    if (verb > 0) print("Initialized system");
  update_state();
}

