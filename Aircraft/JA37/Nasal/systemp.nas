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
    m.verbose = 1;
    m.running=0;
    m.dt=0;
    m.oldtime=0;
    return m;
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
          append(me.connections, Connection.new(c_arr));
          if (me.verbose > 1) print("Adding: "~line);
        } else if (me.verbose > 1) print("Skipping: "~line);
      }
    }
    io.close(fh); 
    if (me.verbose > 0) print("Read connections");
  },

  change_value : func(prop, value, ramp) {
    if (ramp == 0) setprop(prop, value);
    else {
      var ov=num(getprop(prop));
      if (ov<value and value-ov > ramp*me.dt) setprop(prop, ov+ramp*me.dt);
      else if (ov>value and ov-value > ramp*me.dt) setprop(prop, ov-ramp*me.dt);
      else setprop(prop, value);
    }
  },

  update : func {
    if (!me.running) return;
    var service = getprop("/systems/electrical/serviceable");
    var time=getprop("/sim/time/elapsed-sec");
    me.dt= time-me.oldtime;
    foreach (con; me.connections) {
      if(service == 0 and rand() > 0.30) dp=num(con.off); else dp=getprop(con.dep); #electrical system has failed?
      if (dp != nil) {
        if (num(con.limit) != nil) limit=num(con.limit); else limit=getprop(con.limit);
        if (con.in == ".") me.change_value(con.out, dp, con.ramp); #copy dep value to out
        else if (dp <= limit) {
            if (num(con.off) != nil) me.change_value(con.out, num(con.off), con.ramp);
            else me.change_value(con.out, getprop(con.off), con.ramp);
        } else {
          if (num(con.in) != nil) me.change_value(con.out, num(con.in), con.ramp);
          else me.change_value(con.out, getprop(con.in), con.ramp);
        }
      }
    }
    me.oldtime=time;
    settimer( func me.update(), 0.05);    
  },

  init : func {
    me.read_connections();
    foreach (con; me.connections) {
      if (num(con.off) != nil) setprop(con.out, num(con.off));
      else setprop(con.out, getprop(con.off));
    }
    me.running=1;
    me.oldtime= getprop("/sim/time/elapsed-sec");
    if (me.verbose > 0) print("Initialized system");
    me.update();
  },
};

var el = System_P.new("Systems/electric.txt");
el.init();
print("Electric ... Check");

