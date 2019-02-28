var table = {};

var t1 = 0;
var t2 = 0;
var time = 0;

var timeLoop = func (name, function, context) {
	t1 = systime();
	call(function, nil, context, context, var err = []);
	t2 = systime();
	time = t2-t1;
	time *= 1000;
	if (table[name] == nil) {
		table[name] = time;
	} else {
		table[name] = math.max(table[name],time);
	}
	setprop("timings/now-"~name, time);
	setprop("timings/max-"~name, table[name]);
	if (getprop("timings/aaaa")) {
		setprop("timings/aaaa",0);
		table = {};
	}
}
setprop("timings/reset-max",1);