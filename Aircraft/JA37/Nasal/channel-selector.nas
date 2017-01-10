var STANDBY = 0;
var INPUT = 1;
var mode = STANDBY;
var digit = 1;
var display = 0;
var top    = "36C";
var middle = "321";
var bottom = "12345";

var roundabout = func(x) {
  var y = x - int(x);
  return y < 0.5 ? int(x) : 1 + int(x) ;
};

var resetDisplays = func {
	setprop("ja37/radio/kv1/digit-top-1", getPlace(substr(top, 0 , 1)));
	setprop("ja37/radio/kv1/digit-top-2", getPlace(substr(top, 1 , 1)));
	setprop("ja37/radio/kv1/digit-top-3", getPlace(substr(top, 2 , 2)));

	setprop("ja37/radio/kv1/digit-middle-1", getPlace(substr(middle, 0 , 1)));
	setprop("ja37/radio/kv1/digit-middle-2", getPlace(substr(middle, 1 , 1)));
	setprop("ja37/radio/kv1/digit-middle-3", getPlace(substr(middle, 2 , 1)));

	setprop("ja37/radio/kv1/digit-bottom-1", getPlace(substr(bottom, 0 , 1)));
	setprop("ja37/radio/kv1/digit-bottom-2", getPlace(substr(bottom, 1 , 1)));
	setprop("ja37/radio/kv1/digit-bottom-3", getPlace(substr(bottom, 2 , 1)));
	setprop("ja37/radio/kv1/digit-bottom-4", getPlace(substr(bottom, 3 , 1)));
	setprop("ja37/radio/kv1/digit-bottom-5", getPlace(substr(bottom, 4 , 1)));
	#print("KV1 Displays reset");
};

var updateToRadio = func {
	if (getprop("ja37/radio/kv1/button-mhz") == 1) {
		var number = num(bottom)/100;
		var CN = getprop("instrumentation/radio/switches/com-nav");
		var MK = getprop("instrumentation/radio/switches/mhz-khz");

		if (CN == 0 and MK == 0) {
			setprop("instrumentation/comm/frequencies/selected-mhz", number);
		} elsif (CN == 1 and MK == 0) {
			setprop("instrumentation/nav/frequencies/selected-mhz", number);
		} elsif (CN == 1 and MK == 1) {
			setprop("instrumentation/adf/frequencies/selected-khz", number);
		}
	}
};

var updateFromRadio = func {
	var freq = roundabout(getprop("instrumentation/radio/display-freq")*100);
	bottom = ""~freq;
	digit = 1;
	mode = STANDBY;
	display = 0;
	resetDisplays();
};

var getPlace = func (strDigit) {
	if (strDigit == "0") {
		return 0;
	} elsif (strDigit == "1") {
		return 1;
	} elsif (strDigit == "2") {
		return 2;
	} elsif (strDigit == "3") {
		return 3;
	} elsif (strDigit == "4") {
		return 4;
	} elsif (strDigit == "5") {
		return 5;
	} elsif (strDigit == "6") {
		return 6;
	} elsif (strDigit == "7") {
		return 7;
	} elsif (strDigit == "8") {
		return 8;
	} elsif (strDigit == "9") {
		return 9;
	} elsif (strDigit == "C") {
		return 10;
	} elsif (strDigit == "C2") {
		return 11;
	}
}

var button = func (number) {
	if (mode == INPUT) {
		if (1==1) {
			# number
			var displ = display==1?"top":(display==2?"middle":"bottom");
			var place = 0;
			var special = "";
			if (display == 1 and digit == 3) {
				if (number == 2) {
					place = 10;
					special = "C";
				} elsif (number == 3) {
					place = 11;
					special = "C2";
				} else {
					#change this to show all letters
					place = number;
					special = ""~number;
				}
			} else {
				place = number;
			}
			setprop("ja37/radio/kv1/digit-"~displ~"-"~digit, place);
			if (display == 1) {
				if (digit == 3) {
					digit = 1;
					mode = STANDBY;
					display = 0;
					top = getprop("ja37/radio/kv1/digit-top-1")~getprop("ja37/radio/kv1/digit-top-2")~special;
					updateToRadio();
				} else {
					digit += 1;
				}
			} elsif (display == 2) {
				if (digit == 3) {
					digit = 1;
					mode = STANDBY;
					display = 0;
					middle = getprop("ja37/radio/kv1/digit-middle-1")~getprop("ja37/radio/kv1/digit-middle-2")~getprop("ja37/radio/kv1/digit-middle-3");
					updateToRadio();
				} else {
					digit += 1;
				}
			} elsif (display == 3) {
				if (digit == 5) {
					digit = 1;
					mode = STANDBY;
					display = 0;
					bottom = getprop("ja37/radio/kv1/digit-bottom-1")~getprop("ja37/radio/kv1/digit-bottom-2")~getprop("ja37/radio/kv1/digit-bottom-3")~getprop("ja37/radio/kv1/digit-bottom-4")~getprop("ja37/radio/kv1/digit-bottom-5");
					updateToRadio();
				} else {
					digit += 1;
				}
			}
		} else {
			# letter

		}
	}
}



var cl1 = func {
	mode = INPUT;
	digit = 1;
	display = 1;
	resetDisplays();
	setprop("ja37/radio/kv1/digit-top-1", 12);
	setprop("ja37/radio/kv1/digit-top-2", 12);
	setprop("ja37/radio/kv1/digit-top-3", 12);
};

var cl2 = func {
	mode = INPUT;
	digit = 1;
	display = 2;
	resetDisplays();
	setprop("ja37/radio/kv1/digit-middle-1", 12);
	setprop("ja37/radio/kv1/digit-middle-2", 12);
	setprop("ja37/radio/kv1/digit-middle-3", 12);
};

var cl3 = func {
	mode = INPUT;
	digit = 1;
	display = 3;
	resetDisplays();
	setprop("ja37/radio/kv1/digit-bottom-1", 12);
	setprop("ja37/radio/kv1/digit-bottom-2", 12);
	setprop("ja37/radio/kv1/digit-bottom-3", 12);
	setprop("ja37/radio/kv1/digit-bottom-4", 12);
	setprop("ja37/radio/kv1/digit-bottom-5", 12);
};

updateFromRadio();
resetDisplays();
setlistener("instrumentation/radio/display-freq", updateFromRadio);