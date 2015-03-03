# Potemkin system

# Connections
#dep: depends on this property.
#limit: lower limit for true. dep > limit eq. true
#in: input property eg. orientation/pitch-deg or number constant. 
#    Use . to copy dep value to out.
#out output property eg.instruments/ai/pitch-deg
#off: value if not dep true, can be a property to be read
#ramp: max change per second of out, 0 no limit

var Connection = {
  new : func(cv) {
    var m = {parents:[Connection] };
    m.dep=cv[0];
    m.limit=cv[1];
    m.in=cv[2];
    m.out=cv[3];
    m.off=cv[4];
    m.ramp=num(cv[5]);
    return m;
  },
  
};

var System_P = {

  new : func(system_file) {
    var m = {parents:[System_P] };
    m.file=system_file;
    m.connections = [];
    m.verbose = 0;
    m.running=0;
    m.dt=0;
    m.oldtime=0;
    return m;
  },

  init : func {
    me.read_connections();
    foreach (var connection; me.connections) {
      if (num(connection.off) != nil) {
        setprop(connection.out, num(connection.off));
      } else {
        setprop(connection.out, getprop(connection.off));
      }
    }
    me.running = 1;
    me.oldtime = getprop("/sim/time/elapsed-sec");
    if (me.verbose > 0) print("Initialized system");
    me.update();
  },

  read_connections : func {
    if (me.verbose > 0) print("Reading connections");
    var fh = io.open(getprop("/sim/aircraft-dir")~"/"~me.file, "r");
    var line="";
    while (line != nil) {
      line = io.readln(fh);
      if (line != nil) {
        var c_arr=split(",", line);
        if (size(c_arr) == 6) {
#print("adding "~c_arr[0]);
          c_arr[0] = props.globals.getNode(c_arr[0]);
          if(c_arr[0] == nil) print("Potemkin: property not initialized in line: "~line);
          if(num(c_arr[2]) == nil and c_arr[2] != ".") {
            c_arr[2] = props.globals.getNode(c_arr[2]);
            if(c_arr[2] == nil) print("Potemkin: property not initialized in line: "~line);
          }
          c_arr[3] = props.globals.getNode(c_arr[3]);
          if(c_arr[3] == nil) print("Potemkin: property not initialized in line: "~line);
          if(num(c_arr[4]) == nil) {
            c_arr[4] = props.globals.getNode(c_arr[4]);
            if(c_arr[4] == nil) print("Potemkin: property not initialized in line: "~line);
          }
          append(me.connections, Connection.new(c_arr));
          if (me.verbose > 1) print("Adding: "~line);
        } else if (me.verbose > 1) print("Skipping: "~line);
      }
    }
    io.close(fh); 
    if (me.verbose > 0) print("Read connections");
  },

  update : func {
    if (!me.running) return;
    if(getprop("sim/replay/replay-state") == 1) {
      # replay is active, skip rest of loop.
      settimer( func me.update(), 0.05);
    } else {
      var service = getprop("/systems/electrical/serviceable");
      var time = getprop("/sim/time/elapsed-sec");
      me.dt = time - me.oldtime;

      foreach (connection; me.connections) {
        var dependant = nil;
        if(service == 0 and rand() > 0.30) {#electrical system has failed?
          dependant = num(connection.off);
        } else {
          dependant = connection.dep.getValue(); 
        }
        if (dependant != nil) {
          if (num(connection.limit) != nil) {
            limit = num(connection.limit);
          } else {
            limit = connection.limit.getValue();
          }
          if (connection.in == ".") {
            me.change_value(connection.out, dependant, connection.ramp); #copy dep value to out
          } elsif (dependant <= limit) {
              if (num(connection.off) != nil) {
                me.change_value(connection.out, num(connection.off), connection.ramp);
              } elsif (connection.off.getValue() != nil) {
                me.change_value(connection.out, connection.off.getValue(), connection.ramp);
              }
          } else {
            if (num(connection.in) != nil) {
              me.change_value(connection.out, num(connection.in), connection.ramp);
            } elsif (connection.in.getValue() != nil) {
              me.change_value(connection.out, connection.in.getValue(), connection.ramp);
            } else {
              print("Potomkin: Setting nothing on "~connection.out.getPath()~" due to nil on "~connection.in.getPath());
            }
          }
        }
      }
      me.oldtime = time;
      settimer( func me.update(), 0.05);
    }
  },

  change_value : func(node, value, ramp) {
    if (ramp == 0) {
      #print("setting "~value~" on "~node.getPath());
      node.setValue(value);
    } else {
      var ov = node.getValue();
      if (ov<value and value-ov > ramp*me.dt) {
        node.setValue(ov+ramp*me.dt);
      } elsif (ov>value and ov-value > ramp*me.dt) {
        node.setValue(ov-ramp*me.dt);
      } else {
        node.setValue(value);
      }
    }
  },
};

var el = System_P.new("Systems/electric.txt");

var elec_start = func {
  removelistener(lsnr);
  el.init();
  # print("Electric ... Check");
}

var lsnr = setlistener("sim/ja37/supported/initialized", elec_start);


