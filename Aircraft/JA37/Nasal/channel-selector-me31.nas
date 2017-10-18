#
# H = 121.50 MHz
#


var STANDBY = 0;
var INPUT = 1;
var mode = STANDBY;
var digit = 1;
var display = 0;
var bottom = "12345";

var roundabout = func(x) {
  var y = x - int(x);
  return y < 0.5 ? int(x) : 1 + int(x) ;
};

var resetDisplays = func {
	setprop("ja37/radio/me31/digit-bottom-1", getPlace(substr(bottom, 0 , 1)));
	setprop("ja37/radio/me31/digit-bottom-2", getPlace(substr(bottom, 1 , 1)));
	setprop("ja37/radio/me31/digit-bottom-3", getPlace(substr(bottom, 2 , 1)));
	setprop("ja37/radio/me31/digit-bottom-4", getPlace(substr(bottom, 3 , 1)));
	setprop("ja37/radio/me31/digit-bottom-5", getPlace(substr(bottom, 4 , 1)));
	#print("ME31 Display reset");
};

var updateToRadio = func {
	var number = num(bottom)/100;
	setprop("instrumentation/nav/frequencies/selected-mhz", number);
};

var updateFromRadio = func {
	var freq = roundabout(getprop("instrumentation/nav/frequencies/selected-mhz")*100);
	bottom = sprintf("%05d", freq);
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
			var displ = "bottom";
			var place = 0;
			var special = "";
			place = number;
			setprop("ja37/radio/me31/digit-"~displ~"-"~digit, place);
			if (display == 3) {
				if (digit == 5) {
					digit = 1;
					mode = STANDBY;
					display = 0;
					bottom = sprintf("%01d%01d%01d%01d%01d", getprop("ja37/radio/me31/digit-bottom-1"),getprop("ja37/radio/me31/digit-bottom-2"),getprop("ja37/radio/me31/digit-bottom-3"),getprop("ja37/radio/me31/digit-bottom-4"),getprop("ja37/radio/me31/digit-bottom-5"));
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

var cl3 = func {
	mode = INPUT;
	digit = 1;
	display = 3;
	resetDisplays();
	setprop("ja37/radio/me31/digit-bottom-1", 12);
	setprop("ja37/radio/me31/digit-bottom-2", 12);
	setprop("ja37/radio/me31/digit-bottom-3", 12);
	setprop("ja37/radio/me31/digit-bottom-4", 12);
	setprop("ja37/radio/me31/digit-bottom-5", 12);
};

updateFromRadio();
resetDisplays();
setlistener("instrumentation/nav/frequencies/selected-mhz", updateFromRadio);